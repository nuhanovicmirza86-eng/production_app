import '../../ai_analysis/ai_analysis_payloads.dart';
import '../models/analytics_downtime_daily_model.dart';
import '../models/analytics_summary_model.dart';

/// JSON za Callable [runAiAnalysis] s domenom `oee` (Operonix Analytics snimak).
class OperonixAnalyticsAiPayload {
  OperonixAnalyticsAiPayload._();

  static String _periodLabel(OperonixAnalyticsSnapshot s) {
    final a = s.rangeStart.toLocal();
    final b = s.rangeEndExclusive
        .subtract(const Duration(milliseconds: 1))
        .toLocal();
    return '${a.day.toString().padLeft(2, '0')}.'
        '${a.month.toString().padLeft(2, '0')}.'
        '${a.year} – '
        '${b.day.toString().padLeft(2, '0')}.'
        '${b.month.toString().padLeft(2, '0')}.'
        '${b.year}';
  }

  static Map<String, dynamic> build(OperonixAnalyticsSnapshot s) {
    final tr = s.teepRollup;
    final rep = s.report;
    final prev = s.previousReport;
    const topN = 8;

    final pareto = rep.paretoCategories
        .take(topN)
        .map(
          (e) => <String, dynamic>{
            'label': e.label,
            'minutes': e.minutes,
            'count': e.count,
            'pct': e.pctOfTotalMinutes,
            'cumulativePct': e.cumulativePct,
          },
        )
        .toList();

    final workCenters = rep.byWorkCenter
        .take(topN)
        .map(
          (e) => <String, dynamic>{
            'label': e.label,
            'downtimeMinutes': e.minutesClipped,
            'oeeAffectingMinutes': e.minutesOee,
            'events': e.events,
          },
        )
        .toList();

    final processes = rep.byProcess
        .take(topN)
        .map(
          (e) => <String, dynamic>{
            'label': e.label,
            'downtimeMinutes': e.minutesClipped,
            'events': e.events,
          },
        )
        .toList();

    Map<String, dynamic>? previousSummary;
    if (prev != null) {
      previousSummary = <String, dynamic>{
        'totalDowntimeMinutes': prev.totalMinutesClipped,
        'oeeAffectingMinutes': prev.minutesOeeLoss,
        'unplannedMinutes': prev.unplannedMinutes,
        'plannedMinutes': prev.plannedMinutes,
      };
    }

    return <String, dynamic>{
      ...AiAnalysisPayloads.oeeBlock(
        periodLabel: _periodLabel(s),
        oeePct: tr.hasTeepData ? tr.avgOee * 100 : null,
        availabilityPct: tr.hasTeepData ? tr.avgAvailabilityOee * 100 : null,
        performancePct: tr.hasTeepData ? tr.avgPerformance * 100 : null,
        qualityPct: tr.hasTeepData ? tr.avgQuality * 100 : null,
        losses: <String, dynamic>{
          'ooePct': tr.hasTeepData ? tr.avgOoe * 100 : null,
          'teepPct': tr.hasTeepData ? tr.avgTeep * 100 : null,
          'availabilityOoePct': tr.hasTeepData ? tr.avgAvailabilityOoe * 100 : null,
          'utilizationPct': tr.hasTeepData ? tr.avgUtilization * 100 : null,
          'fpyApproxPct': tr.fpy != null ? tr.fpy! * 100 : null,
          'scrapRateApproxPct': tr.scrapRate != null ? tr.scrapRate! * 100 : null,
          'planVsActualAvgPct': tr.planVsActualPct,
          'teepDayCount': tr.dayCount,
        },
        downtimeSummary: <String, dynamic>{
          'source': 'downtime_events_aggregated',
          'eventCountInPeriod': rep.eventsTouchingPeriod,
          'totalDowntimeMinutes': rep.totalMinutesClipped,
          'oeeAffectingMinutes': rep.minutesOeeLoss,
          'ooeAffectingMinutes': rep.minutesOoeLoss,
          'teepAffectingMinutes': rep.minutesTeepLoss,
          'unplannedVsPlanned': <String, dynamic>{
            'unplanned': rep.unplannedMinutes,
            'planned': rep.plannedMinutes,
          },
          'mttrResolvedMinutes': rep.mttrMinutesResolved,
          'paretoByCategory': pareto,
          'topWorkCentersByMinutes': workCenters,
          'topProcessesByMinutes': processes,
        },
      ),
      'kind': 'operonix_analytics_dashboard',
      'source': 'operonix_analytics_dashboard',
      'teepLoad': <String, dynamic>{
        'failed': s.teepLoadFailed,
        'fromRecent200Scan': s.teepFromRecentScan,
        'daySeriesPoints': s.plantDayTeepAsc.length,
      },
      'serverDowntimeDaily': _serverDowntimeDailyBlock(s),
      'previousPeriodSummary': previousSummary,
      'methodologyNote':
          'Kombinacija dnevnih teep_summaries (pogon) i agregata zastoja u periodu. '
          'Ne izvlači se svaki nalog; drill-down u aplikaciji preko zastoja / naloga.',
    };
  }

  /// Sažetak učitane `analytics_downtime_daily` liste za model (dnevni trend, ograničen broj redaka).
  static Map<String, dynamic> _serverDowntimeDailyBlock(OperonixAnalyticsSnapshot s) {
    const maxPerDayChronological = 45;
    final list = List<AnalyticsDowntimeDailyModel>.from(s.serverDowntimeDaily)
      ..sort((a, b) => a.summaryDateYmd.compareTo(b.summaryDateYmd));
    final int? totalMin = list.isEmpty
        ? null
        : list.fold<int>(0, (a, e) => a + e.totalMinutesClipped);
    final int? totalOee = list.isEmpty
        ? null
        : list.fold<int>(0, (a, e) => a + e.minutesOeeLoss);
    return <String, dynamic>{
      'loadFailed': s.serverDowntimeDailyLoadFailed,
      'documentCount': list.length,
      'totalMinutesFromServerDocs': totalMin,
      'totalOeeAffectingMinutesFromServerDocs': totalOee,
      'perDayChronological': list
          .take(maxPerDayChronological)
          .map(
            (e) => <String, dynamic>{
              'dateYmd': e.summaryDateYmd,
              'totalMinutes': e.totalMinutesClipped,
              'events': e.eventsWithMinutes,
              'oeeAffectingMinutes': e.minutesOeeLoss,
            },
          )
          .toList(),
      'perDayChronologicalNote':
          'Najviše $maxPerDayChronological dana kronološki (cijeli period može biti dulji).',
    };
  }
}
