import 'package:cloud_functions/cloud_functions.dart';

import '../models/tracking_scrap_line.dart';

/// Callable mutacije za `production_operator_tracking` (server postavlja createdAt).
class ProductionOperatorTrackingCallableService {
  ProductionOperatorTrackingCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> createProductionOperatorTrackingEntry({
    required String companyId,
    required String plantKey,
    required String phase,
    required String workDate,
    required String itemCode,
    required String itemName,
    required double goodQty,
    required String unit,
    String? productId,
    String? workCenterId,
    String? productionOrderId,
    String? commercialOrderId,
    String? rawMaterialOrderCode,
    String? lineOrBatchRef,
    String? releaseToolOrRodRef,
    String? customerName,
    String? rawWorkOperatorName,
    String? preparedByDisplayName,
    String? sourceQrPayload,
    String? notes,
    List<TrackingScrapLine> scrapBreakdown = const [],
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      throw Exception('companyId i plantKey su obavezni.');
    }
    final payload = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'phase': phase.trim(),
      'workDate': workDate.trim(),
      'itemCode': itemCode.trim(),
      'itemName': itemName.trim(),
      'goodQty': goodQty,
      'unit': unit.trim().isEmpty ? 'kom' : unit.trim(),
      'scrapBreakdown': scrapBreakdown.map((e) => e.toMap()).toList(),
    };
    if (productId != null && productId.trim().isNotEmpty) {
      payload['productId'] = productId.trim();
    }
    if (workCenterId != null && workCenterId.trim().isNotEmpty) {
      payload['workCenterId'] = workCenterId.trim();
    }
    if (productionOrderId != null && productionOrderId.trim().isNotEmpty) {
      payload['productionOrderId'] = productionOrderId.trim();
    }
    if (commercialOrderId != null && commercialOrderId.trim().isNotEmpty) {
      payload['commercialOrderId'] = commercialOrderId.trim();
    }
    if (rawMaterialOrderCode != null && rawMaterialOrderCode.trim().isNotEmpty) {
      payload['rawMaterialOrderCode'] = rawMaterialOrderCode.trim();
    }
    if (lineOrBatchRef != null && lineOrBatchRef.trim().isNotEmpty) {
      payload['lineOrBatchRef'] = lineOrBatchRef.trim();
    }
    if (releaseToolOrRodRef != null && releaseToolOrRodRef.trim().isNotEmpty) {
      payload['releaseToolOrRodRef'] = releaseToolOrRodRef.trim();
    }
    if (customerName != null && customerName.trim().isNotEmpty) {
      payload['customerName'] = customerName.trim();
    }
    if (rawWorkOperatorName != null && rawWorkOperatorName.trim().isNotEmpty) {
      payload['rawWorkOperatorName'] = rawWorkOperatorName.trim();
    }
    if (preparedByDisplayName != null && preparedByDisplayName.trim().isNotEmpty) {
      payload['preparedByDisplayName'] = preparedByDisplayName.trim();
    }
    if (sourceQrPayload != null && sourceQrPayload.trim().isNotEmpty) {
      payload['sourceQrPayload'] = sourceQrPayload.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }

    final res = await _functions
        .httpsCallable('createProductionOperatorTrackingEntry')
        .call<Map<String, dynamic>>(payload);
    final id = (res.data['entryId'] ?? '').toString().trim();
    if (res.data['success'] != true || id.isEmpty) {
      throw Exception('Snimanje unosa nije uspjelo.');
    }
    return id;
  }

  Future<void> correctProductionOperatorTrackingEntry({
    required String companyId,
    required String entryId,
    required String itemCode,
    required String itemName,
    required double goodQty,
    required String unit,
    String? productId,
    String? workCenterId,
    String? productionOrderId,
    String? commercialOrderId,
    String? rawMaterialOrderCode,
    String? lineOrBatchRef,
    String? releaseToolOrRodRef,
    String? customerName,
    String? rawWorkOperatorName,
    String? preparedByDisplayName,
    String? sourceQrPayload,
    String? notes,
    List<TrackingScrapLine> scrapBreakdown = const [],
    String? reason,
  }) async {
    final cid = companyId.trim();
    final eid = entryId.trim();
    if (cid.isEmpty || eid.isEmpty) {
      throw Exception('companyId i entryId su obavezni.');
    }
    final payload = <String, dynamic>{
      'companyId': cid,
      'entryId': eid,
      'itemCode': itemCode.trim(),
      'itemName': itemName.trim(),
      'goodQty': goodQty,
      'unit': unit.trim().isEmpty ? 'kom' : unit.trim(),
      'scrapBreakdown': scrapBreakdown.map((e) => e.toMap()).toList(),
    };
    if (productId != null && productId.trim().isNotEmpty) {
      payload['productId'] = productId.trim();
    }
    if (workCenterId != null && workCenterId.trim().isNotEmpty) {
      payload['workCenterId'] = workCenterId.trim();
    }
    if (productionOrderId != null && productionOrderId.trim().isNotEmpty) {
      payload['productionOrderId'] = productionOrderId.trim();
    }
    if (commercialOrderId != null && commercialOrderId.trim().isNotEmpty) {
      payload['commercialOrderId'] = commercialOrderId.trim();
    }
    if (rawMaterialOrderCode != null && rawMaterialOrderCode.trim().isNotEmpty) {
      payload['rawMaterialOrderCode'] = rawMaterialOrderCode.trim();
    }
    if (lineOrBatchRef != null && lineOrBatchRef.trim().isNotEmpty) {
      payload['lineOrBatchRef'] = lineOrBatchRef.trim();
    }
    if (releaseToolOrRodRef != null && releaseToolOrRodRef.trim().isNotEmpty) {
      payload['releaseToolOrRodRef'] = releaseToolOrRodRef.trim();
    }
    if (customerName != null && customerName.trim().isNotEmpty) {
      payload['customerName'] = customerName.trim();
    }
    if (rawWorkOperatorName != null && rawWorkOperatorName.trim().isNotEmpty) {
      payload['rawWorkOperatorName'] = rawWorkOperatorName.trim();
    }
    if (preparedByDisplayName != null && preparedByDisplayName.trim().isNotEmpty) {
      payload['preparedByDisplayName'] = preparedByDisplayName.trim();
    }
    if (sourceQrPayload != null && sourceQrPayload.trim().isNotEmpty) {
      payload['sourceQrPayload'] = sourceQrPayload.trim();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }

    final res = await _functions
        .httpsCallable('correctProductionOperatorTrackingEntry')
        .call<Map<String, dynamic>>(payload);
    if (res.data['success'] != true) {
      throw Exception('Ispravak nije uspio.');
    }
  }
}
