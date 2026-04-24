import 'package:cloud_firestore/cloud_firestore.dart';

/// F4 — operativni sloj (planiranje); bez zdravstvenih detalja u napomeni.
class WorkforceLeaveOperational {
  const WorkforceLeaveOperational({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.employeeDocId,
    required this.dateKeyStart,
    required this.dateKeyEnd,
    required this.operationalAvailability,
    required this.leaveCategoryOperational,
    this.notesShort,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String employeeDocId;
  final String dateKeyStart;
  final String dateKeyEnd;
  final String operationalAvailability;
  final String leaveCategoryOperational;
  final String? notesShort;
  final DateTime? createdAt;

  factory WorkforceLeaveOperational.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    return WorkforceLeaveOperational(
      id: doc.id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      employeeDocId: (m['employeeDocId'] ?? '').toString(),
      dateKeyStart: (m['dateKeyStart'] ?? '').toString(),
      dateKeyEnd: (m['dateKeyEnd'] ?? '').toString(),
      operationalAvailability:
          (m['operationalAvailability'] ?? '').toString(),
      leaveCategoryOperational:
          (m['leaveCategoryOperational'] ?? '').toString(),
      notesShort: m['notesShort']?.toString(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
