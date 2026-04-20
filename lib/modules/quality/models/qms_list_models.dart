/// Redovi za QMS liste (Callable → JSON).
class QmsControlPlanRow {
  final String id;
  final String? controlPlanCode;
  final String title;
  final String productId;
  final String status;
  final String? plantKey;
  final String? updatedAtIso;

  const QmsControlPlanRow({
    required this.id,
    this.controlPlanCode,
    required this.title,
    required this.productId,
    required this.status,
    this.plantKey,
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
  final String? updatedAtIso;

  const QmsInspectionPlanRow({
    required this.id,
    this.inspectionPlanCode,
    required this.inspectionType,
    required this.productId,
    required this.controlPlanId,
    required this.status,
    this.plantKey,
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
      updatedAtIso: m['updatedAt']?.toString(),
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
