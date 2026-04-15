import 'package:cloud_functions/cloud_functions.dart';

/// Unified Assessment Engine — šabloni + automatski izračun (Callable).
///
/// Isti backend kao `maintenance_app` (`upsertAssessmentTemplate`, `computeAssessment`).
class AssessmentEngineService {
  AssessmentEngineService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> upsertAssessmentTemplate({
    required String companyId,
    String? templateId,
    required Map<String, dynamic> payload,
  }) async {
    final body = <String, dynamic>{
      'companyId': companyId.trim(),
      'payload': payload,
    };
    final tid = templateId?.trim();
    if (tid != null && tid.isNotEmpty) {
      body['templateId'] = tid;
    }

    final res = await _functions
        .httpsCallable('upsertAssessmentTemplate')
        .call<Map<String, dynamic>>(body);
    if (res.data['success'] != true) {
      throw Exception('Snimanje šablona nije uspjelo.');
    }
    final out = res.data['templateId']?.toString().trim() ?? '';
    if (out.isEmpty) throw Exception('Callable: prazan templateId.');
    return out;
  }

  Future<AssessmentComputeResult> computeAssessment({
    required String companyId,
    String plantKey = '',
    required String templateId,
    required String entityType,
    required String entityId,
    Map<String, dynamic> inputs = const {},
    List<Map<String, dynamic>> pfmeaLines = const [],
    String? assessmentId,
    String status = 'draft',
    String? runGroupId,
    String? templateFamily,
  }) async {
    final body = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'templateId': templateId.trim(),
      'entityType': entityType.trim(),
      'entityId': entityId.trim(),
      'inputs': inputs,
      'pfmeaLines': pfmeaLines,
      'status': status.trim(),
      if (runGroupId != null && runGroupId.trim().isNotEmpty)
        'runGroupId': runGroupId.trim(),
      if (templateFamily != null && templateFamily.trim().isNotEmpty)
        'templateFamily': templateFamily.trim(),
    };
    final aid = assessmentId?.trim();
    if (aid != null && aid.isNotEmpty) {
      body['assessmentId'] = aid;
    }

    final res = await _functions
        .httpsCallable('computeAssessment')
        .call<Map<String, dynamic>>(body);
    if (res.data['success'] != true) {
      throw Exception('Izračun procjene nije uspio.');
    }

    return AssessmentComputeResult(
      assessmentId: res.data['assessmentId']?.toString().trim() ?? '',
      resultId: res.data['resultId']?.toString().trim() ?? '',
      totalScore: (res.data['totalScore'] is num)
          ? (res.data['totalScore'] as num).toDouble()
          : double.tryParse('${res.data['totalScore']}') ?? 0,
      riskLevel: res.data['riskLevel']?.toString().trim() ?? '',
      maxRpn: res.data['maxRpn'] is num
          ? (res.data['maxRpn'] as num).toInt()
          : int.tryParse('${res.data['maxRpn']}'),
      legacyAssetRiskSynced: res.data['legacyAssetRiskSynced'] == true,
    );
  }
}

class AssessmentComputeResult {
  final String assessmentId;
  final String resultId;
  final double totalScore;
  final String riskLevel;
  final int? maxRpn;

  /// Kad je `entityType == asset` i PFMEA, backend može sinkronizovati `assets.risk`.
  final bool legacyAssetRiskSynced;

  const AssessmentComputeResult({
    required this.assessmentId,
    required this.resultId,
    required this.totalScore,
    required this.riskLevel,
    this.maxRpn,
    this.legacyAssetRiskSynced = false,
  });
}
