import 'package:cloud_firestore/cloud_firestore.dart';

class WorkforceQualification {
  const WorkforceQualification({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.employeeDocId,
    required this.dimensionType,
    required this.dimensionId,
    required this.level,
    required this.status,
    this.validUntil,
    this.verifiedAt,
    this.verifierUid,
    this.notesShort,
    this.approvalStatus,
    this.approvalNote,
    this.approverUid,
    this.approvalResolvedAt,
    this.approvalRequestedAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String employeeDocId;
  final String dimensionType;
  final String dimensionId;
  final int level;
  final String status;
  final DateTime? validUntil;
  final DateTime? verifiedAt;
  final String? verifierUid;
  final String? notesShort;
  /// F2: `approved` | `pending_approval` | `rejected` (prazno tretiraj kao approved).
  final String? approvalStatus;
  final String? approvalNote;
  final String? approverUid;
  final DateTime? approvalResolvedAt;
  final DateTime? approvalRequestedAt;

  factory WorkforceQualification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    return WorkforceQualification(
      id: doc.id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      employeeDocId: (m['employeeDocId'] ?? '').toString(),
      dimensionType: (m['dimensionType'] ?? '').toString(),
      dimensionId: (m['dimensionId'] ?? '').toString(),
      level: (m['level'] as num?)?.toInt() ?? 0,
      status: (m['status'] ?? '').toString(),
      validUntil: (m['validUntil'] as Timestamp?)?.toDate(),
      verifiedAt: (m['verifiedAt'] as Timestamp?)?.toDate(),
      verifierUid: m['verifierUid']?.toString(),
      notesShort: m['notesShort']?.toString(),
      approvalStatus: m['approvalStatus']?.toString(),
      approvalNote: m['approvalNote']?.toString(),
      approverUid: m['approverUid']?.toString(),
      approvalResolvedAt: (m['approvalResolvedAt'] as Timestamp?)?.toDate(),
      approvalRequestedAt: (m['approvalRequestedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get effectiveApproval =>
      (approvalStatus == null || approvalStatus!.isEmpty)
          ? 'approved'
          : approvalStatus!;

  bool get isExpired {
    final v = validUntil;
    if (v == null) return false;
    return v.isBefore(DateTime.now());
  }
}
