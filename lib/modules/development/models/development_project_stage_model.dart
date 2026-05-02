import 'package:cloud_firestore/cloud_firestore.dart';

/// Gate faza u `development_projects/{projectId}/stages/{G0..G9}`.
class DevelopmentProjectStageModel {
  const DevelopmentProjectStageModel({
    required this.id,
    required this.projectId,
    required this.companyId,
    required this.plantKey,
    required this.gateCode,
    required this.stageKey,
    required this.title,
    required this.status,
    required this.sortOrder,
    this.notes,
    this.plannedEndDate,
    this.actualEndDate,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;
  final String projectId;
  final String companyId;
  final String plantKey;
  final String gateCode;
  final String stageKey;
  final String title;
  final String status;
  final int sortOrder;
  final String? notes;
  final DateTime? plannedEndDate;
  final DateTime? actualEndDate;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _tsOpt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory DevelopmentProjectStageModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final so = data['sortOrder'];
    return DevelopmentProjectStageModel(
      id: doc.id,
      projectId: _s(data['projectId']),
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      gateCode: _s(data['gateCode']).isEmpty ? doc.id : _s(data['gateCode']),
      stageKey: _s(data['stageKey']),
      title: _s(data['title']),
      status: _s(data['status']).isEmpty ? 'pending' : _s(data['status']),
      sortOrder: () {
        if (so is int) return so;
        if (so is num) return so.toInt();
        return int.tryParse(_s(so)) ?? 0;
      }(),
      notes: _s(data['notes']).isEmpty ? null : _s(data['notes']),
      plannedEndDate: _tsOpt(data['plannedEndDate']),
      actualEndDate: _tsOpt(data['actualEndDate']),
      createdAt: _ts(data['createdAt']),
      createdBy: _s(data['createdBy']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }
}
