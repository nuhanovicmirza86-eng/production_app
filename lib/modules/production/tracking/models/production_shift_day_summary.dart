import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan dokument: dnevni sažetak smjena / radne snage za [plantKey].
class ProductionShiftDaySummary {
  const ProductionShiftDaySummary({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.workDate,
    required this.plannedHeadcount,
    required this.presentCount,
    required this.absentCount,
    required this.absentByReason,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String plantKey;

  /// YYYY-MM-DD
  final String workDate;
  final int plannedHeadcount;
  final int presentCount;
  final int absentCount;
  final Map<String, int> absentByReason;
  final String? notes;
  final DateTime? updatedAt;

  static ProductionShiftDaySummary? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    if (d == null) return null;
    final cid = (d['companyId'] ?? '').toString().trim();
    final pk = (d['plantKey'] ?? '').toString().trim();
    final wd = (d['workDate'] ?? '').toString().trim();
    if (cid.isEmpty || pk.isEmpty || wd.isEmpty) return null;

    final rawReason = d['absentByReason'];
    final Map<String, int> reasons = {};
    if (rawReason is Map) {
      for (final e in rawReason.entries) {
        final k = e.key.toString().trim();
        final v = e.value;
        final n = v is num ? v.toInt() : int.tryParse(v.toString());
        if (k.isNotEmpty && n != null && n >= 0) {
          reasons[k] = n;
        }
      }
    }

    DateTime? upd;
    final tu = d['updatedAt'];
    if (tu is Timestamp) {
      upd = tu.toDate();
    }

    return ProductionShiftDaySummary(
      id: doc.id,
      companyId: cid,
      plantKey: pk,
      workDate: wd,
      plannedHeadcount: _intField(d['plannedHeadcount']),
      presentCount: _intField(d['presentCount']),
      absentCount: _intField(d['absentCount']),
      absentByReason: reasons,
      notes: (d['notes'] ?? '').toString().trim().isEmpty
          ? null
          : (d['notes'] ?? '').toString().trim(),
      updatedAt: upd,
    );
  }

  static int _intField(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
