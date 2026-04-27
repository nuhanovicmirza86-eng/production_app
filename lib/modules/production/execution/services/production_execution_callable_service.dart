import 'package:cloud_functions/cloud_functions.dart';

/// Transakcije [production_execution] + [production_orders] (mesExecutionStart / mesExecutionComplete).
class ProductionExecutionCallableService {
  ProductionExecutionCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  /// Vraća [executionId].
  Future<String> startExecution({
    required String companyId,
    required String plantKey,
    required String productionOrderId,
    required String productionOrderCode,
    required String productId,
    required String productCode,
    required String productName,
    required String routingId,
    required String routingVersion,
    required String stepId,
    required String stepName,
    required String executionType,
    required String operatorId,
    String? operatorName,
    String? createdBy,
    String? stepCode,
    String? unit,
    String? workCenterId,
    String? workCenterCode,
    String? workCenterName,
    String? lineId,
    String? lineCode,
    String? lineName,
    String? machineId,
    String? machineCode,
    String? machineName,
    String? shiftCode,
    String? notes,
    double? goodQty,
    double? scrapQty,
    double? reworkQty,
    Map<String, dynamic>? parameters,
    List<Map<String, dynamic>>? materialsUsed,
  }) async {
    final body = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'productionOrderId': productionOrderId.trim(),
      'productionOrderCode': productionOrderCode.trim(),
      'productId': productId.trim(),
      'productCode': productCode.trim(),
      'productName': productName.trim(),
      'routingId': routingId.trim(),
      'routingVersion': routingVersion.trim(),
      'stepId': stepId.trim(),
      'stepName': stepName.trim(),
      'executionType': executionType.trim(),
      'operatorId': operatorId.trim(),
      if (operatorName != null) 'operatorName': operatorName,
      if (createdBy != null && createdBy.trim().isNotEmpty) 'createdBy': createdBy.trim(),
      if (stepCode != null) 'stepCode': stepCode,
      if (unit != null) 'unit': unit,
      if (workCenterId != null) 'workCenterId': workCenterId,
      if (workCenterCode != null) 'workCenterCode': workCenterCode,
      if (workCenterName != null) 'workCenterName': workCenterName,
      if (lineId != null) 'lineId': lineId,
      if (lineCode != null) 'lineCode': lineCode,
      if (lineName != null) 'lineName': lineName,
      if (machineId != null) 'machineId': machineId,
      if (machineCode != null) 'machineCode': machineCode,
      if (machineName != null) 'machineName': machineName,
      if (shiftCode != null) 'shiftCode': shiftCode,
      if (notes != null) 'notes': notes,
      if (goodQty != null) 'goodQty': goodQty,
      if (scrapQty != null) 'scrapQty': scrapQty,
      if (reworkQty != null) 'reworkQty': reworkQty,
      if (parameters != null) 'parameters': parameters,
      if (materialsUsed != null) 'materialsUsed': materialsUsed,
    };
    final res = await _f.httpsCallable('mesExecutionStart').call(body);
    final raw = res.data;
    if (raw is Map) {
      final id = Map<String, dynamic>.from(raw)['executionId']?.toString() ?? '';
      if (id.isNotEmpty) return id;
    }
    throw Exception('Server nije vratio executionId.');
  }

  Future<void> completeExecution({
    required String executionId,
    required String companyId,
    required String plantKey,
    required String updatedBy,
    double? goodQty,
    double? scrapQty,
    double? reworkQty,
    String? unit,
    String? notes,
    Map<String, dynamic>? parameters,
    List<Map<String, dynamic>>? materialsUsed,
  }) async {
    final body = <String, dynamic>{
      'executionId': executionId.trim(),
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'updatedBy': updatedBy.trim(),
      if (goodQty != null) 'goodQty': goodQty,
      if (scrapQty != null) 'scrapQty': scrapQty,
      if (reworkQty != null) 'reworkQty': reworkQty,
      if (unit != null) 'unit': unit,
      if (notes != null) 'notes': notes,
      if (parameters != null) 'parameters': parameters,
      if (materialsUsed != null) 'materialsUsed': materialsUsed,
    };
    await _f.httpsCallable('mesExecutionComplete').call(body);
  }

  /// `action`: `saveProgress` | `pause` | `resume`
  Future<void> executeUpdate({
    required String action,
    required String executionId,
    required String companyId,
    required String plantKey,
    required String updatedBy,
    String? ooePauseReasonCode,
    double? goodQty,
    double? scrapQty,
    double? reworkQty,
    String? unit,
    String? notes,
    Map<String, dynamic>? parameters,
    List<Map<String, dynamic>>? materialsUsed,
  }) async {
    final body = <String, dynamic>{
      'action': action.trim(),
      'executionId': executionId.trim(),
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'updatedBy': updatedBy.trim(),
      if (ooePauseReasonCode != null) 'ooePauseReasonCode': ooePauseReasonCode,
      if (goodQty != null) 'goodQty': goodQty,
      if (scrapQty != null) 'scrapQty': scrapQty,
      if (reworkQty != null) 'reworkQty': reworkQty,
      if (unit != null) 'unit': unit,
      if (notes != null) 'notes': notes,
      if (parameters != null) 'parameters': parameters,
      if (materialsUsed != null) 'materialsUsed': materialsUsed,
    };
    await _f.httpsCallable('mesExecutionUpdate').call(body);
  }
}
