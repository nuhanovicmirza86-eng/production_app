/// Interni audit — modeli iz Callable JSON-a.
class InternalAuditListRow {
  final String id;
  final String auditCode;
  final String auditType;
  final String title;
  final String auditorName;
  final String auditDate;
  final String department;
  final String status;
  final String? plantKey;
  final String? updatedAt;

  const InternalAuditListRow({
    required this.id,
    required this.auditCode,
    required this.auditType,
    required this.title,
    required this.auditorName,
    required this.auditDate,
    required this.department,
    required this.status,
    this.plantKey,
    this.updatedAt,
  });

  factory InternalAuditListRow.fromMap(Map<String, dynamic> m) {
    return InternalAuditListRow(
      id: (m['id'] ?? '').toString(),
      auditCode: (m['auditCode'] ?? '').toString(),
      auditType: (m['auditType'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      auditorName: (m['auditorName'] ?? '').toString(),
      auditDate: (m['auditDate'] ?? '').toString(),
      department: (m['department'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      plantKey: m['plantKey']?.toString(),
      updatedAt: m['updatedAt']?.toString(),
    );
  }
}

class InternalAuditHeader {
  final String id;
  final String companyId;
  final String? plantKey;
  final String auditCode;
  final String auditType;
  final String title;
  final String auditorName;
  final String auditDate;
  final String department;
  final String status;
  final String notes;
  final String? createdAt;
  final String? updatedAt;

  const InternalAuditHeader({
    required this.id,
    required this.companyId,
    this.plantKey,
    required this.auditCode,
    required this.auditType,
    required this.title,
    required this.auditorName,
    required this.auditDate,
    required this.department,
    required this.status,
    required this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory InternalAuditHeader.fromMap(Map<String, dynamic> m) {
    return InternalAuditHeader(
      id: (m['id'] ?? '').toString(),
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: m['plantKey']?.toString(),
      auditCode: (m['auditCode'] ?? '').toString(),
      auditType: (m['auditType'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      auditorName: (m['auditorName'] ?? '').toString(),
      auditDate: (m['auditDate'] ?? '').toString(),
      department: (m['department'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      notes: (m['notes'] ?? '').toString(),
      createdAt: m['createdAt']?.toString(),
      updatedAt: m['updatedAt']?.toString(),
    );
  }
}

class InternalAuditFinding {
  final String id;
  final String findingCode;
  final String findingType;
  final String description;
  final String status;
  final String? linkedCapaId;
  final String? createdAt;

  const InternalAuditFinding({
    required this.id,
    required this.findingCode,
    required this.findingType,
    required this.description,
    required this.status,
    this.linkedCapaId,
    this.createdAt,
  });

  factory InternalAuditFinding.fromMap(Map<String, dynamic> m) {
    return InternalAuditFinding(
      id: (m['id'] ?? '').toString(),
      findingCode: (m['findingCode'] ?? '').toString(),
      findingType: (m['findingType'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      linkedCapaId: m['linkedCapaId']?.toString(),
      createdAt: m['createdAt']?.toString(),
    );
  }
}

class InternalAuditBundle {
  final InternalAuditHeader audit;
  final List<InternalAuditFinding> findings;

  const InternalAuditBundle({required this.audit, required this.findings});
}
