import 'package:cloud_firestore/cloud_firestore.dart';

class WorkforceTrainingRecord {
  const WorkforceTrainingRecord({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.employeeDocId,
    required this.title,
    required this.trainingType,
    required this.status,
    this.trainerName,
    this.testScore,
    this.practicalPassed,
    this.notesShort,
    this.linkedDimensionType,
    this.linkedDimensionId,
    this.linkedQualificationDocId,
    this.scheduledAt,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String employeeDocId;
  final String title;
  final String trainingType;
  final String status;
  final String? trainerName;
  final String? testScore;
  final bool? practicalPassed;
  final String? notesShort;
  final String? linkedDimensionType;
  final String? linkedDimensionId;
  final String? linkedQualificationDocId;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  factory WorkforceTrainingRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    return WorkforceTrainingRecord(
      id: doc.id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      employeeDocId: (m['employeeDocId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      trainingType: (m['trainingType'] ?? 'other').toString(),
      status: (m['status'] ?? 'planned').toString(),
      trainerName: m['trainerName']?.toString(),
      testScore: m['testScore']?.toString(),
      practicalPassed: m['practicalPassed'] as bool?,
      notesShort: m['notesShort']?.toString(),
      linkedDimensionType: m['linkedDimensionType']?.toString(),
      linkedDimensionId: m['linkedDimensionId']?.toString(),
      linkedQualificationDocId: m['linkedQualificationDocId']?.toString(),
      scheduledAt: (m['scheduledAt'] as Timestamp?)?.toDate(),
      completedAt: (m['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
