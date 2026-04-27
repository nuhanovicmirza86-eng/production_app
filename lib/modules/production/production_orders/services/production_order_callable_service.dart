import 'package:cloud_functions/cloud_functions.dart';

/// Mutacije [production_orders], [production_order_snapshots], [production_order_audit_logs] (Admin SDK) — 022 + Faza 2B.
class ProductionOrderCallableService {
  ProductionOrderCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  Future<Map<String, dynamic>> _callMutate(Map<String, dynamic> body) async {
    final res = await _f.httpsCallable('mutateProductionOrder').call(body);
    final raw = res.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  /// Vraća [productionOrderId] i opcionalno [productionOrderCode].
  Future<String> createProductionOrder({
    required String companyId,
    required String plantKey,
    String? plantCode,
    required String productId,
    required String productCode,
    required String productName,
    required double plannedQty,
    required String unit,
    required String bomId,
    required String bomVersion,
    required String routingId,
    required String routingVersion,
    required String createdBy,
    required DateTime scheduledEndAt,
    String? customerId,
    String? customerName,
    String? productionPlanId,
    String? productionPlanLineId,
    String? sourceOrderId,
    String? sourceOrderItemId,
    String? sourceOrderNumber,
    String? sourceCustomerId,
    String? sourceCustomerName,
    DateTime? sourceOrderDate,
    DateTime? requestedDeliveryDate,
    String? inputMaterialLot,
    String? workCenterId,
    String? workCenterCode,
    String? workCenterName,
    String? machineId,
    String? lineId,
  }) async {
    final create = <String, dynamic>{
      'productId': productId.trim(),
      'productCode': productCode.trim(),
      'productName': productName.trim(),
      'plannedQty': plannedQty,
      'unit': unit.trim(),
      'bomId': bomId.trim(),
      'bomVersion': bomVersion.trim(),
      'routingId': routingId.trim(),
      'routingVersion': routingVersion.trim(),
      'createdBy': createdBy.trim(),
      'scheduledEndAt': scheduledEndAt.toIso8601String(),
      if (plantCode != null && plantCode.trim().isNotEmpty)
        'plantCode': plantCode.trim(),
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      if (productionPlanId != null) 'productionPlanId': productionPlanId,
      if (productionPlanLineId != null)
        'productionPlanLineId': productionPlanLineId,
      if (sourceOrderId != null) 'sourceOrderId': sourceOrderId,
      if (sourceOrderItemId != null) 'sourceOrderItemId': sourceOrderItemId,
      if (sourceOrderNumber != null) 'sourceOrderNumber': sourceOrderNumber,
      if (sourceCustomerId != null) 'sourceCustomerId': sourceCustomerId,
      if (sourceCustomerName != null)
        'sourceCustomerName': sourceCustomerName,
      if (sourceOrderDate != null)
        'sourceOrderDate': sourceOrderDate.toIso8601String(),
      if (requestedDeliveryDate != null)
        'requestedDeliveryDate': requestedDeliveryDate.toIso8601String(),
      if (inputMaterialLot != null) 'inputMaterialLot': inputMaterialLot,
      if (workCenterId != null) 'workCenterId': workCenterId,
      if (workCenterCode != null) 'workCenterCode': workCenterCode,
      if (workCenterName != null) 'workCenterName': workCenterName,
      if (machineId != null) 'machineId': machineId,
      if (lineId != null) 'lineId': lineId,
    };
    final m = await _callMutate({
      'action': 'create',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'create': create,
    });
    final id = m['productionOrderId']?.toString() ?? '';
    if (id.isEmpty) {
      throw Exception('Server nije vratio productionOrderId.');
    }
    return id;
  }

  Future<void> updateCritical({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
    required String actorRole,
    double? plannedQty,
    DateTime? scheduledEndAt,
    String? changeReason,
  }) async {
    final body = <String, dynamic>{
      'action': 'updateCritical',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'actorUserId': actorUserId.trim(),
      'actorRole': actorRole.trim(),
    };
    if (plannedQty != null) body['plannedQty'] = plannedQty;
    if (scheduledEndAt != null) {
      body['scheduledEndAt'] = scheduledEndAt.toIso8601String();
    }
    if (changeReason != null) body['changeReason'] = changeReason;
    await _callMutate(body);
  }

  Future<void> updateMesAssignment({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
    String? workCenterId,
    String? workCenterCode,
    String? workCenterName,
    String? machineId,
    String? lineId,
  }) async {
    await _callMutate({
      'action': 'updateMesAssignment',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'actorUserId': actorUserId.trim(),
      'workCenterId': workCenterId,
      'workCenterCode': workCenterCode,
      'workCenterName': workCenterName,
      'machineId': machineId,
      'lineId': lineId,
    });
  }

  Future<void> release({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String releasedBy,
  }) async {
    await _callMutate({
      'action': 'release',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'releasedBy': releasedBy.trim(),
    });
  }

  Future<void> complete({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    await _callMutate({
      'action': 'complete',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'actorUserId': actorUserId.trim(),
    });
  }

  Future<void> closeOrder({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    await _callMutate({
      'action': 'close',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'actorUserId': actorUserId.trim(),
    });
  }

  Future<void> cancel({
    required String productionOrderId,
    required String companyId,
    required String plantKey,
    required String actorUserId,
  }) async {
    await _callMutate({
      'action': 'cancel',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'actorUserId': actorUserId.trim(),
    });
  }
}
