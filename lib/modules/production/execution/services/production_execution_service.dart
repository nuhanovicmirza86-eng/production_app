import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../ooe/services/ooe_execution_integration.dart';
import 'production_execution_callable_service.dart';

class ProductionExecutionService {
  ProductionExecutionService({
    FirebaseFirestore? firestore,
    ProductionExecutionCallableService? callables,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _callables = callables ?? ProductionExecutionCallableService();

  final FirebaseFirestore _firestore;
  final ProductionExecutionCallableService _callables;

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
    final normalizedCreatedBy = _s(createdBy).isEmpty
        ? normalizedOperatorId
        : _s(createdBy);

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

    final id = await _callables.startExecution(
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
      productionOrderId: normalizedOrderId,
      productionOrderCode: normalizedOrderCode,
      productId: normalizedProductId,
      productCode: normalizedProductCode,
      productName: normalizedProductName,
      routingId: normalizedRoutingId,
      routingVersion: normalizedRoutingVersion,
      stepId: normalizedStepId,
      stepName: normalizedStepName,
      executionType: normalizedExecutionType,
      operatorId: normalizedOperatorId,
      operatorName: operatorName,
      createdBy: normalizedCreatedBy,
      stepCode: stepCode,
      unit: unit,
      workCenterId: workCenterId,
      workCenterCode: workCenterCode,
      workCenterName: workCenterName,
      lineId: lineId,
      lineCode: lineCode,
      lineName: lineName,
      machineId: machineId,
      machineCode: machineCode,
      machineName: machineName,
      shiftCode: shiftCode,
      notes: notes,
      goodQty: goodQty,
      scrapQty: scrapQty,
      reworkQty: reworkQty,
      parameters: parameters,
      materialsUsed: materialsUsed,
    );

    final afterStart = await getById(
      executionId: id,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );
    if (afterStart != null) {
      await OoeExecutionIntegration.onExecutionStarted(
        companyScope: <String, dynamic>{
          'companyId': normalizedCompanyId,
          'plantKey': normalizedPlantKey,
        },
        executionPayload: afterStart,
      );
    }

    return id;
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

    await _callables.executeUpdate(
      action: 'saveProgress',
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
      updatedBy: normalizedUpdatedBy,
      goodQty: goodQty,
      scrapQty: scrapQty,
      reworkQty: reworkQty,
      unit: unit,
      notes: notes,
      parameters: parameters != null ? _cleanParameters(parameters) : null,
      materialsUsed: materialsUsed != null
          ? _cleanMaterialsUsed(materialsUsed)
          : null,
    );
  }

  Future<void> pauseExecution({
    required String executionId,
    required String companyId,
    required String plantKey,
    required String updatedBy,
    String? notes,
    /// Šifra iz `ooe_loss_reasons` (OOE) — u `openState` postaje [reasonCode] + `tpmLossKey`.
    /// `null` ili prazno: briše polje (nema MES razloga za ovu pauzu).
    String? ooePauseReasonCode,
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

    await _callables.executeUpdate(
      action: 'pause',
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
      updatedBy: normalizedUpdatedBy,
      ooePauseReasonCode: ooePauseReasonCode,
      goodQty: goodQty,
      scrapQty: scrapQty,
      reworkQty: reworkQty,
      unit: unit,
      notes: notes,
      parameters: parameters != null ? _cleanParameters(parameters) : null,
      materialsUsed: materialsUsed != null
          ? _cleanMaterialsUsed(materialsUsed)
          : null,
    );

    final afterPause = await getById(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );
    if (afterPause != null) {
      await OoeExecutionIntegration.onExecutionPaused(
        companyScope: <String, dynamic>{
          'companyId': normalizedCompanyId,
          'plantKey': normalizedPlantKey,
        },
        executionPayload: afterPause,
      );
    }
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

    await _callables.executeUpdate(
      action: 'resume',
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
      updatedBy: normalizedUpdatedBy,
      notes: notes,
    );

    final afterResume = await getById(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );
    if (afterResume != null) {
      await OoeExecutionIntegration.onExecutionResumed(
        companyScope: <String, dynamic>{
          'companyId': normalizedCompanyId,
          'plantKey': normalizedPlantKey,
        },
        executionPayload: afterResume,
      );
    }
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

    await _callables.completeExecution(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
      updatedBy: normalizedUpdatedBy,
      goodQty: goodQty,
      scrapQty: scrapQty,
      reworkQty: reworkQty,
      unit: unit,
      notes: notes,
      parameters: parameters,
      materialsUsed: materialsUsed,
    );

    final afterComplete = await getById(
      executionId: normalizedExecutionId,
      companyId: normalizedCompanyId,
      plantKey: normalizedPlantKey,
    );
    if (afterComplete != null) {
      await OoeExecutionIntegration.onExecutionCompleted(
        companyScope: <String, dynamic>{
          'companyId': normalizedCompanyId,
          'plantKey': normalizedPlantKey,
        },
        executionAfterPayload: afterComplete,
      );
    }
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

  /// Više naloga u jednom ili više upita ([whereIn] max 10 ID-eva). Ključ = `productionOrderId`.
  Future<Map<String, List<Map<String, dynamic>>>> getExecutionsByOrderIds({
    required String companyId,
    required String plantKey,
    required Set<String> productionOrderIds,
  }) async {
    final normalizedCompanyId = _s(companyId);
    final normalizedPlantKey = _s(plantKey);
    if (normalizedCompanyId.isEmpty || normalizedPlantKey.isEmpty) {
      return {};
    }
    final flat = productionOrderIds.map(_s).where((e) => e.isNotEmpty).toList();
    if (flat.isEmpty) {
      return {};
    }
    final out = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < flat.length; i += 10) {
      final chunk = flat.sublist(i, min(i + 10, flat.length));
      final snap = await _execution
          .where('companyId', isEqualTo: normalizedCompanyId)
          .where('plantKey', isEqualTo: normalizedPlantKey)
          .where('productionOrderId', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final m = doc.data();
        final oid = _s(m['productionOrderId']);
        if (oid.isEmpty) {
          continue;
        }
        out.putIfAbsent(oid, () => []).add(<String, dynamic>{'id': doc.id, ...m});
      }
    }
    return out;
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
