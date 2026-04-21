import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_count_event.dart';

/// Inkrementi količina — služe za sabiranje u summary / OOE performance kvalitetu.
class ProductionCountService {
  final FirebaseFirestore _firestore;

  ProductionCountService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('production_count_events');

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _assertTenant({
    required String companyId,
    required String plantKey,
  }) {
    if (_s(companyId).isEmpty || _s(plantKey).isEmpty) {
      throw Exception('companyId i plantKey su obavezni.');
    }
  }

  /// Tok događaja za mašinu (npr. za audit trace).
  Stream<List<ProductionCountEvent>> watchEventsForMachine({
    required String companyId,
    required String plantKey,
    required String machineId,
    int limit = 200,
  }) {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final mid = _s(machineId);
    if (mid.isEmpty) throw Exception('machineId je obavezan.');

    return _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .where('machineId', isEqualTo: mid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ProductionCountEvent.fromDoc).toList());
  }

  /// Događaji po nalogu (traceability).
  Stream<List<ProductionCountEvent>> watchEventsForOrder({
    required String companyId,
    required String plantKey,
    required String orderId,
    int limit = 500,
  }) {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final oid = _s(orderId);
    if (oid.isEmpty) throw Exception('orderId je obavezan.');

    return _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .where('orderId', isEqualTo: oid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ProductionCountEvent.fromDoc).toList());
  }

  Future<List<ProductionCountEvent>> listEventsForMachineWindow({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime fromInclusive,
    required DateTime toInclusive,
    int limit = 400,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final mid = _s(machineId);
    if (mid.isEmpty) return const [];

    final q = await _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .where('machineId', isEqualTo: mid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    final list = <ProductionCountEvent>[];
    for (final d in q.docs) {
      final e = ProductionCountEvent.fromDoc(d);
      if (!e.timestamp.isAfter(toInclusive) &&
          !e.timestamp.isBefore(fromInclusive)) {
        list.add(e);
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  Future<ProductionCountEvent?> getEvent({
    required String eventId,
    required String companyId,
    required String plantKey,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final doc = await _col.doc(eventId).get();
    if (!doc.exists) return null;
    final e = ProductionCountEvent.fromDoc(doc);
    if (e.companyId != companyId || e.plantKey != plantKey) return null;
    return e;
  }

  /// Dodaje jedan inkrement (iz ručnog unosa, execution ili kasnije SCADA).
  Future<String> appendIncrement({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime timestamp,
    required double totalCountIncrement,
    required double goodCountIncrement,
    required double scrapCountIncrement,
    required String source,
    String? lineId,
    String? orderId,
    String? productId,
    String? shiftId,
    String? createdBy,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    if (_s(machineId).isEmpty) throw Exception('machineId je obavezan.');

    final now = DateTime.now();
    final docRef = _col.doc();
    final event = ProductionCountEvent(
      id: docRef.id,
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      machineId: _s(machineId),
      lineId: _nullable(lineId),
      orderId: _nullable(orderId),
      productId: _nullable(productId),
      shiftId: _nullable(shiftId),
      timestamp: timestamp,
      totalCountIncrement: totalCountIncrement,
      goodCountIncrement: goodCountIncrement,
      scrapCountIncrement: scrapCountIncrement,
      source: _s(source).isEmpty ? 'manual' : _s(source),
      createdBy: _nullable(createdBy),
      createdAt: now,
    );

    await docRef.set(event.toMap());
    return docRef.id;
  }

  String? _nullable(String? v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
