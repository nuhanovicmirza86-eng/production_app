import 'package:cloud_functions/cloud_functions.dart';

import '../models/qms_execution_models.dart';
import '../models/qms_list_models.dart';

/// QMS Callable-i — mutacije i liste (Firestore rules: klijent read/write false na QMS kolekcijama).
class QualityCallableService {
  QualityCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<QmsDashboardSummary> getQmsDashboardSummary({
    required String companyId,
  }) async {
    final callable = _functions.httpsCallable('getQmsDashboardSummary');
    final res = await callable.call({'companyId': companyId});
    final data = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    return QmsDashboardSummary(
      controlPlanCount: _int(data['controlPlanCount']),
      inspectionPlanCount: _int(data['inspectionPlanCount']),
      openNcrCount: _int(data['openNcrCount']),
      openCapaCount: _int(data['openCapaCount']),
      overdueCapaCount: _int(data['overdueCapaCount']),
    );
  }

  /// Korak 5 QMS: jedan strani izvještaj za vodstvo (Callable [getQmsManagementReport]).
  Future<Map<String, dynamic>> getQmsManagementReport({
    required String companyId,
    int daysBack = 30,
  }) async {
    final callable = _functions.httpsCallable('getQmsManagementReport');
    final res = await callable.call({
      'companyId': companyId,
      'daysBack': daysBack,
    });
    return Map<String, dynamic>.from((res.data as Map?) ?? const <String, dynamic>{});
  }

  Future<String> upsertControlPlan({
    required String companyId,
    String? plantKey,
    String? controlPlanId,
    required String title,
    required String productId,
    String status = 'draft',
    List<dynamic>? operations,
    String? controlPlanCode,
  }) async {
    final callable = _functions.httpsCallable('upsertControlPlan');
    final res = await callable.call({
      'companyId': companyId,
      if (plantKey != null && plantKey.isNotEmpty) 'plantKey': plantKey,
      if (controlPlanId != null && controlPlanId.isNotEmpty)
        'controlPlanId': controlPlanId,
      'title': title,
      'productId': productId,
      'status': status,
      'operations': operations ?? const [],
      if (controlPlanCode != null && controlPlanCode.isNotEmpty)
        'controlPlanCode': controlPlanCode,
    });
    final id = (res.data as Map?)?['controlPlanId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('upsertControlPlan: nije vraćen controlPlanId');
    }
    return id;
  }

  Future<String> upsertInspectionPlan({
    required String companyId,
    String? plantKey,
    String? inspectionPlanId,
    required String productId,
    required String controlPlanId,
    required String inspectionType,
    List<dynamic>? characteristicRefs,
    String status = 'draft',
    String? inspectionPlanCode,
  }) async {
    final callable = _functions.httpsCallable('upsertInspectionPlan');
    final res = await callable.call({
      'companyId': companyId,
      if (plantKey != null && plantKey.isNotEmpty) 'plantKey': plantKey,
      if (inspectionPlanId != null && inspectionPlanId.isNotEmpty)
        'inspectionPlanId': inspectionPlanId,
      'productId': productId,
      'controlPlanId': controlPlanId,
      'inspectionType': inspectionType,
      'characteristicRefs': characteristicRefs ?? const [],
      'status': status,
      if (inspectionPlanCode != null && inspectionPlanCode.isNotEmpty)
        'inspectionPlanCode': inspectionPlanCode,
    });
    final id = (res.data as Map?)?['inspectionPlanId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('upsertInspectionPlan: nije vraćen inspectionPlanId');
    }
    return id;
  }

  Future<SubmitInspectionResult> submitInspectionResult({
    required String companyId,
    String? plantKey,
    required String inspectionPlanId,
    required List<Map<String, dynamic>> measurements,
    String? lotId,
    String? productionOrderId,
    String? operationId,
    String? supplierId,
    String? customerId,
    String? scanPayload,
    bool autoCreateNcr = true,
    bool autoApplyHoldToLot = true,
  }) async {
    final callable = _functions.httpsCallable('submitInspectionResult');
    final res = await callable.call({
      'companyId': companyId,
      if (plantKey != null && plantKey.isNotEmpty) 'plantKey': plantKey,
      'inspectionPlanId': inspectionPlanId,
      'measurements': measurements,
      if (lotId != null && lotId.isNotEmpty) 'lotId': lotId,
      if (productionOrderId != null && productionOrderId.isNotEmpty)
        'productionOrderId': productionOrderId,
      if (operationId != null && operationId.isNotEmpty) 'operationId': operationId,
      if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      if (scanPayload != null && scanPayload.isNotEmpty) 'scanPayload': scanPayload,
      'autoCreateNcr': autoCreateNcr,
      'autoApplyHoldToLot': autoApplyHoldToLot,
    });
    final d = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    return SubmitInspectionResult(
      inspectionResultId: d['inspectionResultId']?.toString() ?? '',
      overallResult: d['overallResult']?.toString() ?? '',
      lotHoldApplied: d['lotHoldApplied'] == true,
      lotHoldSkipReason: d['lotHoldSkipReason']?.toString(),
      inventoryLotDocId: d['inventoryLotDocId']?.toString(),
    );
  }

  /// QMS: stavlja WMS lot na hold (npr. naknadno s NCR detalja ako auto-hold nije prošao).
  Future<ApplyQmsLotHoldResult> applyQmsHoldOnInventoryLot({
    required String companyId,
    required String lotId,
    String? ncrId,
    String? inspectionResultId,
    String sourceType = 'manual',
  }) async {
    final callable = _functions.httpsCallable('applyQmsHoldOnInventoryLot');
    final res = await callable.call({
      'companyId': companyId,
      'lotId': lotId,
      if (ncrId != null && ncrId.trim().isNotEmpty) 'ncrId': ncrId.trim(),
      if (inspectionResultId != null && inspectionResultId.trim().isNotEmpty)
        'inspectionResultId': inspectionResultId.trim(),
      'sourceType': sourceType,
    });
    final d = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    return ApplyQmsLotHoldResult(
      applied: d['applied'] == true,
      lotDocId: d['lotDocId']?.toString() ?? '',
      skipReason: d['skipReason']?.toString(),
    );
  }

  Future<List<QmsControlPlanRow>> listControlPlans({
    required String companyId,
    int limit = 100,
  }) async {
    final callable = _functions.httpsCallable('listQmsControlPlans');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
    });
    return _parseRows(res.data, QmsControlPlanRow.fromMap);
  }

  Future<List<QmsInspectionPlanRow>> listInspectionPlans({
    required String companyId,
    int limit = 100,
  }) async {
    final callable = _functions.httpsCallable('listQmsInspectionPlans');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
    });
    return _parseRows(res.data, QmsInspectionPlanRow.fromMap);
  }

  /// Radni uputi, upute za pakovanje, obrasci (QMS dokumentacija).
  Future<QmsDocumentsPage> listQmsDocuments({
    required String companyId,
    int limit = 50,
    /// Filtar po `documentKind` (npr. `work_instruction`).
    String? documentKind,
    String? productId,
    /// ID zadnjeg dokumenta s prethodne stranice ([nextPageToken] s poslužitelja).
    String? pageToken,
  }) async {
    final callable = _functions.httpsCallable('listQmsDocuments');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
      if (documentKind != null && documentKind.trim().isNotEmpty)
        'documentKind': documentKind.trim(),
      if (productId != null && productId.trim().isNotEmpty)
        'productId': productId.trim(),
      if (pageToken != null && pageToken.trim().isNotEmpty)
        'pageToken': pageToken.trim(),
    });
    final root = Map<String, dynamic>.from((res.data as Map?) ?? {});
    final items = _parseRows(res.data, QmsDocumentRow.fromMap);
    final nextRaw = root['nextPageToken']?.toString().trim();
    return QmsDocumentsPage(
      items: items,
      nextPageToken: (nextRaw == null || nextRaw.isEmpty) ? null : nextRaw,
    );
  }

  /// GCS v4 signed URL za PUT (nakon [upsertQmsDocument] koji vrati id).
  Future<QmsSignedUploadInfo> getQmsDocumentSignedUploadUrl({
    required String companyId,
    required String qmsDocumentId,
    required String fileName,
    String contentType = 'application/octet-stream',
  }) async {
    final callable = _functions.httpsCallable('getQmsDocumentSignedUploadUrl');
    final res = await callable.call({
      'companyId': companyId,
      'qmsDocumentId': qmsDocumentId,
      'fileName': fileName,
      'contentType': contentType,
    });
    final root = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return QmsSignedUploadInfo(
      uploadUrl: (root['uploadUrl'] ?? '').toString(),
      storagePath: (root['storagePath'] ?? '').toString(),
      contentType: (root['contentType'] ?? contentType).toString(),
    );
  }

  /// GCS v4 signed URL za čitanje / preuzimanje datoteke.
  Future<QmsSignedDownloadInfo> getQmsDocumentSignedDownloadUrl({
    required String companyId,
    required String qmsDocumentId,
  }) async {
    final callable = _functions.httpsCallable('getQmsDocumentSignedDownloadUrl');
    final res = await callable.call({
      'companyId': companyId,
      'qmsDocumentId': qmsDocumentId,
    });
    final root = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return QmsSignedDownloadInfo(
      downloadUrl: (root['downloadUrl'] ?? '').toString(),
      fileName: root['fileName']?.toString(),
    );
  }

  Future<String> upsertQmsDocument({
    required String companyId,
    String? plantKey,
    String? qmsDocumentId,
    required String title,
    required String productId,
    required String documentKind,
    String status = 'draft',
    String? notes,
    String? fileName,
    String? fileStoragePath,
    String? externalUrl,
    String? productNameSnapshot,
    String? productCodeSnapshot,
    String? documentCode,
  }) async {
    final callable = _functions.httpsCallable('upsertQmsDocument');
    final res = await callable.call({
      'companyId': companyId,
      if (plantKey != null && plantKey.isNotEmpty) 'plantKey': plantKey,
      if (qmsDocumentId != null && qmsDocumentId.isNotEmpty)
        'qmsDocumentId': qmsDocumentId,
      'title': title,
      'productId': productId,
      'documentKind': documentKind,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (fileName != null && fileName.isNotEmpty) 'fileName': fileName,
      if (fileStoragePath != null && fileStoragePath.isNotEmpty)
        'fileStoragePath': fileStoragePath,
      if (externalUrl != null && externalUrl.isNotEmpty) 'externalUrl': externalUrl,
      if (productNameSnapshot != null && productNameSnapshot.isNotEmpty)
        'productNameSnapshot': productNameSnapshot,
      if (productCodeSnapshot != null && productCodeSnapshot.isNotEmpty)
        'productCodeSnapshot': productCodeSnapshot,
      if (documentCode != null && documentCode.isNotEmpty)
        'documentCode': documentCode,
    });
    final id = (res.data as Map?)?['qmsDocumentId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('upsertQmsDocument: nije vraćen qmsDocumentId');
    }
    return id;
  }

  /// Brisanje reda u `qms_documents` (+ Storage datoteka ako postoji putanja).
  Future<void> deleteQmsDocument({
    required String companyId,
    required String qmsDocumentId,
  }) async {
    final callable = _functions.httpsCallable('deleteQmsDocument');
    await callable.call({
      'companyId': companyId,
      'qmsDocumentId': qmsDocumentId,
    });
  }

  /// Zadnji rezultati kontrola (OK/NOK, lot, plan, datum).
  Future<List<QmsInspectionResultRow>> listInspectionResults({
    required String companyId,
    int limit = 80,
  }) async {
    final callable = _functions.httpsCallable('listQmsInspectionResults');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
    });
    return _parseRows(res.data, QmsInspectionResultRow.fromMap);
  }

  Future<List<QmsNcrRow>> listNonConformances({
    required String companyId,
    int limit = 100,
    bool openOnly = true,
    /// `customer` | `supplier` | `internal` | `operations` ili prazno = sve.
    String? sourceFilter,
    /// Filtar NCR zapisa za jedan proizvod (`products` id).
    String? productId,
  }) async {
    final callable = _functions.httpsCallable('listQmsNonConformances');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
      'openOnly': openOnly,
      if (sourceFilter != null && sourceFilter.trim().isNotEmpty)
        'sourceFilter': sourceFilter.trim(),
      if (productId != null && productId.trim().isNotEmpty)
        'productId': productId.trim(),
    });
    return _parseRows(res.data, QmsNcrRow.fromMap);
  }

  /// Reklamacija kupca (CUSTOMER) ili prigovor prema dobavljaču (SUPPLIER).
  Future<String> createQmsPartnerClaimNcr({
    required String companyId,
    required String claimSource,
    required String partnerKind,
    required String partnerId,
    required String description,
    String? plantKey,
    String? containmentAction,
    String? externalClaimRef,
    String? severity,
  }) async {
    final callable = _functions.httpsCallable('createQmsPartnerClaimNcr');
    final res = await callable.call({
      'companyId': companyId,
      'claimSource': claimSource,
      'partnerKind': partnerKind,
      'partnerId': partnerId,
      'description': description,
      if (plantKey != null && plantKey.isNotEmpty) 'plantKey': plantKey,
      if (containmentAction != null) 'containmentAction': containmentAction,
      if (externalClaimRef != null && externalClaimRef.isNotEmpty)
        'externalClaimRef': externalClaimRef,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
    });
    final id = (res.data as Map?)?['ncrId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('createQmsPartnerClaimNcr: nije vraćen ncrId');
    }
    return id;
  }

  Future<List<QmsCapaRow>> listOpenCapa({required String companyId}) async {
    final callable = _functions.httpsCallable('listQmsOpenCapa');
    final res = await callable.call({
      'companyId': companyId,
    });
    return _parseRows(res.data, QmsCapaRow.fromMap);
  }

  Future<Map<String, dynamic>> getQmsControlPlanMap({
    required String companyId,
    required String controlPlanId,
  }) async {
    final callable = _functions.httpsCallable('getQmsControlPlan');
    final res = await callable.call({
      'companyId': companyId,
      'controlPlanId': controlPlanId,
    });
    final m = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return Map<String, dynamic>.from(m['controlPlan'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> getQmsInspectionPlanMap({
    required String companyId,
    required String inspectionPlanId,
  }) async {
    final callable = _functions.httpsCallable('getQmsInspectionPlan');
    final res = await callable.call({
      'companyId': companyId,
      'inspectionPlanId': inspectionPlanId,
    });
    final m = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return Map<String, dynamic>.from(m['inspectionPlan'] as Map? ?? {});
  }

  Future<QmsInspectionExecutionContext> getInspectionExecutionContext({
    required String companyId,
    required String inspectionPlanId,
  }) async {
    final callable = _functions.httpsCallable('getQmsInspectionExecutionContext');
    final res = await callable.call({
      'companyId': companyId,
      'inspectionPlanId': inspectionPlanId,
    });
    final m = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return QmsInspectionExecutionContext.fromMap(m);
  }

  Future<Map<String, dynamic>> getQmsNonConformanceMap({
    required String companyId,
    required String ncrId,
  }) async {
    final callable = _functions.httpsCallable('getQmsNonConformance');
    final res = await callable.call({
      'companyId': companyId,
      'ncrId': ncrId,
    });
    final m = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return Map<String, dynamic>.from(m['ncr'] as Map? ?? {});
  }

  /// Vraća [capaAutoCreated], [actionPlanId] kad backend automatski otvori CAPA.
  Future<Map<String, dynamic>> updateQmsNonConformance({
    required String companyId,
    required String ncrId,
    String? status,
    String? containmentAction,
    String? reactionPlan,
    String? description,
    String? severity,
    List<Map<String, String>>? attachments,
    /// NCR niska/srednja ozbiljnost: zapis o zatvaranju (alternativa dijelu reaction plana).
    String? closureNote,
    /// HIGH/CRITICAL: CAPA lanac ili poslovno odstupanje.
    String? capaWaiverReason,
    String? sourceModule,
    List<String>? fiveWhySteps,
  }) async {
    final callable = _functions.httpsCallable('updateQmsNonConformance');
    final res = await callable.call({
      'companyId': companyId,
      'ncrId': ncrId,
      if (status != null) 'status': status,
      if (containmentAction != null) 'containmentAction': containmentAction,
      if (reactionPlan != null) 'reactionPlan': reactionPlan,
      if (description != null) 'description': description,
      if (severity != null) 'severity': severity,
      if (attachments != null) 'attachments': attachments,
      if (closureNote != null) 'closureNote': closureNote,
      if (capaWaiverReason != null) 'capaWaiverReason': capaWaiverReason,
      if (sourceModule != null) 'sourceModule': sourceModule,
      if (fiveWhySteps != null) 'fiveWhySteps': fiveWhySteps,
    });
    return Map<String, dynamic>.from((res.data as Map?) ?? const <String, dynamic>{});
  }

  Future<List<QmsCapaRow>> listCapaForNcr({
    required String companyId,
    required String ncrId,
  }) async {
    final callable = _functions.httpsCallable('listQmsCapaForNcr');
    final res = await callable.call({
      'companyId': companyId,
      'ncrId': ncrId,
    });
    return _parseRows(res.data, QmsCapaRow.fromMap);
  }

  Future<Map<String, dynamic>> getQmsCapaActionPlanMap({
    required String companyId,
    required String actionPlanId,
  }) async {
    final callable = _functions.httpsCallable('getQmsCapaActionPlan');
    final res = await callable.call({
      'companyId': companyId,
      'actionPlanId': actionPlanId,
    });
    final m = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return Map<String, dynamic>.from(m['actionPlan'] as Map? ?? {});
  }

  Future<void> updateQmsCapaActionPlan({
    required String companyId,
    required String actionPlanId,
    String? title,
    String? status,
    String? rootCause,
    String? actionText,
    String? verificationNotes,
    String? responsibleUserId,
    String? dueDateIso,
    Map<String, dynamic>? eightD,
    Map<String, dynamic>? ishikawa,
    String? actionType,
    /// Negativna verifikacija: vraća CAPA u rad i NCR u UNDER_REVIEW (samo u `waiting_verification`).
    bool? verificationFailed,
  }) async {
    final callable = _functions.httpsCallable('updateQmsCapaActionPlan');
    await callable.call({
      'companyId': companyId,
      'actionPlanId': actionPlanId,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (rootCause != null) 'rootCause': rootCause,
      if (actionText != null) 'actionText': actionText,
      if (verificationNotes != null) 'verificationNotes': verificationNotes,
      if (responsibleUserId != null) 'responsibleUserId': responsibleUserId,
      if (dueDateIso != null) 'dueDate': dueDateIso,
      if (eightD != null) 'eightD': eightD,
      if (ishikawa != null) 'ishikawa': ishikawa,
      if (actionType != null) 'actionType': actionType,
      if (verificationFailed == true) 'verificationFailed': true,
    });
  }

  Future<String> createQmsCapaForNcr({
    required String companyId,
    required String ncrId,
    required String title,
    String? actionText,
    String? responsibleUserId,
    String? dueDateIso,
  }) async {
    final callable = _functions.httpsCallable('createQmsCapaForNcr');
    final res = await callable.call({
      'companyId': companyId,
      'ncrId': ncrId,
      'title': title,
      if (actionText != null && actionText.isNotEmpty) 'actionText': actionText,
      if (responsibleUserId != null && responsibleUserId.isNotEmpty)
        'responsibleUserId': responsibleUserId,
      if (dueDateIso != null && dueDateIso.isNotEmpty) 'dueDate': dueDateIso,
    });
    final id = (res.data as Map?)?['actionPlanId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('createQmsCapaForNcr: nije vraćen actionPlanId');
    }
    return id;
  }

  Future<List<QmsPfmeaRow>> listQmsPfmeaRows({
    required String companyId,
    String? productId,
    String? controlPlanId,
    int limit = 300,
  }) async {
    final callable = _functions.httpsCallable('listQmsPfmeaRows');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (controlPlanId != null && controlPlanId.isNotEmpty)
        'controlPlanId': controlPlanId,
    });
    return _parseRows(res.data, QmsPfmeaRow.fromMap);
  }

  Future<Map<String, dynamic>> getQmsPfmeaRowMap({
    required String companyId,
    required String pfmeaRowId,
  }) async {
    final callable = _functions.httpsCallable('getQmsPfmeaRow');
    final res = await callable.call({
      'companyId': companyId,
      'pfmeaRowId': pfmeaRowId,
    });
    final m = Map<String, dynamic>.from((res.data as Map?) ?? {});
    return Map<String, dynamic>.from(m['row'] as Map? ?? {});
  }

  Future<String> upsertQmsPfmeaRow({
    required String companyId,
    String? pfmeaRowId,
    required String processStep,
    required String failureMode,
    String? plantKey,
    String? productId,
    String? controlPlanId,
    String? effects,
    int severity = 0,
    int occurrence = 0,
    int detection = 0,
    bool apManual = false,
    String apManualValue = 'M',
    String? currentControls,
    String? recommendedAction,
    String rowStatus = 'draft',
    int sortOrder = 0,
  }) async {
    final callable = _functions.httpsCallable('upsertQmsPfmeaRow');
    final res = await callable.call({
      'companyId': companyId,
      if (pfmeaRowId != null && pfmeaRowId.isNotEmpty) 'pfmeaRowId': pfmeaRowId,
      'processStep': processStep,
      'failureMode': failureMode,
      if (plantKey != null && plantKey.isNotEmpty) 'plantKey': plantKey,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (controlPlanId != null && controlPlanId.isNotEmpty)
        'controlPlanId': controlPlanId,
      if (effects != null) 'effects': effects,
      'severity': severity,
      'occurrence': occurrence,
      'detection': detection,
      'apManual': apManual,
      'apManualValue': apManualValue,
      if (currentControls != null) 'currentControls': currentControls,
      if (recommendedAction != null) 'recommendedAction': recommendedAction,
      'rowStatus': rowStatus,
      'sortOrder': sortOrder,
    });
    final id = (res.data as Map?)?['pfmeaRowId']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError('upsertQmsPfmeaRow: nije vraćen pfmeaRowId');
    }
    return id;
  }

  Future<void> deleteQmsPfmeaRow({
    required String companyId,
    required String pfmeaRowId,
  }) async {
    final callable = _functions.httpsCallable('deleteQmsPfmeaRow');
    await callable.call({
      'companyId': companyId,
      'pfmeaRowId': pfmeaRowId,
    });
  }

  static List<T> _parseRows<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final items = root['items'];
    if (items is! List) return [];
    return items
        .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class QmsDashboardSummary {
  final int controlPlanCount;
  final int inspectionPlanCount;
  final int openNcrCount;
  final int openCapaCount;
  final int overdueCapaCount;

  const QmsDashboardSummary({
    required this.controlPlanCount,
    required this.inspectionPlanCount,
    required this.openNcrCount,
    required this.openCapaCount,
    this.overdueCapaCount = 0,
  });
}

class SubmitInspectionResult {
  final String inspectionResultId;
  final String overallResult;
  final bool lotHoldApplied;
  final String? lotHoldSkipReason;
  final String? inventoryLotDocId;

  const SubmitInspectionResult({
    required this.inspectionResultId,
    required this.overallResult,
    this.lotHoldApplied = false,
    this.lotHoldSkipReason,
    this.inventoryLotDocId,
  });
}

class ApplyQmsLotHoldResult {
  final bool applied;
  final String lotDocId;
  final String? skipReason;

  const ApplyQmsLotHoldResult({
    required this.applied,
    required this.lotDocId,
    this.skipReason,
  });
}
