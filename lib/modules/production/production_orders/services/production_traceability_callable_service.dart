import 'package:cloud_functions/cloud_functions.dart';

/// Callable [getProductionTraceabilityBundle] — IATF lanac po nalogu.
class ProductionTraceabilityCallableService {
  ProductionTraceabilityCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> getTraceabilityBundle({
    required String companyId,
    required String productionOrderId,
  }) async {
    final res = await _functions.httpsCallable('getProductionTraceabilityBundle').call(
      {
        'companyId': companyId,
        'productionOrderId': productionOrderId,
      },
    );
    return Map<String, dynamic>.from((res.data as Map?) ?? const {});
  }
}
