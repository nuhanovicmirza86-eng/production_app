import '../../downtime/analytics/downtime_analytics_engine.dart';
import '../../ooe/models/teep_summary.dart';
import 'analytics_downtime_daily_model.dart';

/// Sažetak za Operonix Analytics Dashboard (klijent agregira TEEP + zastoje).
class OperonixTeepRollup {
  const OperonixTeepRollup({
    required this.dayCount,
    required this.avgOee,
    required this.avgOoe,
    required this.avgTeep,
    required this.avgAvailabilityOee,
    required this.avgAvailabilityOoe,
    required this.avgPerformance,
    required this.avgQuality,
    required this.avgUtilization,
    this.fpy,
    this.scrapRate,
    this.planVsActualPct,
    this.totalGoodQty,
    this.totalScrapQty,
    this.totalReworkQty,
  });

  final int dayCount;

  /// 0–1 (iz dnevnih `teep_summaries` plant/day).
  final double avgOee;
  final double avgOoe;
  final double avgTeep;
  final double avgAvailabilityOee;
  final double avgAvailabilityOoe;
  final double avgPerformance;
  final double avgQuality;
  final double avgUtilization;

  final double? fpy;
  final double? scrapRate;

  /// Ostvarenje u odnosu na planirano vrijeme (prosjek dana gdje je plan > 0).
  final double? planVsActualPct;

  final double? totalGoodQty;
  final double? totalScrapQty;
  final double? totalReworkQty;

  bool get hasTeepData => dayCount > 0;
}

/// Jedan učitani snimak (trenutni + opcijski prethodni period za usporedbu).
class OperonixAnalyticsSnapshot {
  const OperonixAnalyticsSnapshot({
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.report,
    this.previousReport,
    required this.plantDayTeepAsc,
    required this.teepRollup,
    this.teepLoadFailed = false,
    this.teepFromRecentScan = false,
    this.serverDowntimeDaily = const [],
    this.serverDowntimeDailyLoadFailed = false,
  });

  final DateTime rangeStart;
  final DateTime rangeEndExclusive;
  final DowntimeAnalyticsReport report;
  final DowntimeAnalyticsReport? previousReport;

  /// Dnevni TEEP za pogon, lokalni kalendar, uzlazno.
  final List<TeepSummary> plantDayTeepAsc;
  final OperonixTeepRollup teepRollup;

  /// True ako Firestore upit nije uspio — KPI iz TEEP-a ostaju prazni, zastoji i dalje rade.
  final bool teepLoadFailed;

  /// True ako je upit s indeksom pao (ili nije dostupan) i korišten je širi upit (zadnjih 200 redaka).
  final bool teepFromRecentScan;

  /// Serverski dnevni sažetci [analytics_downtime_daily] za isti period (lokalni kalendar).
  final List<AnalyticsDowntimeDailyModel> serverDowntimeDaily;

  final bool serverDowntimeDailyLoadFailed;
}
