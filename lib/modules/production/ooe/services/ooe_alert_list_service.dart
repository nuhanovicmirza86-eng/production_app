import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ooe_alert.dart';

class OoeAlertListService {
  OoeAlertListService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('ooe_alerts');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Otvoreni + nedavno zatvoreni (limit).
  Stream<List<OoeAlert>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 50,
  }) {
    final c = _s(companyId);
    final p = _s(plantKey);
    if (c.isEmpty || p.isEmpty) {
      return const Stream.empty();
    }
    return _col
        .where('companyId', isEqualTo: c)
        .where('plantKey', isEqualTo: p)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(OoeAlert.fromDoc).toList());
  }
}
