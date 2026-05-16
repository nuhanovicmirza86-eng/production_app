import 'package:cloud_functions/cloud_functions.dart';

/// Callable-i Supplier Selection v1 — backend rangiranje + audit.
///
/// Regija mora odgovarati [FirebaseFunctions] konfiguraciji (`europe-west1`).
class SupplierSelectionCallableService {
  SupplierSelectionCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> createSupplierSelectionRequest({
    required String companyId,
    required String plantKey,
    required String productId,
    required String materialGroup,
    String processKey = '',
    required double requiredQuantity,
    required String requiredDateIso,
    required List<String> candidateSupplierIds,
    String requestSource = 'manual_ui',
    Map<String, double>? priceScores,
    Map<String, double>? availabilityScores,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw StateError('companyId je obavezan.');
    final raw = await _functions
        .httpsCallable('createSupplierSelectionRequest')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'plantKey': plantKey.trim(),
          'productId': productId.trim(),
          'materialGroup': materialGroup.trim(),
          if (processKey.trim().isNotEmpty) 'processKey': processKey.trim(),
          'requiredQuantity': requiredQuantity,
          'requiredDate': requiredDateIso.trim(),
          'candidateSupplierIds': candidateSupplierIds
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'requestSource': requestSource.trim(),
          ...{
            if (priceScores != null && priceScores.isNotEmpty)
              'priceScores': priceScores,
            if (availabilityScores != null && availabilityScores.isNotEmpty)
              'availabilityScores': availabilityScores,
          },
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Kreiranje zahtjeva nije uspjelo.');
    }
    final id = (data['requestId'] ?? '').toString().trim();
    if (id.isEmpty) throw StateError('Prazan requestId.');
    return id;
  }

  Future<Map<String, dynamic>> rankSupplierCandidates({
    required String companyId,
    required String requestId,
  }) async {
    final raw = await _functions
        .httpsCallable('rankSupplierCandidates')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'requestId': requestId.trim(),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Rangiranje nije uspjelo.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<String> confirmSupplierSelection({
    required String companyId,
    required String selectionResultId,
    required String decision,
    String chosenSupplierId = '',
    String reasonCode = '',
    String reasonNote = '',
  }) async {
    final raw = await _functions
        .httpsCallable('confirmSupplierSelection')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'selectionResultId': selectionResultId.trim(),
          'chosenSupplierId': chosenSupplierId.trim(),
          'decision': decision.trim(),
          if (reasonCode.trim().isNotEmpty) 'reasonCode': reasonCode.trim(),
          if (reasonNote.trim().isNotEmpty) 'reasonNote': reasonNote.trim(),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Potvrda odabira nije uspjela.');
    }
    final id = (data['feedbackId'] ?? '').toString().trim();
    if (id.isEmpty) throw StateError('Prazan feedbackId.');
    return id;
  }

  Future<void> recordSupplierSelectionOutcome({
    required String companyId,
    required String feedbackId,
    dynamic actualDeliveryResult,
    dynamic actualQualityResult,
    bool claimCreated = false,
    bool lateDelivery = false,
    bool quantityDeviation = false,
    String outcomeNotes = '',
  }) async {
    final raw = await _functions
        .httpsCallable('recordSupplierSelectionOutcome')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'feedbackId': feedbackId.trim(),
          if (actualDeliveryResult != null)
            'actualDeliveryResult': actualDeliveryResult,
          if (actualQualityResult != null)
            'actualQualityResult': actualQualityResult,
          'claimCreated': claimCreated,
          'lateDelivery': lateDelivery,
          'quantityDeviation': quantityDeviation,
          if (outcomeNotes.trim().isNotEmpty)
            'outcomeNotes': outcomeNotes.trim(),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Zapis ishoda nije uspio.');
    }
  }

  /// Čitanje preko Callable-a (nema direktnog Firestore read na `supplier_selection_*`).
  Future<List<Map<String, dynamic>>> listSupplierSelectionRequests({
    required String companyId,
    String plantKey = '',
    int limit = 50,
  }) async {
    final raw = await _functions
        .httpsCallable('listSupplierSelectionRequests')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          if (plantKey.trim().isNotEmpty) 'plantKey': plantKey.trim(),
          'limit': limit.clamp(1, 100),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Dohvat liste zahtjeva nije uspio.');
    }
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getSupplierSelectionResult({
    required String companyId,
    required String selectionResultId,
  }) async {
    final raw = await _functions
        .httpsCallable('getSupplierSelectionResult')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'selectionResultId': selectionResultId.trim(),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Dohvat rezultata rangiranja nije uspio.');
    }
    final result = data['result'];
    if (result is! Map) {
      throw StateError('Očekivan je objekt result.');
    }
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> listSupplierSelectionFeedback({
    required String companyId,
    String selectionResultId = '',
    int limit = 50,
  }) async {
    final raw = await _functions
        .httpsCallable('listSupplierSelectionFeedback')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          if (selectionResultId.trim().isNotEmpty)
            'selectionResultId': selectionResultId.trim(),
          'limit': limit.clamp(1, 100),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Dohvat liste povratnih informacija nije uspio.');
    }
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listSupplierDecisionAuditLogs({
    required String companyId,
    int limit = 50,
  }) async {
    final raw = await _functions
        .httpsCallable('listSupplierDecisionAuditLogs')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'limit': limit.clamp(1, 100),
        });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Dohvat audit zapisa nije uspio.');
    }
    final items = data['items'];
    if (items is! List) return [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
