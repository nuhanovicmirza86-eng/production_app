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
    );
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
    });
    final d = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    return SubmitInspectionResult(
      inspectionResultId: d['inspectionResultId']?.toString() ?? '',
      overallResult: d['overallResult']?.toString() ?? '',
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

  Future<List<QmsNcrRow>> listNonConformances({
    required String companyId,
    int limit = 100,
    bool openOnly = true,
    /// `customer` | `supplier` | `internal` | `operations` ili prazno = sve.
    String? sourceFilter,
  }) async {
    final callable = _functions.httpsCallable('listQmsNonConformances');
    final res = await callable.call({
      'companyId': companyId,
      'limit': limit,
      'openOnly': openOnly,
      if (sourceFilter != null && sourceFilter.trim().isNotEmpty)
        'sourceFilter': sourceFilter.trim(),
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
    String? description,
    String? severity,
    List<Map<String, String>>? attachments,
  }) async {
    final callable = _functions.httpsCallable('updateQmsNonConformance');
    final res = await callable.call({
      'companyId': companyId,
      'ncrId': ncrId,
      if (status != null) 'status': status,
      if (containmentAction != null) 'containmentAction': containmentAction,
      if (description != null) 'description': description,
      if (severity != null) 'severity': severity,
      if (attachments != null) 'attachments': attachments,
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

  const QmsDashboardSummary({
    required this.controlPlanCount,
    required this.inspectionPlanCount,
    required this.openNcrCount,
    required this.openCapaCount,
  });
}

class SubmitInspectionResult {
  final String inspectionResultId;
  final String overallResult;

  const SubmitInspectionResult({
    required this.inspectionResultId,
    required this.overallResult,
  });
}
