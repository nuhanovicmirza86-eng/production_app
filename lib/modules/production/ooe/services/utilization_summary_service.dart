import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/utilization_summary.dart';

/// Čitanje [utilization_summaries].
class UtilizationSummaryService {
  UtilizationSummaryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('utilization_summaries');

  String _s(dynamic v) => (v ?? '').toString().trim();

  Stream<List<UtilizationSummary>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 40,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('periodDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(UtilizationSummary.fromDoc).toList());
  }
}
