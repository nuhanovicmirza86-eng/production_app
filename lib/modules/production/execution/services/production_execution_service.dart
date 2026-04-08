import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionExecutionService {
  final FirebaseFirestore _firestore;

  ProductionExecutionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _execution =>
      _firestore.collection('production_execution');

  String _s(dynamic value) => (value ?? '').toString().trim();

  double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  Map<String, dynamic> _cleanParameters(Map<String, dynamic>? raw) {
    if (raw == null) return <String, dynamic>{};

    final cleaned = <String, dynamic>{};

    raw.forEach((key, value) {
      final normalizedKey = _s(key);
      if (normalizedKey.isEmpty) return;

      if (value == null) return;

      if (value is String) {
        final text = value.trim();
        if (text.isEmpty) return;
        cleaned[normalizedKey] = text;
        return;
      }

      if (value is num || value is bool) {
        cleaned[normalizedKey] = value;
        return;
      }

      cleaned[normalizedKey] = value;
    });

    return cleaned;
  }

  List<Map<String, dynamic>> _cleanMaterialsUsed(
    List<Map<String, dynamic>>? raw,
  ) {
    if (raw == null) return <Map<String, dynamic>>[];

    final cleaned = <Map<String, dynamic>>[];

    for (final item in raw) {
      final materialName = _s(item['materialName']);
      final qty = _d(item['qty']);
      final unit = _s(item['unit']);

      if (materialName.isEmpty) continue;
      if (qty <= 0) continue;
      if (unit.isEmpty) continue;

      cleaned.add(<String, dynamic>{
        'materialId': _nullableString(item['materialId']),
        'materialCode': _nullableString(item['materialCode']),
        'materialName': materialName,
        'qty': qty,
        'unit': unit,
        'notes': _nullableString(item['notes']),
      });
    }

    return cleaned;
  }

  String? _nullableString(dynamic value) {
    final text = _s(value);
    return text.isEmpty ? null : text;
  }

  void _validateExecutionType(String executionType) {
    const allowed = <String>{'discrete', 'batch', 'process', 'continuous'};

    if (!allowed.contains(executionType)) {
      throw Exception('executionType nije validan.');
    }
  }

  void _validateStatus(String status) {
    const allowed = <String>{'started', 'paused', 'completed'};

    if (!allowed.contains(status)) {
      throw Exception('status execution zapisa nije validan.');
    }
  }

  Future<Map<String, dynamic>> _requireExecutionDoc({
    required String executionId,
    required String companyId,
    required String plantKey,
  }) async {
    final doc = await _execution.doc(executionId).get();

    if (!doc.exists) {
      throw Exception('Execution zapis ne postoji.');
    }

    final data = doc.data();
    if (data == null) {
      throw Exception('Execution zapis nema podatke.');
    }

    if (_s(data['companyId']) != companyId ||
        _s(data['plantKey']) != plantKey) {
      throw Exception('Nemaš pristup ovom execution zapisu.');
    }

    return <String, dynamic>{'id': doc.id, ...data};
  }

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
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedOrderId = _s(productionOrderId);
    final normalizedOrderCode = _s(productionOrderCode);
    final normalizedProductId = _s(productId);
    final normalizedProductCode = _s(productCode);
    final normalizedProductName = _s(productName);
    final normalizedRoutingId = _s(routingId);
    final normalizedRoutingVersion = _s(routingVersion);
    final normalizedStepId = _s(stepId);
    final normalizedStepName = _s(stepName);
    final normalizedExecutionType = _s(executionType).toLowerCase();
    final normalizedOperatorId = _s(operatorId);
    final normalizedOperatorName = _nullableString(operatorName);
    final normalizedCreatedBy = _s(createdBy).isEmpty
        ? normalizedOperatorId
        : _s(createdBy);
    final normalizedUnit = _nullableString(unit);

    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedOrderId.isEmpty) {
      throw Exception('productionOrderId je obavezan.');
    }
    if (normalizedOrderCode.isEmpty) {
      throw Exception('productionOrderCode je obavezan.');
    }
    if (normalizedProductId.isEmpty) {
      throw Exception('productId je obavezan.');
    }
    if (normalizedProductCode.isEmpty) {
      throw Exception('productCode je obavezan.');
    }
    if (normalizedProductName.isEmpty) {
      throw Exception('productName je obavezan.');
    }
    if (normalizedRoutingId.isEmpty) {
      throw Exception('routingId je obavezan.');
    }
    if (normalizedRoutingVersion.isEmpty) {
      throw Exception('routingVersion je obavezan.');
    }
    if (normalizedStepId.isEmpty) {
      throw Exception('stepId je obavezan.');
    }
    if (normalizedStepName.isEmpty) {
      throw Exception('stepName je obavezan.');
    }
    if (normalizedOperatorId.isEmpty) {
      throw Exception('operatorId je obavezan.');
    }

    _validateExecutionType(normalizedExecutionType);

    final hasActiveForOperatorAndStep =
        await hasActiveExecutionForOperatorAndStep(
          companyId: normalizedCompanyId,
          plantKey: normalizedPlantKey,
          productionOrderId: normalizedOrderId,
          stepId: normalizedStepId,
          operatorId: normalizedOperatorId,
        );

    if (hasActiveForOperatorAndStep) {
      throw Exception(
        'Operator već ima aktivan execution za isti nalog i isti korak.',
      );
    }

    final now = DateTime.now();
    final docRef = _execution.doc();

    final payload = <String, dynamic>{
      'companyId': normalizedCompanyId,
      'plantKey': normalizedPlantKey,
      'productionOrderId': normalizedOrderId,
      'productionOrderCode': normalizedOrderCode,
      'productId': normalizedProductId,
      'productCode': normalizedProductCode,
      'productName': normalizedProductName,
      'routingId': normalizedRoutingId,
      'routingVersion': normalizedRoutingVersion,
      'stepId': normalizedStepId,
      'stepCode': _nullableString(stepCode),
      'stepName': normalizedStepName,
      'executionType': normalizedExecutionType,
      'status': 'started',
      'startedAt': now,
      'endedAt': null,
      'operatorId': normalizedOperatorId,
      'operatorName': normalizedOperatorName,
      'goodQty': goodQty ?? 0,
      'scrapQty': scrapQty ?? 0,
      'reworkQty': reworkQty ?? 0,
      'unit': normalizedUnit,
      'parameters': _cleanParameters(parameters),
      'materialsUsed': _cleanMaterialsUsed(materialsUsed),
      'notes': _nullableString(notes),
      'workCenterId': _nullableString(workCenterId),
      'workCenterCode': _nullableString(workCenterCode),
      'workCenterName': _nullableString(workCenterName),
      'lineId': _nullableString(lineId),
      'lineCode': _nullableString(lineCode),
      'lineName': _nullableString(lineName),
      'machineId': _nullableString(machineId),
      'machineCode': _nullableString(machineCode),
      'machineName': _nullableString(machineName),
      'shiftCode': _nullableString(shiftCode),
      'createdAt': now,
      'createdBy': normalizedCreatedBy,
      'updatedAt': now,
      'updatedBy': normalizedCreatedBy,
    };

    await docRef.set(payload);

    return docRef.id;
  }

  Future<void> saveProgress({
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
    final normalizedExecutionId = _s(executionId);
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedUpdatedBy = _s(updatedBy);

    if (normalizedExecutionId.isEmpty) {
      throw Exception('executionId je obavezan.');
    }
    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedUpdatedBy.isEmpty) {
      throw Exception('updatedBy je obavezan.');
    }

    final current = await _requireExecutionDoc(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );

    final currentStatus = _s(current['status']).toLowerCase();
    _validateStatus(currentStatus);

    if (currentStatus == 'completed') {
      throw Exception('Completed execution se ne može mijenjati.');
    }

    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
      'updatedBy': normalizedUpdatedBy,
    };

    if (goodQty != null) {
      updates['goodQty'] = goodQty;
    }

    if (scrapQty != null) {
      updates['scrapQty'] = scrapQty;
    }

    if (reworkQty != null) {
      updates['reworkQty'] = reworkQty;
    }

    if (unit != null) {
      final normalizedUnit = _nullableString(unit);
      if (normalizedUnit == null) {
        updates['unit'] = FieldValue.delete();
      } else {
        updates['unit'] = normalizedUnit;
      }
    }

    if (notes != null) {
      final normalizedNotes = _nullableString(notes);
      if (normalizedNotes == null) {
        updates['notes'] = FieldValue.delete();
      } else {
        updates['notes'] = normalizedNotes;
      }
    }

    if (parameters != null) {
      updates['parameters'] = _cleanParameters(parameters);
    }

    if (materialsUsed != null) {
      updates['materialsUsed'] = _cleanMaterialsUsed(materialsUsed);
    }

    await _execution.doc(normalizedExecutionId).update(updates);
  }

  Future<void> pauseExecution({
    required String executionId,
    required String companyId,
    required String plantKey,
    required String updatedBy,
    String? notes,
    double? goodQty,
    double? scrapQty,
    double? reworkQty,
    String? unit,
    Map<String, dynamic>? parameters,
    List<Map<String, dynamic>>? materialsUsed,
  }) async {
    final normalizedExecutionId = _s(executionId);
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedUpdatedBy = _s(updatedBy);

    if (normalizedExecutionId.isEmpty) {
      throw Exception('executionId je obavezan.');
    }
    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedUpdatedBy.isEmpty) {
      throw Exception('updatedBy je obavezan.');
    }

    final current = await _requireExecutionDoc(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );

    final currentStatus = _s(current['status']).toLowerCase();
    _validateStatus(currentStatus);

    if (currentStatus == 'completed') {
      throw Exception('Completed execution se ne može pauzirati.');
    }

    final updates = <String, dynamic>{
      'status': 'paused',
      'updatedAt': DateTime.now(),
      'updatedBy': normalizedUpdatedBy,
    };

    if (goodQty != null) {
      updates['goodQty'] = goodQty;
    }

    if (scrapQty != null) {
      updates['scrapQty'] = scrapQty;
    }

    if (reworkQty != null) {
      updates['reworkQty'] = reworkQty;
    }

    if (unit != null) {
      final normalizedUnit = _nullableString(unit);
      if (normalizedUnit == null) {
        updates['unit'] = FieldValue.delete();
      } else {
        updates['unit'] = normalizedUnit;
      }
    }

    if (notes != null) {
      final normalizedNotes = _nullableString(notes);
      if (normalizedNotes == null) {
        updates['notes'] = FieldValue.delete();
      } else {
        updates['notes'] = normalizedNotes;
      }
    }

    if (parameters != null) {
      updates['parameters'] = _cleanParameters(parameters);
    }

    if (materialsUsed != null) {
      updates['materialsUsed'] = _cleanMaterialsUsed(materialsUsed);
    }

    await _execution.doc(normalizedExecutionId).update(updates);
  }

  Future<void> resumeExecution({
    required String executionId,
    required String companyId,
    required String plantKey,
    required String updatedBy,
    String? notes,
  }) async {
    final normalizedExecutionId = _s(executionId);
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedUpdatedBy = _s(updatedBy);

    if (normalizedExecutionId.isEmpty) {
      throw Exception('executionId je obavezan.');
    }
    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedUpdatedBy.isEmpty) {
      throw Exception('updatedBy je obavezan.');
    }

    final current = await _requireExecutionDoc(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );

    final currentStatus = _s(current['status']).toLowerCase();
    _validateStatus(currentStatus);

    if (currentStatus == 'completed') {
      throw Exception('Completed execution se ne može nastaviti.');
    }

    final updates = <String, dynamic>{
      'status': 'started',
      'updatedAt': DateTime.now(),
      'updatedBy': normalizedUpdatedBy,
    };

    if (notes != null) {
      final normalizedNotes = _nullableString(notes);
      if (normalizedNotes == null) {
        updates['notes'] = FieldValue.delete();
      } else {
        updates['notes'] = normalizedNotes;
      }
    }

    await _execution.doc(normalizedExecutionId).update(updates);
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
    final normalizedExecutionId = _s(executionId);
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedUpdatedBy = _s(updatedBy);

    if (normalizedExecutionId.isEmpty) {
      throw Exception('executionId je obavezan.');
    }
    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedUpdatedBy.isEmpty) {
      throw Exception('updatedBy je obavezan.');
    }

    final current = await _requireExecutionDoc(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );

    final currentStatus = _s(current['status']).toLowerCase();
    _validateStatus(currentStatus);

    if (currentStatus == 'completed') {
      throw Exception('Execution je već završen.');
    }

    final now = DateTime.now();

    final updates = <String, dynamic>{
      'status': 'completed',
      'endedAt': now,
      'updatedAt': now,
      'updatedBy': normalizedUpdatedBy,
    };

    if (goodQty != null) {
      updates['goodQty'] = goodQty;
    }

    if (scrapQty != null) {
      updates['scrapQty'] = scrapQty;
    }

    if (reworkQty != null) {
      updates['reworkQty'] = reworkQty;
    }

    if (unit != null) {
      final normalizedUnit = _nullableString(unit);
      if (normalizedUnit == null) {
        updates['unit'] = FieldValue.delete();
      } else {
        updates['unit'] = normalizedUnit;
      }
    }

    if (notes != null) {
      final normalizedNotes = _nullableString(notes);
      if (normalizedNotes == null) {
        updates['notes'] = FieldValue.delete();
      } else {
        updates['notes'] = normalizedNotes;
      }
    }

    if (parameters != null) {
      updates['parameters'] = _cleanParameters(parameters);
    }

    if (materialsUsed != null) {
      updates['materialsUsed'] = _cleanMaterialsUsed(materialsUsed);
    }

    await _execution.doc(normalizedExecutionId).update(updates);
  }

  Future<Map<String, dynamic>?> getById({
    required String executionId,
    required String companyId,
    required String plantKey,
  }) async {
    final normalizedExecutionId = _s(executionId);
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);

    if (normalizedExecutionId.isEmpty) {
      throw Exception('executionId je obavezan.');
    }
    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }

    final doc = await _execution.doc(normalizedExecutionId).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) {
      return null;
    }

    if (_s(data['companyId']) != normalizedCompanyId ||
        _s(data['plantKey']) != normalizedPlantKey) {
      throw Exception('Nemaš pristup ovom execution zapisu.');
    }

    return <String, dynamic>{'id': doc.id, ...data};
  }

  Future<List<Map<String, dynamic>>> getExecutionsForOrder({
    required String companyId,
    required String plantKey,
    required String productionOrderId,
  }) async {
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedOrderId = _s(productionOrderId);

    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedOrderId.isEmpty) {
      throw Exception('productionOrderId je obavezan.');
    }

    final snapshot = await _execution
        .where('companyId', isEqualTo: normalizedCompanyId)
        .where('plantKey', isEqualTo: normalizedPlantKey)
        .where('productionOrderId', isEqualTo: normalizedOrderId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<List<Map<String, dynamic>>> getActiveExecutionsForOrder({
    required String companyId,
    required String plantKey,
    required String productionOrderId,
  }) async {
    final all = await getExecutionsForOrder(
      companyId: companyId,
      plantKey: plantKey,
      productionOrderId: productionOrderId,
    );

    return all.where((item) {
      final status = _s(item['status']).toLowerCase();
      return status == 'started' || status == 'paused';
    }).toList();
  }

  Future<List<Map<String, dynamic>>>
  getActiveExecutionsForOrderStepAndOperator({
    required String companyId,
    required String plantKey,
    required String productionOrderId,
    required String stepId,
    required String operatorId,
  }) async {
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    final normalizedOrderId = _s(productionOrderId);
    final normalizedStepId = _s(stepId);
    final normalizedOperatorId = _s(operatorId);

    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }
    if (normalizedPlantKey.isEmpty) {
      throw Exception('plantKey je obavezan.');
    }
    if (normalizedOrderId.isEmpty) {
      throw Exception('productionOrderId je obavezan.');
    }
    if (normalizedStepId.isEmpty) {
      throw Exception('stepId je obavezan.');
    }
    if (normalizedOperatorId.isEmpty) {
      throw Exception('operatorId je obavezan.');
    }

    final all = await getActiveExecutionsForOrder(
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
      productionOrderId: normalizedOrderId,
    );

    return all.where((item) {
      return _s(item['stepId']) == normalizedStepId &&
          _s(item['operatorId']) == normalizedOperatorId;
    }).toList();
  }

  Future<bool> hasActiveExecutionForOperatorAndStep({
    required String companyId,
    required String plantKey,
    required String productionOrderId,
    required String stepId,
    required String operatorId,
  }) async {
    final active = await getActiveExecutionsForOrderStepAndOperator(
      companyId: companyId,
      plantKey: plantKey,
      productionOrderId: productionOrderId,
      stepId: stepId,
      operatorId: operatorId,
    );

    return active.isNotEmpty;
  }
}
