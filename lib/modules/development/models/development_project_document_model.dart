import 'package:cloud_firestore/cloud_firestore.dart';

/// Evidencija dokumenta u `development_projects/{projectId}/documents/{documentId}`.
class DevelopmentProjectDocumentModel {
  const DevelopmentProjectDocumentModel({
    required this.id,
    required this.projectId,
    required this.companyId,
    required this.plantKey,
    required this.title,
    this.description,
    required this.docType,
    required this.status,
    this.linkedGate,
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
  final String docType;
  final String status;
  final String? linkedGate;
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

  factory DevelopmentProjectDocumentModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final so = data['sortOrder'];
    return DevelopmentProjectDocumentModel(
      id: doc.id,
      projectId: _s(data['projectId']),
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      title: _s(data['title']),
      description: _s(data['description']).isEmpty ? null : _s(data['description']),
      docType: _s(data['docType']).isEmpty ? 'other' : _s(data['docType']),
      status: _s(data['status']).isEmpty ? 'draft' : _s(data['status']),
      linkedGate: _s(data['linkedGate']).isEmpty ? null : _s(data['linkedGate']),
      externalRef: _s(data['externalRef']).isEmpty ? null : _s(data['externalRef']),
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
