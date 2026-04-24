import 'package:cloud_functions/cloud_functions.dart';

/// Serverski preračun `ooe_shift_summaries` preko Callable [recomputeOoeShiftSummary].
class OoeShiftSummaryCallableService {
  OoeShiftSummaryCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  static String shiftDateYmd(DateTime localDate) {
    final d = localDate;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<Map<String, dynamic>> recomputeShiftSummary({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime shiftDateLocal,
    String shiftId = 'DAY',
    int? operatingTimeSeconds,
    String? productId,
    String? orderId,
    String? lineId,
    double? idealCycleTimeSeconds,
  }) async {
    final callable = _f.httpsCallable('recomputeOoeShiftSummary');
    final shiftDate = shiftDateYmd(shiftDateLocal);
    final result = await callable.call({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'machineId': machineId.trim(),
      'shiftId': shiftId.trim(),
      'shiftDate': shiftDate,
      'windowStart': windowStart.toUtc().toIso8601String(),
      'windowEnd': windowEnd.toUtc().toIso8601String(),
      'operatingTimeSeconds': ?operatingTimeSeconds,
      if (productId != null && productId.trim().isNotEmpty)
        'productId': productId.trim(),
      if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId.trim(),
      if (lineId != null && lineId.trim().isNotEmpty) 'lineId': lineId.trim(),
      if (idealCycleTimeSeconds != null && idealCycleTimeSeconds > 0)
        'idealCycleTimeSeconds': idealCycleTimeSeconds,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
