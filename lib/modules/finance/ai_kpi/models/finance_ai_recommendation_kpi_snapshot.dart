import '../../shared/finance_callable_utils.dart';

/// Stopa s numeratorom/denominatorom — backend vraća `rate: null` kad denominator=0.
class FinanceAiKpiRateMetric {
  const FinanceAiKpiRateMetric({
    required this.numerator,
    required this.denominator,
    this.rate,
  });

  final int numerator;
  final int denominator;
  final double? rate;

  factory FinanceAiKpiRateMetric.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiKpiRateMetric(numerator: 0, denominator: 0);
    final numVal = raw['numerator'];
    final denVal = raw['denominator'];
    final rateVal = raw['rate'];
    return FinanceAiKpiRateMetric(
      numerator: numVal is num ? numVal.toInt() : int.tryParse('$numVal') ?? 0,
      denominator: denVal is num ? denVal.toInt() : int.tryParse('$denVal') ?? 0,
      rate: rateVal == null
          ? null
          : (rateVal is num ? rateVal.toDouble() : double.tryParse('$rateVal')),
    );
  }
}

class FinanceAiKpiCountValue {
  const FinanceAiKpiCountValue({required this.value});

  final int value;

  factory FinanceAiKpiCountValue.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiKpiCountValue(value: 0);
    final v = raw['value'];
    return FinanceAiKpiCountValue(
      value: v is num ? v.toInt() : int.tryParse('$v') ?? 0,
    );
  }
}

class FinanceAiKpiAvgTimeMetric {
  const FinanceAiKpiAvgTimeMetric({this.valueMs, this.pairCount = 0});

  final int? valueMs;
  final int pairCount;

  factory FinanceAiKpiAvgTimeMetric.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiKpiAvgTimeMetric();
    final v = raw['value'];
    final pc = raw['pairCount'];
    return FinanceAiKpiAvgTimeMetric(
      valueMs: v == null
          ? null
          : (v is num ? v.toInt() : int.tryParse('$v')),
      pairCount: pc is num ? pc.toInt() : int.tryParse('$pc') ?? 0,
    );
  }
}

class FinanceAiKpiConfirmedImpactSum {
  const FinanceAiKpiConfirmedImpactSum({
    this.byCurrency = const {},
    this.baseCurrency,
    this.baseCurrencyTotal,
    this.multiCurrencyWarning = false,
  });

  final Map<String, double> byCurrency;
  final String? baseCurrency;
  final double? baseCurrencyTotal;
  final bool multiCurrencyWarning;

  factory FinanceAiKpiConfirmedImpactSum.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const FinanceAiKpiConfirmedImpactSum();
    final m = Map<String, dynamic>.from(raw);
    final byCurRaw = m['byCurrency'];
    final byCurrency = <String, double>{};
    if (byCurRaw is Map) {
      for (final entry in byCurRaw.entries) {
        byCurrency[entry.key.toString()] =
            FinanceCallableUtils.parseAmount(entry.value);
      }
    }
    final baseTotal = m['baseCurrencyTotal'];
    return FinanceAiKpiConfirmedImpactSum(
      byCurrency: byCurrency,
      baseCurrency: (m['baseCurrency'] ?? '').toString().trim().isEmpty
          ? null
          : m['baseCurrency'].toString(),
      baseCurrencyTotal: baseTotal == null
          ? null
          : FinanceCallableUtils.parseAmount(baseTotal),
      multiCurrencyWarning: m['multiCurrencyWarning'] == true,
    );
  }
}

class FinanceAiRecommendationKpiMetrics {
  const FinanceAiRecommendationKpiMetrics({
    required this.shownCount,
    required this.viewedRate,
    required this.acceptanceRate,
    required this.rejectionRateByReason,
    required this.rejectionCountByReason,
    required this.actionStartRate,
    required this.actionCompletionRate,
    required this.confirmedOutcomeRate,
    required this.positiveConfirmedOutcomeRate,
    required this.outcomeUnknownRate,
    required this.avgTimeShownToActionCompletedMs,
    required this.confirmedFinancialImpactSum,
    required this.outcomeCountByStatus,
    required this.outcomeCountByAttribution,
    required this.interactionTypeCounts,
    required this.evaluatedOutcomeCount,
  });

  final FinanceAiKpiCountValue shownCount;
  final FinanceAiKpiRateMetric viewedRate;
  final FinanceAiKpiRateMetric acceptanceRate;
  final Map<String, FinanceAiKpiRateMetric> rejectionRateByReason;
  final Map<String, int> rejectionCountByReason;
  final FinanceAiKpiRateMetric actionStartRate;
  final FinanceAiKpiRateMetric actionCompletionRate;
  final FinanceAiKpiRateMetric confirmedOutcomeRate;
  final FinanceAiKpiRateMetric positiveConfirmedOutcomeRate;
  final FinanceAiKpiRateMetric outcomeUnknownRate;
  final FinanceAiKpiAvgTimeMetric avgTimeShownToActionCompletedMs;
  final FinanceAiKpiConfirmedImpactSum confirmedFinancialImpactSum;
  final Map<String, int> outcomeCountByStatus;
  final Map<String, int> outcomeCountByAttribution;
  final Map<String, int> interactionTypeCounts;
  final FinanceAiKpiCountValue evaluatedOutcomeCount;

  factory FinanceAiRecommendationKpiMetrics.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) {
      return FinanceAiRecommendationKpiMetrics(
        shownCount: const FinanceAiKpiCountValue(value: 0),
        viewedRate: const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        acceptanceRate: const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        rejectionRateByReason: const {},
        rejectionCountByReason: const {},
        actionStartRate: const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        actionCompletionRate: const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        confirmedOutcomeRate: const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        positiveConfirmedOutcomeRate:
            const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        outcomeUnknownRate: const FinanceAiKpiRateMetric(numerator: 0, denominator: 0),
        avgTimeShownToActionCompletedMs: const FinanceAiKpiAvgTimeMetric(),
        confirmedFinancialImpactSum: const FinanceAiKpiConfirmedImpactSum(),
        outcomeCountByStatus: const {},
        outcomeCountByAttribution: const {},
        interactionTypeCounts: const {},
        evaluatedOutcomeCount: const FinanceAiKpiCountValue(value: 0),
      );
    }
    final m = Map<String, dynamic>.from(raw);

    final rejRatesRaw = m['rejection_rate_by_reason'];
    final rejRates = <String, FinanceAiKpiRateMetric>{};
    if (rejRatesRaw is Map) {
      for (final entry in rejRatesRaw.entries) {
        rejRates[entry.key.toString()] = FinanceAiKpiRateMetric.fromMap(
          entry.value is Map
              ? Map<String, dynamic>.from(entry.value as Map)
              : null,
        );
      }
    }

    final rejCountsRaw = m['rejection_count_by_reason'];
    final rejCounts = <String, int>{};
    if (rejCountsRaw is Map) {
      for (final entry in rejCountsRaw.entries) {
        final v = entry.value;
        rejCounts[entry.key.toString()] =
            v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      }
    }

    final statusRaw = m['outcome_count_by_status'];
    final statusCounts = <String, int>{};
    if (statusRaw is Map) {
      for (final entry in statusRaw.entries) {
        final v = entry.value;
        statusCounts[entry.key.toString()] =
            v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      }
    }

    final attrRaw = m['outcome_count_by_attribution'];
    final attrCounts = <String, int>{};
    if (attrRaw is Map) {
      for (final entry in attrRaw.entries) {
        final v = entry.value;
        attrCounts[entry.key.toString()] =
            v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      }
    }

    final typeRaw = m['interaction_type_counts'];
    final typeCounts = <String, int>{};
    if (typeRaw is Map) {
      for (final entry in typeRaw.entries) {
        final v = entry.value;
        typeCounts[entry.key.toString()] =
            v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      }
    }

    return FinanceAiRecommendationKpiMetrics(
      shownCount: FinanceAiKpiCountValue.fromMap(
        m['shown_count'] is Map
            ? Map<String, dynamic>.from(m['shown_count'] as Map)
            : null,
      ),
      viewedRate: FinanceAiKpiRateMetric.fromMap(
        m['viewed_rate'] is Map
            ? Map<String, dynamic>.from(m['viewed_rate'] as Map)
            : null,
      ),
      acceptanceRate: FinanceAiKpiRateMetric.fromMap(
        m['acceptance_rate'] is Map
            ? Map<String, dynamic>.from(m['acceptance_rate'] as Map)
            : null,
      ),
      rejectionRateByReason: rejRates,
      rejectionCountByReason: rejCounts,
      actionStartRate: FinanceAiKpiRateMetric.fromMap(
        m['action_start_rate'] is Map
            ? Map<String, dynamic>.from(m['action_start_rate'] as Map)
            : null,
      ),
      actionCompletionRate: FinanceAiKpiRateMetric.fromMap(
        m['action_completion_rate'] is Map
            ? Map<String, dynamic>.from(m['action_completion_rate'] as Map)
            : null,
      ),
      confirmedOutcomeRate: FinanceAiKpiRateMetric.fromMap(
        m['confirmed_outcome_rate'] is Map
            ? Map<String, dynamic>.from(m['confirmed_outcome_rate'] as Map)
            : null,
      ),
      positiveConfirmedOutcomeRate: FinanceAiKpiRateMetric.fromMap(
        m['positive_confirmed_outcome_rate'] is Map
            ? Map<String, dynamic>.from(
                m['positive_confirmed_outcome_rate'] as Map,
              )
            : null,
      ),
      outcomeUnknownRate: FinanceAiKpiRateMetric.fromMap(
        m['outcome_unknown_rate'] is Map
            ? Map<String, dynamic>.from(m['outcome_unknown_rate'] as Map)
            : null,
      ),
      avgTimeShownToActionCompletedMs: FinanceAiKpiAvgTimeMetric.fromMap(
        m['avg_time_shown_to_action_completed_ms'] is Map
            ? Map<String, dynamic>.from(
                m['avg_time_shown_to_action_completed_ms'] as Map,
              )
            : null,
      ),
      confirmedFinancialImpactSum: FinanceAiKpiConfirmedImpactSum.fromMap(
        m['confirmed_financial_impact_sum'] is Map
            ? Map<String, dynamic>.from(
                m['confirmed_financial_impact_sum'] as Map,
              )
            : null,
      ),
      outcomeCountByStatus: statusCounts,
      outcomeCountByAttribution: attrCounts,
      interactionTypeCounts: typeCounts,
      evaluatedOutcomeCount: FinanceAiKpiCountValue.fromMap(
        m['evaluated_outcome_count'] is Map
            ? Map<String, dynamic>.from(m['evaluated_outcome_count'] as Map)
            : null,
      ),
    );
  }
}

/// Read-only KPI snapshot iz `getFinanceAiRecommendationKpiSnapshot`.
class FinanceAiRecommendationKpiSnapshot {
  const FinanceAiRecommendationKpiSnapshot({
    required this.companyId,
    required this.periodFrom,
    required this.periodTo,
    required this.plantKey,
    required this.scope,
    this.baseCurrency,
    required this.contractVersion,
    required this.evaluatorVersion,
    required this.metrics,
    required this.sourceCollections,
  });

  final String companyId;
  final DateTime periodFrom;
  final DateTime periodTo;
  final String plantKey;
  final String scope;
  final String? baseCurrency;
  final String contractVersion;
  final String evaluatorVersion;
  final FinanceAiRecommendationKpiMetrics metrics;
  final List<String> sourceCollections;

  factory FinanceAiRecommendationKpiSnapshot.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    final m = Map<String, dynamic>.from(raw);
    final period = m['period'];
    DateTime? from;
    DateTime? to;
    if (period is Map) {
      from = FinanceCallableUtils.parseTimestamp(period['from']);
      to = FinanceCallableUtils.parseTimestamp(period['to']);
    }
    return FinanceAiRecommendationKpiSnapshot(
      companyId: (m['companyId'] ?? '').toString(),
      periodFrom: from ?? DateTime.fromMillisecondsSinceEpoch(0),
      periodTo: to ?? DateTime.fromMillisecondsSinceEpoch(0),
      plantKey: (m['plantKey'] ?? '').toString(),
      scope: (m['scope'] ?? '').toString(),
      baseCurrency: (m['baseCurrency'] ?? '').toString().trim().isEmpty
          ? null
          : m['baseCurrency'].toString(),
      contractVersion: (m['contractVersion'] ?? '').toString(),
      evaluatorVersion: (m['evaluatorVersion'] ?? '').toString(),
      metrics: FinanceAiRecommendationKpiMetrics.fromMap(
        m['metrics'] is Map
            ? Map<String, dynamic>.from(m['metrics'] as Map)
            : null,
      ),
      sourceCollections: m['sourceCollections'] is List
          ? (m['sourceCollections'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}
