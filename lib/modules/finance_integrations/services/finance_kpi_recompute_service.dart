import 'package:cloud_functions/cloud_functions.dart';

/// Callable [recomputeFinanceKpiSnapshot]: preračun `finance_kpi_snapshots` iz `downtime_events`.
class FinanceKpiRecomputeService {
  FinanceKpiRecomputeService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Prazan [plantKey]: admin rollup — svi pogonici + zbroj.
  Future<void> recompute({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
  }) async {
    final res = await _functions
        .httpsCallable('recomputeFinanceKpiSnapshot')
        .call(<String, dynamic>{
      'companyId': companyId.trim(),
      'businessYearId': businessYearId.trim(),
      'periodYear': periodYear,
      'periodMonth': periodMonth,
      'plantKey': plantKey.trim(),
    });
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Preračun KPI nije uspio.');
    }
  }
}
