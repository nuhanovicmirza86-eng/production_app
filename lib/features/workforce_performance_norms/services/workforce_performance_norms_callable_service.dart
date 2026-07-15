import 'package:cloud_functions/cloud_functions.dart';

import '../models/workforce_performance_norm_models.dart';

String workforcePerformanceNormsErrorMessage(Object error) {
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

class WorkforcePerformanceNormsCallableService {
  WorkforcePerformanceNormsCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<WorkforcePerformanceNorm>> listNorms({
    required String companyId,
    String? status,
    String? plantKey,
    String? normGroupId,
    int limit = 100,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'limit': limit,
    };
    if ((status ?? '').trim().isNotEmpty) payload['status'] = status!.trim();
    if ((plantKey ?? '').trim().isNotEmpty) payload['plantKey'] = plantKey!.trim();
    if ((normGroupId ?? '').trim().isNotEmpty) {
      payload['normGroupId'] = normGroupId!.trim();
    }

    final res = await _functions
        .httpsCallable('listWorkforcePerformanceNorms')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje normativa nije uspjelo.');
    }
    final raw = data['norms'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => WorkforcePerformanceNorm.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList(growable: false);
  }

  Future<({WorkforcePerformanceNorm norm, List<WorkforcePerformanceNorm> versions})>
  getNorm({
    required String companyId,
    required String normId,
    bool includeVersionHistory = true,
  }) async {
    final res = await _functions
        .httpsCallable('getWorkforcePerformanceNorm')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'normId': normId.trim(),
          'includeVersionHistory': includeVersionHistory,
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Učitavanje normativa nije uspjelo.');
    }
    final rawNorm = data['norm'];
    if (rawNorm is! Map) {
      throw Exception('Nepotpun odgovor servera (norm).');
    }
    final versions = <WorkforcePerformanceNorm>[];
    final rawVersions = data['versions'];
    if (rawVersions is List) {
      for (final item in rawVersions) {
        if (item is Map) {
          versions.add(
            WorkforcePerformanceNorm.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return (
      norm: WorkforcePerformanceNorm.fromMap(Map<String, dynamic>.from(rawNorm)),
      versions: versions,
    );
  }

  Future<WorkforcePerformanceNormMutationResult> createDraft({
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _functions
        .httpsCallable('createWorkforcePerformanceNorm')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          ...payload,
        });
    return _parseMutation(res.data);
  }

  Future<WorkforcePerformanceNormMutationResult> updateNorm({
    required String companyId,
    required String normId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _functions
        .httpsCallable('updateWorkforcePerformanceNorm')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'normId': normId.trim(),
          ...payload,
        });
    return _parseMutation(res.data);
  }

  Future<WorkforcePerformanceNormMutationResult> activateNorm({
    required String companyId,
    required String normId,
    required String validFrom,
    required String changeReason,
    String? validTo,
  }) async {
    return updateNorm(
      companyId: companyId,
      normId: normId,
      payload: {
        'status': 'active',
        'validFrom': validFrom,
        if ((validTo ?? '').trim().isNotEmpty) 'validTo': validTo,
        'changeReason': changeReason,
      },
    );
  }

  Future<WorkforcePerformanceNormMutationResult> archiveNorm({
    required String companyId,
    required String normId,
    required String reason,
  }) async {
    final res = await _functions
        .httpsCallable('archiveWorkforcePerformanceNorm')
        .call<Map<String, dynamic>>({
          'companyId': companyId.trim(),
          'normId': normId.trim(),
          'reason': reason.trim(),
        });
    return _parseMutation(res.data);
  }

  Future<WorkforcePerformanceNormMatchResult> matchNorm({
    required String companyId,
    required String plantKey,
    String? processProfileType,
    String? stationConfigId,
    String? operationType,
    String? productId,
    String? productCode,
    String? pieceType,
    String? asOfDate,
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
    };
    void put(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) payload[key] = v;
    }

    put('processProfileType', processProfileType);
    put('stationConfigId', stationConfigId);
    put('operationType', operationType);
    put('productId', productId);
    put('productCode', productCode);
    put('pieceType', pieceType);
    put('asOfDate', asOfDate);

    final res = await _functions
        .httpsCallable('matchWorkforcePerformanceNorm')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Match normativa nije uspio.');
    }
    return WorkforcePerformanceNormMatchResult.fromMap(data);
  }

  WorkforcePerformanceNormMutationResult _parseMutation(
    Map<String, dynamic> data,
  ) {
    if (data['success'] != true) {
      throw Exception('Mutacija normativa nije uspjela.');
    }
    final rawNorm = data['norm'];
    if (rawNorm is! Map) {
      throw Exception('Nepotpun odgovor servera (norm).');
    }
    return WorkforcePerformanceNormMutationResult(
      norm: WorkforcePerformanceNorm.fromMap(Map<String, dynamic>.from(rawNorm)),
      auditLogId: (data['auditLogId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['auditLogId'] ?? '').toString().trim(),
    );
  }
}
