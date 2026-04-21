import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_plant_device_event.dart';
import '../models/production_shift_day_summary.dart';

/// Čitanje `production_shift_day_summaries` i `production_plant_device_events`.
class ProductionTrackingHubFirestoreService {
  ProductionTrackingHubFirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _shiftCol =>
      _db.collection('production_shift_day_summaries');

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _db.collection('production_plant_device_events');

  /// Jedan dokument za dan (0 ili 1).
  Stream<ProductionShiftDaySummary?> watchShiftDaySummary({
    required String companyId,
    required String plantKey,
    required String workDate,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final wd = workDate.trim();
    if (cid.isEmpty || pk.isEmpty || wd.isEmpty) {
      return const Stream.empty();
    }
    return _shiftCol
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .where('workDate', isEqualTo: wd)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return ProductionShiftDaySummary.fromDoc(snap.docs.first);
        });
  }

  /// Zadnjih [limit] događaja (otvoreni i riješeni).
  Stream<List<ProductionPlantDeviceEvent>> watchRecentDeviceEvents({
    required String companyId,
    required String plantKey,
    int limit = 40,
  }) {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      return const Stream.empty();
    }
    final lim = limit.clamp(1, 100);
    return _eventsCol
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('occurredAt', descending: true)
        .limit(lim)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ProductionPlantDeviceEvent.fromDoc)
              .whereType<ProductionPlantDeviceEvent>()
              .toList(),
        );
  }
}
