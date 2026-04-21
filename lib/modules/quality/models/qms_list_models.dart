/// Redovi za QMS liste (Callable → JSON).
class QmsControlPlanRow {
  final String id;
  final String? controlPlanCode;
  final String title;
  final String productId;
  final String status;
  final String? plantKey;
  final String? approvedAtIso;
  final String? approvedByUid;
  final String? obsoleteAtIso;
  final String? obsoleteByUid;
  final String? updatedAtIso;

  const QmsControlPlanRow({
    required this.id,
    this.controlPlanCode,
    required this.title,
    required this.productId,
    required this.status,
    this.plantKey,
    this.approvedAtIso,
    this.approvedByUid,
    this.obsoleteAtIso,
    this.obsoleteByUid,
    this.updatedAtIso,
  });

  factory QmsControlPlanRow.fromMap(Map<String, dynamic> m) {
    return QmsControlPlanRow(
      id: (m['id'] ?? '').toString(),
      controlPlanCode: m['controlPlanCode']?.toString(),
      title: (m['title'] ?? '').toString(),
      productId: (m['productId'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      plantKey: m['plantKey']?.toString(),
      approvedAtIso: m['approvedAt']?.toString(),
      approvedByUid: m['approvedByUid']?.toString(),
      obsoleteAtIso: m['obsoleteAt']?.toString(),
      obsoleteByUid: m['obsoleteByUid']?.toString(),
      updatedAtIso: m['updatedAt']?.toString(),
    );
  }
}

class QmsInspectionPlanRow {
  final String id;
  final String? inspectionPlanCode;
  final String inspectionType;
  final String productId;
  final String controlPlanId;
  final String status;
  final String? plantKey;
  final String? approvedAtIso;
  final String? approvedByUid;
  final String? obsoleteAtIso;
  final String? obsoleteByUid;
  final String? updatedAtIso;

  const QmsInspectionPlanRow({
    required this.id,
    this.inspectionPlanCode,
    required this.inspectionType,
    required this.productId,
    required this.controlPlanId,
    required this.status,
    this.plantKey,
    this.approvedAtIso,
    this.approvedByUid,
    this.obsoleteAtIso,
    this.obsoleteByUid,
    this.updatedAtIso,
  });

  factory QmsInspectionPlanRow.fromMap(Map<String, dynamic> m) {
    return QmsInspectionPlanRow(
      id: (m['id'] ?? '').toString(),
      inspectionPlanCode: m['inspectionPlanCode']?.toString(),
      inspectionType: (m['inspectionType'] ?? '').toString(),
      productId: (m['productId'] ?? '').toString(),
      controlPlanId: (m['controlPlanId'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      plantKey: m['plantKey']?.toString(),
      approvedAtIso: m['approvedAt']?.toString(),
      approvedByUid: m['approvedByUid']?.toString(),
      obsoleteAtIso: m['obsoleteAt']?.toString(),
      obsoleteByUid: m['obsoleteByUid']?.toString(),
      updatedAtIso: m['updatedAt']?.toString(),
    );
  }
}

/// Jedan red QMS dokumentacije ([listQmsDocuments]).
class QmsDocumentRow {
  final String id;
  final String? documentCode;
  final String title;
  final String documentKind;
  final String productId;
  final String? productNameSnapshot;
  final String? productCodeSnapshot;
  final String status;
  final String? plantKey;
  final String? notes;
  final String? fileName;
  final String? fileStoragePath;
  final String? externalUrl;
  final String? approvedAtIso;
  final String? approvedByUid;
  final String? obsoleteAtIso;
  final String? obsoleteByUid;
  final String? updatedAtIso;

  const QmsDocumentRow({
    required this.id,
    this.documentCode,
    required this.title,
    required this.documentKind,
    required this.productId,
    this.productNameSnapshot,
    this.productCodeSnapshot,
    required this.status,
    this.plantKey,
    this.notes,
    this.fileName,
    this.fileStoragePath,
    this.externalUrl,
    this.approvedAtIso,
    this.approvedByUid,
    this.obsoleteAtIso,
    this.obsoleteByUid,
    this.updatedAtIso,
  });

  factory QmsDocumentRow.fromMap(Map<String, dynamic> m) {
    return QmsDocumentRow(
      id: (m['id'] ?? '').toString(),
      documentCode: m['documentCode']?.toString(),
      title: (m['title'] ?? '').toString(),
      documentKind: (m['documentKind'] ?? '').toString(),
      productId: (m['productId'] ?? '').toString(),
      productNameSnapshot: m['productNameSnapshot']?.toString(),
      productCodeSnapshot: m['productCodeSnapshot']?.toString(),
      status: (m['status'] ?? '').toString(),
      plantKey: m['plantKey']?.toString(),
      notes: m['notes']?.toString(),
      fileName: m['fileName']?.toString(),
      fileStoragePath: m['fileStoragePath']?.toString(),
      externalUrl: m['externalUrl']?.toString(),
      approvedAtIso: m['approvedAt']?.toString(),
      approvedByUid: m['approvedByUid']?.toString(),
      obsoleteAtIso: m['obsoleteAt']?.toString(),
      obsoleteByUid: m['obsoleteByUid']?.toString(),
      updatedAtIso: m['updatedAt']?.toString(),
    );
  }
}

/// Jedan red povijesti kontrola ([listQmsInspectionResults]).
class QmsInspectionResultRow {
  final String id;
  final String inspectionPlanId;
  final String inspectionType;
  final String productId;
  final String overallResult;
  final String? lotId;
  final String? productionOrderId;
  final String? inspectedAtIso;

  const QmsInspectionResultRow({
    required this.id,
    required this.inspectionPlanId,
    required this.inspectionType,
    required this.productId,
    required this.overallResult,
    this.lotId,
    this.productionOrderId,
    this.inspectedAtIso,
  });

  factory QmsInspectionResultRow.fromMap(Map<String, dynamic> m) {
    return QmsInspectionResultRow(
      id: (m['id'] ?? '').toString(),
      inspectionPlanId: (m['inspectionPlanId'] ?? '').toString(),
      inspectionType: (m['inspectionType'] ?? '').toString(),
      productId: (m['productId'] ?? '').toString(),
      overallResult: (m['overallResult'] ?? '').toString(),
      lotId: m['lotId']?.toString(),
      productionOrderId: m['productionOrderId']?.toString(),
      inspectedAtIso: m['inspectedAt']?.toString(),
    );
  }
}

class QmsNcrRow {
  final String id;
  final String ncrCode;
  final String source;
  final String status;
  final String severity;
  final String description;
  final String? lotId;
  final String? productionOrderId;
  final String? partnerKind;
  final String? partnerDisplayName;
  final String? externalClaimRef;
  final String? createdAtIso;

  const QmsNcrRow({
    required this.id,
    required this.ncrCode,
    required this.source,
    required this.status,
    required this.severity,
    required this.description,
    this.lotId,
    this.productionOrderId,
    this.partnerKind,
    this.partnerDisplayName,
    this.externalClaimRef,
    this.createdAtIso,
  });

  factory QmsNcrRow.fromMap(Map<String, dynamic> m) {
    return QmsNcrRow(
      id: (m['id'] ?? '').toString(),
      ncrCode: (m['ncrCode'] ?? '').toString(),
      source: (m['source'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      severity: (m['severity'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      lotId: m['lotId']?.toString(),
      productionOrderId: m['productionOrderId']?.toString(),
      partnerKind: m['partnerKind']?.toString(),
      partnerDisplayName: m['partnerDisplayName']?.toString(),
      externalClaimRef: m['externalClaimRef']?.toString(),
      createdAtIso: m['createdAt']?.toString(),
    );
  }
}

class QmsCapaRow {
  final String id;
  final String sourceRefId;
  final String title;
  final String status;
  final String? dueDateIso;
  final String? responsibleUserId;
  final String? rootCause;
  final String? updatedAtIso;

  const QmsCapaRow({
    required this.id,
    required this.sourceRefId,
    required this.title,
    required this.status,
    this.dueDateIso,
    this.responsibleUserId,
    this.rootCause,
    this.updatedAtIso,
  });

  factory QmsCapaRow.fromMap(Map<String, dynamic> m) {
    return QmsCapaRow(
      id: (m['id'] ?? '').toString(),
      sourceRefId: (m['sourceRefId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      dueDateIso: m['dueDate']?.toString(),
      responsibleUserId: m['responsibleUserId']?.toString(),
      rootCause: m['rootCause']?.toString(),
      updatedAtIso: m['updatedAt']?.toString(),
    );
  }
}

/// Sažetak reda PFMEA (lista Callable).
class QmsPfmeaRow {
  final String id;
  final String productId;
  final String controlPlanId;
  final String? plantKey;
  final String processStep;
  final String failureMode;
  final int severity;
  final int occurrence;
  final int detection;
  final int rpn;
  final String ap;
  final String rowStatus;
  final int sortOrder;
  final String? updatedAtIso;

  const QmsPfmeaRow({
    required this.id,
    required this.productId,
    required this.controlPlanId,
    this.plantKey,
    required this.processStep,
    required this.failureMode,
    required this.severity,
    required this.occurrence,
    required this.detection,
    required this.rpn,
    required this.ap,
    required this.rowStatus,
    required this.sortOrder,
    this.updatedAtIso,
  });

  factory QmsPfmeaRow.fromMap(Map<String, dynamic> m) {
    int gi(String k) {
      final v = m[k];
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return QmsPfmeaRow(
      id: (m['id'] ?? '').toString(),
      productId: (m['productId'] ?? '').toString(),
      controlPlanId: (m['controlPlanId'] ?? '').toString(),
      plantKey: m['plantKey']?.toString(),
      processStep: (m['processStep'] ?? '').toString(),
      failureMode: (m['failureMode'] ?? '').toString(),
      severity: gi('severity'),
      occurrence: gi('occurrence'),
      detection: gi('detection'),
      rpn: gi('rpn'),
      ap: (m['ap'] ?? 'U').toString(),
      rowStatus: (m['rowStatus'] ?? 'draft').toString(),
      sortOrder: gi('sortOrder'),
      updatedAtIso: m['updatedAt']?.toString(),
    );
  }
}

/// Jedna stranica liste [listQmsDocuments] (paginacija `pageToken`).
class QmsDocumentsPage {
  final List<QmsDocumentRow> items;
  final String? nextPageToken;

  const QmsDocumentsPage({
    required this.items,
    this.nextPageToken,
  });
}

/// Odgovor [getQmsDocumentSignedUploadUrl] — HTTP PUT na [uploadUrl].
class QmsSignedUploadInfo {
  final String uploadUrl;
  final String storagePath;
  final String contentType;

  const QmsSignedUploadInfo({
    required this.uploadUrl,
    required this.storagePath,
    required this.contentType,
  });
}

/// Odgovor [getQmsDocumentSignedDownloadUrl].
class QmsSignedDownloadInfo {
  final String downloadUrl;
  final String? fileName;

  const QmsSignedDownloadInfo({
    required this.downloadUrl,
    this.fileName,
  });
}
