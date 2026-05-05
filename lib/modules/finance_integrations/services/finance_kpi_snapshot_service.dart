import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_kpi_snapshot_model.dart';

class FinanceKpiSnapshotService {
  FinanceKpiSnapshotService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Jedan snapshot za tenant + poslovnu godinu + mjesec + pogon (prazan plantKey = cijeli pogon filtriran u pravilima).
  Stream<FinanceKpiSnapshotModel?> watchSnapshot({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
  }) {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    if (cid.isEmpty || by.isEmpty) {
      return Stream<FinanceKpiSnapshotModel?>.value(null);
    }
    final pk = plantKey.trim();
    Query<Map<String, dynamic>> q = _db
        .collection('finance_kpi_snapshots')
        .where('companyId', isEqualTo: cid)
        .where('businessYearId', isEqualTo: by)
        .where('periodYear', isEqualTo: periodYear)
        .where('periodMonth', isEqualTo: periodMonth);
    if (pk.isNotEmpty) {
      q = q.where('plantKey', isEqualTo: pk);
    } else {
      q = q.where('plantKey', isEqualTo: '');
    }
    return q.limit(1).snapshots().map((snap) {
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return FinanceKpiSnapshotModel.fromFirestore(d.id, d.data());
    });
  }
}
