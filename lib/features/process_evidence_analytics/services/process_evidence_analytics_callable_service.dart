import 'package:cloud_functions/cloud_functions.dart';

import '../models/process_evidence_analytics_models.dart';

String processEvidenceAnalyticsErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final msg = (error.message ?? '').trim();
    if (msg.isNotEmpty) return msg;
    return error.code;
  }
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('[firebase_functions/', '');
}

class ProcessEvidenceAnalyticsCallableService {
  ProcessEvidenceAnalyticsCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static const breakdownDimensions = <String>[
    'profile',
    'station',
    'operator',
    'operation_type',
    'scrap_reason',
    'material_type',
    'product',
  ];

  Future<ProcessEvidenceAnalyticsSummary> getSummary({
    required String companyId,
    required ProcessEvidenceAnalyticsFilters filters,
  }) async {
    final res = await _functions
        .httpsCallable('getProcessEvidenceAnalyticsSummary')
        .call<Map<String, dynamic>>(
          filters.toCallablePayload(companyId),
        );
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje analitike nije uspjelo.');
    }
    final rawSummary = data['summary'];
    if (rawSummary is! Map) {
      throw Exception('Nepotpun odgovor servera (summary).');
    }
    return ProcessEvidenceAnalyticsSummary.fromMap({
      ...Map<String, dynamic>.from(rawSummary),
      'truncated': data['truncated'] == true,
      if (data['sessionCountAnalyzed'] != null)
        'sessionCountAnalyzed': data['sessionCountAnalyzed'],
    });
  }

  Future<List<ProcessEvidenceBreakdownRow>> getBreakdown({
    required String companyId,
    required ProcessEvidenceAnalyticsFilters filters,
    required String dimension,
  }) async {
    final payload = filters.toCallablePayload(companyId)
      ..['dimension'] = dimension.trim();

    final res = await _functions
        .httpsCallable('getProcessEvidenceAnalyticsBreakdown')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje breakdown-a nije uspjelo ($dimension).');
    }
    final rawRows = data['rows'];
    if (rawRows is! List) return const [];
    return rawRows
        .whereType<Map>()
        .map(
          (e) => ProcessEvidenceBreakdownRow.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Future<({
    List<WorkerPerformanceKpiRow> operators,
    bool normativeReady,
    String? normativeComparisonNote,
  })> getWorkerPerformanceKpiSnapshot({
    required String companyId,
    required ProcessEvidenceAnalyticsFilters filters,
  }) async {
    final res = await _functions
        .httpsCallable('getWorkerPerformanceKpiSnapshot')
        .call<Map<String, dynamic>>(
          filters.toCallablePayload(companyId),
        );
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje KPI radnika nije uspjelo.');
    }
    final rawOperators = data['operators'];
    final operators = <WorkerPerformanceKpiRow>[];
    if (rawOperators is List) {
      for (final item in rawOperators) {
        if (item is Map) {
          operators.add(
            WorkerPerformanceKpiRow.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return (
      operators: operators,
      normativeReady: data['normativeReady'] == true,
      normativeComparisonNote: (data['normativeComparisonNote'] ?? '')
          .toString()
          .trim()
          .isEmpty
          ? null
          : (data['normativeComparisonNote'] ?? '').toString().trim(),
    );
  }

  Future<ProcessEvidenceAnalyticsLoadResult> loadAll({
    required String companyId,
    required ProcessEvidenceAnalyticsFilters filters,
  }) async {
    final summaryFuture = getSummary(companyId: companyId, filters: filters);
    final workerFuture = getWorkerPerformanceKpiSnapshot(
      companyId: companyId,
      filters: filters,
    );
    final breakdownFutures = <String, Future<List<ProcessEvidenceBreakdownRow>>>{};
    for (final dimension in breakdownDimensions) {
      breakdownFutures[dimension] = getBreakdown(
        companyId: companyId,
        filters: filters,
        dimension: dimension,
      );
    }

    final summary = await summaryFuture;
    final worker = await workerFuture;
    final breakdowns = <String, List<ProcessEvidenceBreakdownRow>>{};
    for (final entry in breakdownFutures.entries) {
      breakdowns[entry.key] = await entry.value;
    }

    return ProcessEvidenceAnalyticsLoadResult(
      summary: summary,
      breakdowns: breakdowns,
      operators: worker.operators,
      summaryTruncated: summary.truncated,
    );
  }
}
