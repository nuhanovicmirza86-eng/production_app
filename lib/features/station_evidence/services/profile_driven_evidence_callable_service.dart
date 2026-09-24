import 'package:cloud_functions/cloud_functions.dart';

import '../export/first_piece_approval_release_document.dart';
import '../models/profile_driven_evidence_session.dart';

String profileDrivenEvidenceErrorMessage(Object error) {
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

class ProfileDrivenEvidenceCallableService {
  ProfileDrivenEvidenceCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ProfileDrivenEvidenceListResult> listProfileDrivenEvidenceSessions({
    required String companyId,
    String? plantKey,
    String? processProfileType,
    String? stationConfigId,
    String? evidenceConfigId,
    String? operatorUid,
    String? dateFrom,
    String? dateTo,
    /// `all` | `none` | `step`
    String? operationFilter,
    int? routingStepOrder,
    String? routingStepOperationName,
    String? routingStepOperationCode,
    int limit = 50,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'limit': limit,
    };
    void put(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) payload[key] = v;
    }

    put('plantKey', plantKey);
    put('processProfileType', processProfileType);
    put('stationConfigId', stationConfigId);
    put('evidenceConfigId', evidenceConfigId);
    put('operatorUid', operatorUid);
    put('dateFrom', dateFrom);
    put('dateTo', dateTo);
    put('operationFilter', operationFilter);
    put('routingStepOperationName', routingStepOperationName);
    put('routingStepOperationCode', routingStepOperationCode);
    if (routingStepOrder != null) {
      payload['routingStepOrder'] = routingStepOrder;
    }

    final res = await _functions
        .httpsCallable('listProfileDrivenEvidenceSessions')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje evidencija nije uspjelo.');
    }
    final rawItems = data['items'];
    final items = rawItems is! List
        ? const <ProfileDrivenEvidenceListItem>[]
        : rawItems
            .whereType<Map>()
            .map(
              (e) => ProfileDrivenEvidenceListItem.fromMap(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false);
    final rawFacets = data['operationFacets'];
    final facets = rawFacets is! List
        ? const <ProfileDrivenEvidenceOperationFacet>[]
        : rawFacets
            .whereType<Map>()
            .map(
              (e) => ProfileDrivenEvidenceOperationFacet.fromMap(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false);
    return ProfileDrivenEvidenceListResult(items: items, operationFacets: facets);
  }

  Future<ProfileDrivenEvidenceSessionDetail> getProfileDrivenEvidenceSession({
    required String companyId,
    required String sessionId,
  }) async {
    final res = await _functions
        .httpsCallable('getProfileDrivenEvidenceSession')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'sessionId': sessionId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje detalja evidencije nije uspjelo.');
    }
    final raw = data['session'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return ProfileDrivenEvidenceSessionDetail.fromMap(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<void> recordProductionEvidencePdfGenerated({
    required String companyId,
    required String sessionId,
  }) async {
    final res = await _functions
        .httpsCallable('recordProductionEvidencePdfGenerated')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'sessionId': sessionId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Zapis generisanja PDF-a nije sačuvan.');
    }
  }

  Future<List<ProductionEvidenceAuditItem>> listProductionEvidenceSessionAuditTrail({
    required String companyId,
    required String sessionId,
  }) async {
    final res = await _functions
        .httpsCallable('listProductionEvidenceSessionAuditTrail')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'sessionId': sessionId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje historije evidencije nije uspjelo.');
    }
    final rawItems = data['items'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((e) => ProductionEvidenceAuditItem.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// M1-I3-G — validiran release dokument za PDF odobrenja prvog komada.
  Future<FirstPieceApprovalReleaseDocument>
  getFirstPieceApprovalReleaseDocument({
    required String companyId,
    required String sessionId,
  }) async {
    final res = await _functions
        .httpsCallable('getFirstPieceApprovalReleaseDocument')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'sessionId': sessionId.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Priprema release dokumenta nije uspjela.');
    }
    final raw = data['document'];
    if (raw is! Map) {
      throw Exception('Nepotpun odgovor servera.');
    }
    return FirstPieceApprovalReleaseDocument.fromMap(
      Map<String, dynamic>.from(raw),
    );
  }
}
