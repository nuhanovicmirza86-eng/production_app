import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_station_work_session.dart';

class ProductionStationWorkSessionService {
  ProductionStationWorkSessionService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('production_station_work_sessions');

  Stream<ProductionStationWorkSession?> watchActiveSession({
    required String companyId,
    required int stationSlot,
  }) {
    final cid = companyId.trim();
    if (cid.isEmpty || stationSlot < 1) {
      return Stream.value(null);
    }
    return _col
        .where('companyId', isEqualTo: cid)
        .where('stationSlot', isEqualTo: stationSlot)
        .where('status', whereIn: const [
          ProductionStationWorkSession.statusOpen,
          ProductionStationWorkSession.statusPaused,
        ])
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return ProductionStationWorkSession.fromDoc(snap.docs.first);
        });
  }

  Stream<ProductionStationWorkSession?> watchSession(String sessionId) {
    final sid = sessionId.trim();
    if (sid.isEmpty) return Stream.value(null);
    return _col.doc(sid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProductionStationWorkSession.fromDoc(doc);
    });
  }
}
