import 'package:cloud_firestore/cloud_firestore.dart';

/// Vanjski dobavljač na projektu (`development_projects/{id}/suppliers/{supplierId}`).
class DevelopmentProjectSupplierModel {
  const DevelopmentProjectSupplierModel({
    required this.id,
    required this.projectId,
    required this.companyId,
    required this.plantKey,
    required this.displayName,
    required this.category,
    required this.approvalStatus,
    required this.externalRiskLevel,
    this.scopeSummary,
    this.iatfControlNote,
    this.evaluationNote,
    required this.assignedTaskIds,
    required this.assignedPartLabels,
    this.qualityRating,
    this.deliveryRating,
    this.priceRating,
    this.dueDate,
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
  final String displayName;
  final String category;
  final String approvalStatus;
  final String externalRiskLevel;
  final String? scopeSummary;
  final String? iatfControlNote;
  final String? evaluationNote;
  final List<String> assignedTaskIds;
  final List<String> assignedPartLabels;
  final int? qualityRating;
  final int? deliveryRating;
  final int? priceRating;
  final DateTime? dueDate;
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

  static List<String> _strList(dynamic v) {
    if (v is! List) return const [];
    return v.map((x) => _s(x)).where((e) => e.isNotEmpty).toList();
  }

  static int? _rating(dynamic v) {
    if (v == null) return null;
    final n = v is num ? v.toInt() : int.tryParse(v.toString());
    if (n == null) return null;
    if (n < 1 || n > 5) return null;
    return n;
  }

  factory DevelopmentProjectSupplierModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final dd = data['dueDate'];
    return DevelopmentProjectSupplierModel(
      id: doc.id,
      projectId: _s(data['projectId']),
      companyId: _s(data['companyId']),
      plantKey: _s(data['plantKey']),
      displayName: _s(data['displayName']),
      category: _s(data['category']).isEmpty ? 'other' : _s(data['category']),
      approvalStatus:
          _s(data['approvalStatus']).isEmpty ? 'draft' : _s(data['approvalStatus']),
      externalRiskLevel:
          _s(data['externalRiskLevel']).isEmpty ? 'medium' : _s(data['externalRiskLevel']),
      scopeSummary: _s(data['scopeSummary']).isEmpty ? null : _s(data['scopeSummary']),
      iatfControlNote:
          _s(data['iatfControlNote']).isEmpty ? null : _s(data['iatfControlNote']),
      evaluationNote:
          _s(data['evaluationNote']).isEmpty ? null : _s(data['evaluationNote']),
      assignedTaskIds: _strList(data['assignedTaskIds']),
      assignedPartLabels: _strList(data['assignedPartLabels']),
      qualityRating: _rating(data['qualityRating']),
      deliveryRating: _rating(data['deliveryRating']),
      priceRating: _rating(data['priceRating']),
      dueDate: dd is Timestamp ? dd.toDate() : null,
      createdAt: _ts(data['createdAt']),
      createdBy: _s(data['createdBy']),
      createdByName: _s(data['createdByName']),
      updatedAt: _ts(data['updatedAt']),
      updatedBy: _s(data['updatedBy']),
    );
  }
}
