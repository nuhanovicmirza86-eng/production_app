import 'package:cloud_functions/cloud_functions.dart';

/// Callable mutacije za hub smjena i događaje uređaja.
class ProductionTrackingHubCallableService {
  ProductionTrackingHubCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> upsertProductionShiftDaySummary({
    required String companyId,
    required String plantKey,
    required String workDate,
    required int plannedHeadcount,
    required int presentCount,
    required int absentCount,
    Map<String, int>? absentByReason,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'workDate': workDate.trim(),
      'plannedHeadcount': plannedHeadcount,
      'presentCount': presentCount,
      'absentCount': absentCount,
    };
    if (absentByReason != null && absentByReason.isNotEmpty) {
      payload['absentByReason'] = absentByReason;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    final r = await _functions
        .httpsCallable('upsertProductionShiftDaySummary')
        .call<Map<String, dynamic>>(payload);
    final id = r.data['id']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw Exception('Nepoznat odgovor servera.');
    }
    return id;
  }

  Future<String> appendProductionPlantDeviceEvent({
    required String companyId,
    required String plantKey,
    required String kind,
    required String severity,
    required String title,
    String? detail,
    String? assetCode,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'kind': kind.trim(),
      'severity': severity.trim(),
      'title': title.trim(),
    };
    if (detail != null && detail.trim().isNotEmpty) {
      payload['detail'] = detail.trim();
    }
    if (assetCode != null && assetCode.trim().isNotEmpty) {
      payload['assetCode'] = assetCode.trim();
    }
    final r = await _functions
        .httpsCallable('appendProductionPlantDeviceEvent')
        .call<Map<String, dynamic>>(payload);
    final id = r.data['id']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw Exception('Nepoznat odgovor servera.');
    }
    return id;
  }

  Future<void> resolveProductionPlantDeviceEvent({
    required String companyId,
    required String plantKey,
    required String eventId,
  }) async {
    await _functions.httpsCallable('resolveProductionPlantDeviceEvent').call(
      <String, dynamic>{
        'companyId': companyId.trim(),
        'plantKey': plantKey.trim(),
        'eventId': eventId.trim(),
      },
    );
  }
}
