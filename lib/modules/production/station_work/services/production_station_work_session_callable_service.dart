import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_station_work_session.dart';

class ActiveStructuredSessionResult {
  const ActiveStructuredSessionResult({
    required this.session,
    this.structuredTables = const {},
  });

  final ProductionStationWorkSession session;
  final Map<String, List<Map<String, dynamic>>> structuredTables;
}

String productionStationWorkSessionErrorMessage(Object error) {
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

class ProductionStationWorkSessionCallableService {
  ProductionStationWorkSessionCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ProductionStationWorkSession> startProductionStationWorkSession({
    required String companyId,
    required int stationSlot,
    String? productionOrderId,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'stationSlot': stationSlot,
    };
    final orderId = productionOrderId?.trim();
    if (orderId != null && orderId.isNotEmpty) {
      payload['productionOrderId'] = orderId;
    }

    final res = await _functions
        .httpsCallable('startProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Pokretanje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      (data['sessionId'] ?? '').toString(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<ProductionStationWorkSession> startProductionEvidenceWorkSession({
    required String companyId,
    required String evidenceConfigId,
  }) async {
    final res = await _functions
        .httpsCallable('startProductionEvidenceWorkSession')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'evidenceConfigId': evidenceConfigId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Pokretanje evidencije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      (data['sessionId'] ?? '').toString(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<({ProductionStationWorkSession session, String? trackingEntryId})>
  updateProductionStationWorkSession({
    required String companyId,
    required String sessionId,
    required String action,
    double goodQtyDelta = 0,
    double scrapQtyDelta = 0,
    double reworkQtyDelta = 0,
    String? comment,
    Map<String, dynamic>? fieldValues,
    List<Map<String, dynamic>>? processedItems,
    List<Map<String, dynamic>>? materialConsumptions,
    List<Map<String, dynamic>>? operatorWorkLogs,
    List<Map<String, dynamic>>? scrapItems,
    List<Map<String, dynamic>>? controlledItems,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
      'action': action.trim(),
    };
    if (action == 'record_output') {
      payload['goodQtyDelta'] = goodQtyDelta;
      payload['scrapQtyDelta'] = scrapQtyDelta;
      payload['reworkQtyDelta'] = reworkQtyDelta;
      payload['comment'] = (comment ?? '').trim();
    } else if (action == 'set_comment') {
      payload['comment'] = (comment ?? '').trim();
    } else if (action == 'set_field_values') {
      payload['fieldValues'] = fieldValues ?? const <String, dynamic>{};
      if (processedItems != null) payload['processedItems'] = processedItems;
      if (materialConsumptions != null) {
        payload['materialConsumptions'] = materialConsumptions;
      }
      if (operatorWorkLogs != null) {
        payload['operatorWorkLogs'] = operatorWorkLogs;
      }
      if (scrapItems != null) payload['scrapItems'] = scrapItems;
      if (controlledItems != null) payload['controlledItems'] = controlledItems;
    } else if (comment != null && comment.trim().isNotEmpty) {
      payload['comment'] = comment.trim();
    }

    final res = await _functions
        .httpsCallable('updateProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Ažuriranje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return (
      session: ProductionStationWorkSession.fromMap(
        sessionId.trim(),
        Map<String, dynamic>.from(raw),
      ),
      trackingEntryId: (data['trackingEntryId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['trackingEntryId'] ?? '').toString().trim(),
    );
  }

  Future<ProductionStationWorkSession> setProfileFieldValues({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
  }) async {
    final result = await updateProductionStationWorkSession(
      companyId: companyId,
      sessionId: sessionId,
      action: 'set_field_values',
      fieldValues: fieldValues,
    );
    return result.session;
  }

  Future<ProductionStationWorkSession> finishProductionStationWorkSession({
    required String companyId,
    required String sessionId,
    Map<String, dynamic>? fieldValues,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
    };
    if (fieldValues != null && fieldValues.isNotEmpty) {
      payload['fieldValues'] = fieldValues;
    }

    final res = await _functions
        .httpsCallable('finishProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Završetak sesije nije uspio.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      sessionId.trim(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<ProductionStationWorkSession?> getActiveProductionStationWorkSession({
    required String companyId,
    required int stationSlot,
  }) async {
    final result = await getActiveStructuredSession(
      companyId: companyId,
      stationSlot: stationSlot,
    );
    return result?.session;
  }

  Future<ActiveStructuredSessionResult?> getActiveStructuredSession({
    required String companyId,
    required int stationSlot,
  }) async {
    final res = await _functions
        .httpsCallable('getActiveProductionStationWorkSession')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'stationSlot': stationSlot,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw == null) return null;
    if (raw is! Map) return null;
    final id = (data['sessionId'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    return ActiveStructuredSessionResult(
      session: ProductionStationWorkSession.fromMap(
        id,
        Map<String, dynamic>.from(raw),
      ),
      structuredTables: _parseStructuredTables(data['structuredTables']),
    );
  }

  Future<ProductionStationWorkSession> updateStructuredProfileSession({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
    required List<Map<String, dynamic>> processedItems,
    required List<Map<String, dynamic>> materialConsumptions,
    required List<Map<String, dynamic>> operatorWorkLogs,
    required List<Map<String, dynamic>> scrapItems,
  }) async {
    final result = await updateProductionStationWorkSession(
      companyId: companyId,
      sessionId: sessionId,
      action: 'set_field_values',
      fieldValues: fieldValues,
      processedItems: processedItems,
      materialConsumptions: materialConsumptions,
      operatorWorkLogs: operatorWorkLogs,
      scrapItems: scrapItems,
    );
    return result.session;
  }

  Future<ProductionStationWorkSession> updateFinalControlProfileSession({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
    required List<Map<String, dynamic>> controlledItems,
  }) async {
    final result = await updateProductionStationWorkSession(
      companyId: companyId,
      sessionId: sessionId,
      action: 'set_field_values',
      fieldValues: fieldValues,
      controlledItems: controlledItems,
    );
    return result.session;
  }

  Future<ProductionStationWorkSession> finishFinalControlProfileSession({
    required String companyId,
    required String sessionId,
    Map<String, dynamic>? fieldValues,
    List<Map<String, dynamic>>? controlledItems,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
    };
    if (fieldValues != null && fieldValues.isNotEmpty) {
      payload['fieldValues'] = fieldValues;
    }
    if (controlledItems != null) payload['controlledItems'] = controlledItems;

    final res = await _functions
        .httpsCallable('finishProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Završetak sesije nije uspio.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      sessionId.trim(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<ProductionStationWorkSession> updateCatalogEvidenceSession({
    required String companyId,
    required String sessionId,
    required Map<String, dynamic> fieldValues,
    required Map<String, dynamic> tablePayload,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
      'action': 'set_field_values',
      'fieldValues': fieldValues,
      ...tablePayload,
    };

    final res = await _functions
        .httpsCallable('updateProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Ažuriranje sesije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      sessionId.trim(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<ProductionStationWorkSession> finishCatalogEvidenceSession({
    required String companyId,
    required String sessionId,
    Map<String, dynamic>? fieldValues,
    Map<String, dynamic>? tablePayload,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
    };
    if (fieldValues != null && fieldValues.isNotEmpty) {
      payload['fieldValues'] = fieldValues;
    }
    if (tablePayload != null) {
      payload.addAll(tablePayload);
    }

    final res = await _functions
        .httpsCallable('finishProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Završetak sesije nije uspio.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      sessionId.trim(),
      Map<String, dynamic>.from(raw),
    );
  }

  Future<ProductionStationWorkSession> finishStructuredProfileSession({
    required String companyId,
    required String sessionId,
    Map<String, dynamic>? fieldValues,
    List<Map<String, dynamic>>? processedItems,
    List<Map<String, dynamic>>? materialConsumptions,
    List<Map<String, dynamic>>? operatorWorkLogs,
    List<Map<String, dynamic>>? scrapItems,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'sessionId': sessionId.trim(),
    };
    if (fieldValues != null && fieldValues.isNotEmpty) {
      payload['fieldValues'] = fieldValues;
    }
    if (processedItems != null) payload['processedItems'] = processedItems;
    if (materialConsumptions != null) {
      payload['materialConsumptions'] = materialConsumptions;
    }
    if (operatorWorkLogs != null) payload['operatorWorkLogs'] = operatorWorkLogs;
    if (scrapItems != null) payload['scrapItems'] = scrapItems;

    final res = await _functions
        .httpsCallable('finishProductionStationWorkSession')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Završetak sesije nije uspio.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProductionStationWorkSession.fromMap(
      sessionId.trim(),
      Map<String, dynamic>.from(raw),
    );
  }

  Map<String, List<Map<String, dynamic>>> _parseStructuredTables(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<Map<String, dynamic>>>{};
    raw.forEach((key, value) {
      if (value is! List) return;
      out[key.toString()] = value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    });
    return out;
  }
}
