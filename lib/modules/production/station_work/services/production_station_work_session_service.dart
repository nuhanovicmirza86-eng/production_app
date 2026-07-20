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

  Stream<List<ProductionStationWorkSession>> watchClosedSessionsForStation({
    required String companyId,
    required int stationSlot,
    int limit = 50,
  }) {
    final cid = companyId.trim();
    if (cid.isEmpty || stationSlot < 1) {
      return Stream.value(const []);
    }
    return _col
        .where('companyId', isEqualTo: cid)
        .where('stationSlot', isEqualTo: stationSlot)
        .where('status', isEqualTo: ProductionStationWorkSession.statusClosed)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final sessions = snap.docs
              .map(ProductionStationWorkSession.fromDoc)
              .toList(growable: false);
          sessions.sort((a, b) {
            final aTs = a.endedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTs = b.endedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTs.compareTo(aTs);
          });
          return sessions;
        });
  }
}
