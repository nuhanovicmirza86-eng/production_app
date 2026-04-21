import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/teep_summary.dart';

/// Čitanje agregata [teep_summaries] (OEE + OOE + TEEP u istom dokumentu).
class TeepSummaryService {
  TeepSummaryService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('teep_summaries');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Zadnji sažeci za pogon (svi opsezi: plant, line, machine × day, week, month).
  Stream<List<TeepSummary>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 48,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('periodDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(TeepSummary.fromDoc).toList());
  }
}
