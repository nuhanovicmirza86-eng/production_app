import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/machine_state_event.dart';

/// Čitanje `machine_state_events` — segmenti stanja mašine / linije (upis: Callable).
class MachineStateService {
  MachineStateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('machine_state_events');

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _assertTenant({
    required String companyId,
    required String plantKey,
  }) {
    if (_s(companyId).isEmpty || _s(plantKey).isEmpty) {
      throw Exception('companyId i plantKey su obavezni.');
    }
  }

  /// Posljednji događaji za mašinu (za timeline / historiju).
  Stream<List<MachineStateEvent>> watchEventsForMachine({
    required String companyId,
    required String plantKey,
    required String machineId,
    int limit = 100,
  }) {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final mid = _s(machineId);
    if (mid.isEmpty) throw Exception('machineId je obavezan.');

    return _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .where('machineId', isEqualTo: mid)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MachineStateEvent.fromDoc).toList());
  }

  /// Događaji vezani uz proizvodni nalog.
  Stream<List<MachineStateEvent>> watchEventsForOrder({
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
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MachineStateEvent.fromDoc).toList());
  }

  Future<MachineStateEvent?> getEvent({
    required String eventId,
    required String companyId,
    required String plantKey,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final doc = await _col.doc(eventId).get();
    if (!doc.exists) return null;
    final e = MachineStateEvent.fromDoc(doc);
    if (e.companyId != companyId || e.plantKey != plantKey) return null;
    return e;
  }

  /// Posljednji otvoreni segment (bez [endedAt]) za mašinu — za integraciju execution / očitavanje stanja.
  Future<MachineStateEvent?> getLatestOpenEventForMachine({
    required String companyId,
    required String plantKey,
    required String machineId,
    int scanLimit = 40,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final mid = _s(machineId);
    if (mid.isEmpty) return null;

    final q = await _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .where('machineId', isEqualTo: mid)
        .orderBy('startedAt', descending: true)
        .limit(scanLimit)
        .get();

    for (final d in q.docs) {
      final e = MachineStateEvent.fromDoc(d);
      if (e.endedAt == null) return e;
    }
    return null;
  }

  /// Događaji u vremenskom prozoru (filtrirano u memoriji nakon čitanja posljednjih [limit] segmenta).
  Future<List<MachineStateEvent>> listEventsForMachineWindow({
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
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();

    final list = <MachineStateEvent>[];
    for (final d in q.docs) {
      final e = MachineStateEvent.fromDoc(d);
      if (!e.startedAt.isAfter(toInclusive) &&
          !e.startedAt.isBefore(fromInclusive)) {
        list.add(e);
      }
    }
    list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return list;
  }
}
