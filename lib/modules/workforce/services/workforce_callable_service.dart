import 'package:cloud_functions/cloud_functions.dart';

/// Cloud Functions region mora odgovarati backendu (`europe-west1`).
class WorkforceCallableService {
  WorkforceCallableService({
    FirebaseFunctions? functions,
  }) : _fn = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  Future<Map<String, dynamic>> upsertEmployee({
    required String companyId,
    required String plantKey,
    String? employeeDocId,
    /// Kada nije prazno, backend postavlja pogon zapisu (samo company admin / super admin na drugi pogon).
    String targetPlantKey = '',
    required String displayName,
    String employmentStatus = 'active',
    String jobTitle = '',
    String reportsToEmployeeDocId = '',
    String hireDate = '',
    String shiftGroup = '',
    bool active = true,
    String internalContactEmail = '',
    String internalContactPhone = '',
    String linkedUserUid = '',
    String photoUrl = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertEmployee');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      if (employeeDocId != null && employeeDocId.isNotEmpty)
        'employeeDocId': employeeDocId,
      if (targetPlantKey.trim().isNotEmpty) 'targetPlantKey': targetPlantKey.trim(),
      'displayName': displayName,
      'employmentStatus': employmentStatus,
      'jobTitle': jobTitle,
      'reportsToEmployeeDocId': reportsToEmployeeDocId,
      'hireDate': hireDate,
      'shiftGroup': shiftGroup,
      'active': active,
      'internalContactEmail': internalContactEmail,
      'internalContactPhone': internalContactPhone,
      'linkedUserUid': linkedUserUid,
      'photoUrl': photoUrl,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertQualification({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    String? qualificationDocId,
    required String dimensionType,
    required String dimensionId,
    int level = 0,
    String status = 'not_qualified',
    String? validUntilIso,
    String? verifiedAtIso,
    String verifierUid = '',
    String notesShort = '',
    String approvalStatus = 'approved',
    String approvalNote = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertQualification');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      if (qualificationDocId != null && qualificationDocId.isNotEmpty)
        'qualificationDocId': qualificationDocId,
      'dimensionType': dimensionType,
      'dimensionId': dimensionId,
      'level': level,
      'status': status,
      if (validUntilIso != null && validUntilIso.isNotEmpty)
        'validUntil': validUntilIso,
      if (verifiedAtIso != null && verifiedAtIso.isNotEmpty)
        'verifiedAt': verifiedAtIso,
      'verifierUid': verifierUid,
      'notesShort': notesShort,
      'approvalStatus': approvalStatus,
      'approvalNote': approvalNote,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> resolveQualificationApproval({
    required String companyId,
    required String plantKey,
    required String qualificationDocId,
    required String resolution,
    String note = '',
  }) async {
    final c = _fn.httpsCallable('workforceResolveQualificationApproval');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'qualificationDocId': qualificationDocId,
      'resolution': resolution,
      'note': note,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertShiftAssignment({
    required String companyId,
    required String plantKey,
    required String dateKey,
    required String shiftCode,
    required String employeeDocId,
    String? assignmentDocId,
    String placementType = 'plant',
    String placementId = '',
    String roleTag = '',
    bool skipQualificationCheck = false,
  }) async {
    final c = _fn.httpsCallable('workforceUpsertShiftAssignment');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'dateKey': dateKey,
      'shiftCode': shiftCode,
      'employeeDocId': employeeDocId,
      if (assignmentDocId != null && assignmentDocId.isNotEmpty)
        'assignmentDocId': assignmentDocId,
      'placementType': placementType,
      'placementId': placementId,
      'roleTag': roleTag,
      if (skipQualificationCheck) 'skipQualificationCheck': true,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertAttendanceEntry({
    required String companyId,
    required String plantKey,
    required String dateKey,
    required String shiftCode,
    required String employeeDocId,
    String? entryDocId,
    String operationalStatus = 'unknown',
    String noteShort = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertAttendanceEntry');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'dateKey': dateKey,
      'shiftCode': shiftCode,
      'employeeDocId': employeeDocId,
      if (entryDocId != null && entryDocId.isNotEmpty) 'entryDocId': entryDocId,
      'operationalStatus': operationalStatus,
      'noteShort': noteShort,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertTrainingRecord({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    String? trainingDocId,
    required String title,
    String trainingType = 'other',
    String status = 'planned',
    String trainerName = '',
    String scheduledAtIso = '',
    String completedAtIso = '',
    String testScore = '',
    bool practicalPassed = false,
    String notesShort = '',
    String linkedDimensionType = '',
    String linkedDimensionId = '',
    String linkedQualificationDocId = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertTrainingRecord');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      if (trainingDocId != null && trainingDocId.isNotEmpty)
        'trainingDocId': trainingDocId,
      'title': title,
      'trainingType': trainingType,
      'status': status,
      'trainerName': trainerName,
      if (scheduledAtIso.isNotEmpty) 'scheduledAt': scheduledAtIso,
      if (completedAtIso.isNotEmpty) 'completedAt': completedAtIso,
      'testScore': testScore,
      'practicalPassed': practicalPassed,
      'notesShort': notesShort,
      'linkedDimensionType': linkedDimensionType,
      'linkedDimensionId': linkedDimensionId,
      'linkedQualificationDocId': linkedQualificationDocId,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertPerformanceFeedback({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    String? feedbackDocId,
    required String category,
    required String noteTitle,
    String noteBody = '',
    String kpiPeriodKey = '',
    int? structuredScore,
    String relatedTrackingEntryId = '',
    String relatedMachineStateEventId = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertPerformanceFeedback');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      if (feedbackDocId != null && feedbackDocId.isNotEmpty)
        'feedbackDocId': feedbackDocId,
      'category': category,
      'noteTitle': noteTitle,
      'noteBody': noteBody,
      if (kpiPeriodKey.isNotEmpty) 'kpiPeriodKey': kpiPeriodKey,
      'structuredScore': ?structuredScore,
      if (relatedTrackingEntryId.isNotEmpty)
        'relatedTrackingEntryId': relatedTrackingEntryId,
      if (relatedMachineStateEventId.isNotEmpty)
        'relatedMachineStateEventId': relatedMachineStateEventId,
    };
    final r = await c.call(payload);
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  /// F3 — evidencija ocjena (kućni red, sigurnost 1–3; uspjeh, efikasnost 1–5).
  Future<Map<String, dynamic>> upsertEvaluationRecord({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    required String periodKeyYyyyMm,
    String? evaluationDocId,
    required int houseRulesScore,
    required int safetyComplianceScore,
    required int workEffectivenessScore,
    required int workEfficiencyScore,
    String notesShort = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertEvaluationRecord');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      'periodKey': periodKeyYyyyMm,
      if (evaluationDocId != null && evaluationDocId.isNotEmpty)
        'evaluationDocId': evaluationDocId,
      'houseRulesScore': houseRulesScore,
      'safetyComplianceScore': safetyComplianceScore,
      'workEffectivenessScore': workEffectivenessScore,
      'workEfficiencyScore': workEfficiencyScore,
      if (notesShort.isNotEmpty) 'notesShort': notesShort,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertComplianceDocument({
    required String companyId,
    required String plantKey,
    String? complianceDocId,
    String employeeDocId = '',
    required String docType,
    required String title,
    required String version,
    required String effectiveFrom,
    String validUntil = '',
    String status = 'active',
    String attachmentUrl = '',
    String notesShort = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertComplianceDocument');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      if (complianceDocId != null && complianceDocId.isNotEmpty)
        'complianceDocId': complianceDocId,
      if (employeeDocId.isNotEmpty) 'employeeDocId': employeeDocId,
      'docType': docType,
      'title': title,
      'version': version,
      'effectiveFrom': effectiveFrom,
      if (validUntil.isNotEmpty) 'validUntil': validUntil,
      'status': status,
      'attachmentUrl': attachmentUrl,
      'notesShort': notesShort,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  /// F5 — agregirane preporuke (Callable, read-only).
  Future<Map<String, dynamic>> getPlanningRecommendations({
    required String companyId,
    required String plantKey,
    int horizonDays = 14,
  }) async {
    final c = _fn.httpsCallable('workforceGetPlanningRecommendations');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'horizonDays': horizonDays,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> upsertLeaveOperationalStatus({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    String? leaveDocId,
    required String dateKeyStart,
    required String dateKeyEnd,
    String operationalAvailability = 'unavailable',
    String leaveCategoryOperational = 'undisclosed',
    String notesShort = '',
  }) async {
    final c = _fn.httpsCallable('workforceUpsertLeaveOperationalStatus');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      if (leaveDocId != null && leaveDocId.isNotEmpty) 'leaveDocId': leaveDocId,
      'dateKeyStart': dateKeyStart,
      'dateKeyEnd': dateKeyEnd,
      'operationalAvailability': operationalAvailability,
      'leaveCategoryOperational': leaveCategoryOperational,
      'notesShort': notesShort,
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }
}
