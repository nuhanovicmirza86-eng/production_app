import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/development_constants.dart';

/// Zahtjev za odobrenje u `development_projects/{projectId}/approvals/{approvalId}`.
class DevelopmentProjectApprovalModel {
  const DevelopmentProjectApprovalModel({
    required this.id,
    required this.projectId,
    required this.companyId,
    required this.plantKey,
    required this.title,
    this.description,
    required this.approvalKind,
    required this.status,
    this.linkedGate,
    this.linkedDocumentId,
    this.decisionNote,
    this.decidedAt,
    this.decidedBy,
    this.decidedByName,
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
  final String approvalKind;
  final String status;
  final String? linkedGate;
  final String? linkedDocumentId;
  final String? decisionNote;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? decidedByName;
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

  static DateTime? _tsOpt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  factory DevelopmentProjectApprovalModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final so = data['sortOrder'];
    var kind = _s(data['approvalKind']);
    if (!DevelopmentApprovalKinds.all.contains(kind)) {
      kind = DevelopmentApprovalKinds.general;
    }
    var st = _s(data['status']);
    if (!DevelopmentApprovalStatuses.all.contains(st)) {
      st = DevelopmentApprovalStatuses.pending;
    }
    return DevelopmentProjectApprovalModel(
      id: doc.id,
      projectId: _s(data['projectId']),
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      title: _s(data['title']),
      description: _s(data['description']).isEmpty ? null : _s(data['description']),
      approvalKind: kind,
      status: st,
      linkedGate: _s(data['linkedGate']).isEmpty ? null : _s(data['linkedGate']),
      linkedDocumentId:
          _s(data['linkedDocumentId']).isEmpty ? null : _s(data['linkedDocumentId']),
      decisionNote:
          _s(data['decisionNote']).isEmpty ? null : _s(data['decisionNote']),
      decidedAt: _tsOpt(data['decidedAt']),
      decidedBy: _s(data['decidedBy']).isEmpty ? null : _s(data['decidedBy']),
      decidedByName:
          _s(data['decidedByName']).isEmpty ? null : _s(data['decidedByName']),
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
