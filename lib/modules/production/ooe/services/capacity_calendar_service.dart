import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/capacity_calendar.dart';

/// Čitanje [capacity_calendars] — definicija kalendarskog kapaciteta ( Callable / admin upis ).
class CapacityCalendarService {
  CapacityCalendarService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('capacity_calendars');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Zadnji zapisi za pogon (plant, line, machine — svi opsezi).
  Stream<List<CapacityCalendar>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 42,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);

    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(CapacityCalendar.fromDoc).toList());
  }
}
