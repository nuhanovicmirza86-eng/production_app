import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/development_constants.dart';

/// Inženjetska izmjena / ECO u `development_projects/{projectId}/changes/{changeId}`.
class DevelopmentProjectChangeModel {
  const DevelopmentProjectChangeModel({
    required this.id,
    required this.projectId,
    required this.companyId,
    required this.plantKey,
    required this.title,
    this.description,
    required this.changeKind,
    required this.status,
    required this.blocksRelease,
    this.linkedGate,
    this.linkedDocumentId,
    this.externalRef,
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
  final String changeKind;
  final String status;
  final bool blocksRelease;
  final String? linkedGate;
  final String? linkedDocumentId;
  final String? externalRef;
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

  factory DevelopmentProjectChangeModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final so = data['sortOrder'];
    final br = data['blocksRelease'];
    var kind = _s(data['changeKind']);
    if (!DevelopmentChangeKinds.all.contains(kind)) {
      kind = DevelopmentChangeKinds.other;
    }
    var st = _s(data['status']);
    if (!DevelopmentChangeStatuses.all.contains(st)) {
      st = DevelopmentChangeStatuses.open;
    }
    return DevelopmentProjectChangeModel(
      id: doc.id,
      projectId: _s(data['projectId']),
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      title: _s(data['title']),
      description: _s(data['description']).isEmpty ? null : _s(data['description']),
      changeKind: kind,
      status: st,
      blocksRelease: br == true,
      linkedGate: _s(data['linkedGate']).isEmpty ? null : _s(data['linkedGate']),
      linkedDocumentId:
          _s(data['linkedDocumentId']).isEmpty ? null : _s(data['linkedDocumentId']),
      externalRef:
          _s(data['externalRef']).isEmpty ? null : _s(data['externalRef']),
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
