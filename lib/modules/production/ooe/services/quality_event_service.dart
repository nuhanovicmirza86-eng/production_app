import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quality_event.dart';

/// Škart / rework / hold — posebno od count događaja radi analize kvaliteta.
class QualityEventService {
  final FirebaseFirestore _firestore;

  QualityEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('quality_events');

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _assertTenant({
    required String companyId,
    required String plantKey,
  }) {
    if (_s(companyId).isEmpty || _s(plantKey).isEmpty) {
      throw Exception('companyId i plantKey su obavezni.');
    }
  }

  Future<List<QualityEvent>> listEventsForMachineWindow({
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

    final list = <QualityEvent>[];
    for (final d in q.docs) {
      final e = QualityEvent.fromDoc(d);
      if (!e.timestamp.isAfter(toInclusive) &&
          !e.timestamp.isBefore(fromInclusive)) {
        list.add(e);
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  Stream<List<QualityEvent>> watchEventsForOrder({
    required String companyId,
    required String plantKey,
    required String orderId,
    int limit = 200,
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
        .map((s) => s.docs.map(QualityEvent.fromDoc).toList());
  }

  Future<String> appendEvent({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime timestamp,
    required String eventType,
    required String source,
    double qty = 1,
    String? lineId,
    String? orderId,
    String? productId,
    String? shiftId,
    String? defectCode,
    String? defectName,
    String? severity,
    String? notes,
    String? createdBy,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    if (_s(machineId).isEmpty) throw Exception('machineId je obavezan.');

    final now = DateTime.now();
    final docRef = _col.doc();
    final event = QualityEvent(
      id: docRef.id,
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      machineId: _s(machineId),
      lineId: _nullable(lineId),
      orderId: _nullable(orderId),
      productId: _nullable(productId),
      shiftId: _nullable(shiftId),
      timestamp: timestamp,
      eventType: _s(eventType).isEmpty ? QualityEvent.typeScrap : _s(eventType),
      defectCode: _nullable(defectCode),
      defectName: _nullable(defectName),
      qty: qty,
      severity: _nullable(severity),
      notes: _nullable(notes),
      createdBy: _nullable(createdBy),
      createdAt: now,
    );

    await docRef.set({
      ...event.toMap(),
      'source': _s(source).isEmpty ? 'manual' : _s(source),
    });
    return docRef.id;
  }

  String? _nullable(String? v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
