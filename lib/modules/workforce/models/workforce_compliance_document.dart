import 'package:cloud_firestore/cloud_firestore.dart';

class WorkforceComplianceDocument {
  const WorkforceComplianceDocument({
    required this.id,
    required this.companyId,
    required this.plantKey,
    this.employeeDocId,
    required this.docType,
    required this.title,
    required this.version,
    required this.effectiveFrom,
    this.validUntil,
    required this.status,
    this.attachmentUrl,
    this.notesShort,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String? employeeDocId;
  final String docType;
  final String title;
  final String version;
  final String effectiveFrom;
  final String? validUntil;
  final String status;
  final String? attachmentUrl;
  final String? notesShort;
  final DateTime? createdAt;

  factory WorkforceComplianceDocument.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    final eid = m['employeeDocId']?.toString().trim();
    return WorkforceComplianceDocument(
      id: doc.id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      employeeDocId: (eid == null || eid.isEmpty) ? null : eid,
      docType: (m['docType'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      version: (m['version'] ?? '').toString(),
      effectiveFrom: (m['effectiveFrom'] ?? '').toString(),
      validUntil: m['validUntil']?.toString(),
      status: (m['status'] ?? 'active').toString(),
      attachmentUrl: m['attachmentUrl']?.toString(),
      notesShort: m['notesShort']?.toString(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
