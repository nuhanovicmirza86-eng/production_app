import 'package:cloud_firestore/cloud_firestore.dart';

class WorkforcePerformanceFeedback {
  const WorkforcePerformanceFeedback({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.employeeDocId,
    required this.category,
    required this.noteTitle,
    required this.noteBody,
    this.kpiPeriodKey,
    this.structuredScore,
    this.relatedTrackingEntryId,
    this.relatedMachineStateEventId,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String employeeDocId;
  /// coaching | recognition | improvement_needed
  final String category;
  final String noteTitle;
  final String noteBody;
  final String? kpiPeriodKey;
  final int? structuredScore;
  final String? relatedTrackingEntryId;
  final String? relatedMachineStateEventId;
  final DateTime? createdAt;

  factory WorkforcePerformanceFeedback.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    final sc = m['structuredScore'];
    return WorkforcePerformanceFeedback(
      id: doc.id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      employeeDocId: (m['employeeDocId'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      noteTitle: (m['noteTitle'] ?? '').toString(),
      noteBody: (m['noteBody'] ?? '').toString(),
      kpiPeriodKey: m['kpiPeriodKey']?.toString(),
      structuredScore: sc is num ? sc.toInt() : int.tryParse('$sc'),
      relatedTrackingEntryId: m['relatedTrackingEntryId']?.toString(),
      relatedMachineStateEventId: m['relatedMachineStateEventId']?.toString(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
