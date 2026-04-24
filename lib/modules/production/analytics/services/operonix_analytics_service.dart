import '../../downtime/analytics/downtime_analytics_engine.dart';
import '../../downtime/services/downtime_service.dart';
import '../../ooe/models/teep_summary.dart';
import '../../ooe/services/teep_summary_service.dart';
import '../models/analytics_downtime_daily_model.dart';
import '../models/analytics_summary_model.dart';
import 'analytics_downtime_daily_service.dart';

/// Učitava zastoje + TEEP dnevne sažetke (pogon) i gradi [OperonixAnalyticsSnapshot].
class OperonixAnalyticsService {
  OperonixAnalyticsService({
    DowntimeService? downtime,
    TeepSummaryService? teep,
    AnalyticsDowntimeDailyService? analyticsDowntimeDaily,
  })  : _downtime = downtime ?? DowntimeService(),
        _teep = teep ?? TeepSummaryService(),
        _analyticsDowntimeDaily = analyticsDowntimeDaily ?? AnalyticsDowntimeDailyService();

  final DowntimeService _downtime;
  final TeepSummaryService _teep;
  final AnalyticsDowntimeDailyService _analyticsDowntimeDaily;

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Isti trenutak kao u [DowntimeAnalyticsTab]: [rangeStart, rangeEndExclusive) lokalno.
  static List<TeepSummary> filterPlantDayTeepInRange({
    required List<TeepSummary> recent,
    required DateTime rangeStart,
    required DateTime rangeEndExclusive,
  }) {
    final rs = _dayStart(rangeStart.toLocal());
    final re = rangeEndExclusive.toLocal();
    final out = <TeepSummary>[];
    for (final s in recent) {
      if (s.scopeType != 'plant' || s.periodType != 'day') continue;
      final p = s.periodDate.toLocal();
      final d = _dayStart(p);
      if (!d.isBefore(rs) && d.isBefore(re)) {
        out.add(s);
      }
    }
    out.sort((a, b) => a.periodDate.compareTo(b.periodDate));
    return out;
  }

  static OperonixTeepRollup rollupPlantDays(List<TeepSummary> days) {
    if (days.isEmpty) {
      return const OperonixTeepRollup(
        dayCount: 0,
        avgOee: 0,
        avgOoe: 0,
        avgTeep: 0,
        avgAvailabilityOee: 0,
        avgAvailabilityOoe: 0,
        avgPerformance: 0,
        avgQuality: 0,
        avgUtilization: 0,
      );
    }
    var n = 0;
    var oee = 0.0, ooe = 0.0, teep = 0.0;
    var aOee = 0.0, aOoe = 0.0, perf = 0.0, qual = 0.0, util = 0.0;
    double gSum = 0, sSum = 0;
    double tSum = 0;
    var pvaSum = 0.0;
    var pvaN = 0;

    for (final t in days) {
      n++;
      oee += t.oee;
      ooe += t.ooe;
      teep += t.teep;
      aOee += t.availabilityOee;
      aOoe += t.availabilityOoe;
      perf += t.performance;
      qual += t.quality;
      util += t.utilization;
      gSum += t.goodCount;
      sSum += t.scrapCount;
      tSum += t.totalCount;
      final pp = t.plannedProductionTimeSeconds;
      if (pp > 0) {
        pvaSum += (t.runTimeSeconds / pp) * 100.0;
        pvaN++;
      }
    }
    final inv = 1.0 / n;
    final denomQty = tSum > 0 ? tSum : (gSum + sSum);
    final fpy = denomQty > 0 ? gSum / denomQty : null;
    final scrapRate = denomQty > 0 ? sSum / denomQty : null;

    return OperonixTeepRollup(
      dayCount: n,
      avgOee: oee * inv,
      avgOoe: ooe * inv,
      avgTeep: teep * inv,
      avgAvailabilityOee: aOee * inv,
      avgAvailabilityOoe: aOoe * inv,
      avgPerformance: perf * inv,
      avgQuality: qual * inv,
      avgUtilization: util * inv,
      fpy: fpy,
      scrapRate: scrapRate,
      planVsActualPct: pvaN > 0 ? pvaSum / pvaN : null,
      totalGoodQty: gSum,
      totalScrapQty: sSum,
      totalReworkQty: null,
    );
  }

  Future<OperonixAnalyticsSnapshot> load({
    required String companyId,
    required String plantKey,
    required DateTime rangeStart,
    required DateTime rangeEndExclusive,
    bool includeRejected = false,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      throw StateError('companyId i plantKey su obavezni.');
    }
    final now = DateTime.now();
    final span = rangeEndExclusive.difference(rangeStart);
    final prevEnd = rangeStart;
    final prevStart = prevEnd.subtract(span);

    final eventsCurrent = await _downtime.fetchEventsForAnalytics(
      companyId: cid,
      plantKey: pk,
      rangeStartLocal: rangeStart,
      rangeEndExclusiveLocal: rangeEndExclusive,
    );
    final report = DowntimeAnalyticsReport.compute(
      events: eventsCurrent,
      rangeStart: rangeStart,
      rangeEndExclusive: rangeEndExclusive,
      now: now,
      includeRejected: includeRejected,
    );

    final eventsPrev = await _downtime.fetchEventsForAnalytics(
      companyId: cid,
      plantKey: pk,
      rangeStartLocal: prevStart,
      rangeEndExclusiveLocal: prevEnd,
    );
    final previousReport = DowntimeAnalyticsReport.compute(
      events: eventsPrev,
      rangeStart: prevStart,
      rangeEndExclusive: prevEnd,
      now: now,
      includeRejected: includeRejected,
    );

    var teepFailed = false;
    var teepFromRecentScan = false;
    List<TeepSummary> plantDays;

    try {
      plantDays = await _teep.fetchPlantDaySummariesInDateRange(
        companyId: cid,
        plantKey: pk,
        rangeStartLocal: rangeStart,
        rangeEndExclusiveLocal: rangeEndExclusive,
      );
    } catch (_) {
      teepFromRecentScan = true;
      try {
        final teepRaw = await _teep.fetchRecentForPlantOnce(
          companyId: cid,
          plantKey: pk,
          limit: 200,
        );
        plantDays = filterPlantDayTeepInRange(
          recent: teepRaw,
          rangeStart: rangeStart,
          rangeEndExclusive: rangeEndExclusive,
        );
      } catch (_) {
        teepFailed = true;
        plantDays = const [];
      }
    }
    final rollup = rollupPlantDays(plantDays);

    var serverDailyFailed = false;
    var serverDaily = <AnalyticsDowntimeDailyModel>[];
    try {
      serverDaily = await _analyticsDowntimeDaily.fetchInDateRangeLocal(
        companyId: cid,
        plantKey: pk,
        rangeStartLocal: rangeStart,
        rangeEndExclusiveLocal: rangeEndExclusive,
      );
    } catch (_) {
      serverDailyFailed = true;
    }

    return OperonixAnalyticsSnapshot(
      rangeStart: report.rangeStart,
      rangeEndExclusive: report.rangeEndExclusive,
      report: report,
      previousReport: previousReport,
      plantDayTeepAsc: plantDays,
      teepRollup: rollup,
      teepLoadFailed: teepFailed,
      teepFromRecentScan: teepFromRecentScan,
      serverDowntimeDaily: serverDaily,
      serverDowntimeDailyLoadFailed: serverDailyFailed,
    );
  }
}

