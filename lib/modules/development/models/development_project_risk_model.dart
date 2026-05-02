import 'package:cloud_firestore/cloud_firestore.dart';

/// Rizik u `development_projects/{projectId}/risks/{riskId}`.
class DevelopmentProjectRiskModel {
  const DevelopmentProjectRiskModel({
    required this.id,
    required this.projectId,
    required this.companyId,
    required this.plantKey,
    required this.title,
    this.description,
    required this.severity,
    required this.status,
    this.category,
    required this.blocksRelease,
    this.mitigationNote,
    required this.sortOrder,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String projectId;
  final String companyId;
  final String plantKey;
  final String title;
  final String? description;
  final String severity;
  final String status;
  final String? category;
  final bool blocksRelease;
  final String? mitigationNote;
  final int sortOrder;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime updatedAt;
  final String updatedBy;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory DevelopmentProjectRiskModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final so = data['sortOrder'];
    final br = data['blocksRelease'];
    return DevelopmentProjectRiskModel(
      id: doc.id,
      projectId: _s(data['projectId']),
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      title: _s(data['title']),
      description: _s(data['description']).isEmpty ? null : _s(data['description']),
      severity: _s(data['severity']).isEmpty ? 'medium' : _s(data['severity']),
      status: _s(data['status']).isEmpty ? 'open' : _s(data['status']),
      category: _s(data['category']).isEmpty ? null : _s(data['category']),
      blocksRelease: br == true,
      mitigationNote:
          _s(data['mitigationNote']).isEmpty ? null : _s(data['mitigationNote']),
      sortOrder: () {
        if (so is int) return so;
        if (so is num) return so.toInt();
        return int.tryParse(_s(so)) ?? 0;
      }(),
      createdAt: _ts(data['createdAt']),
      createdBy: _s(data['createdBy']),
      createdByName: _s(data['createdByName']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }
}
