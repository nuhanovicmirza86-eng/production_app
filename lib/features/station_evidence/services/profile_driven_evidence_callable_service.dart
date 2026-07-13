import 'package:cloud_functions/cloud_functions.dart';

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

  Future<List<ProfileDrivenEvidenceListItem>> listProfileDrivenEvidenceSessions({
    required String companyId,
    String? plantKey,
    String? processProfileType,
    String? stationConfigId,
    String? operatorUid,
    String? dateFrom,
    String? dateTo,
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
    put('operatorUid', operatorUid);
    put('dateFrom', dateFrom);
    put('dateTo', dateTo);

    final res = await _functions
        .httpsCallable('listProfileDrivenEvidenceSessions')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje evidencija nije uspjelo.');
    }
    final rawItems = data['items'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map(
          (e) => ProfileDrivenEvidenceListItem.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
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
}
