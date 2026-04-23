import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/machine_state_event.dart';
import 'ooe_loss_reason_service.dart';

/// Upis i čitanje `machine_state_events` — promjene stanja mašine / linije.
class MachineStateService {
  final FirebaseFirestore _firestore;
  final OoeLossReasonService _ooeLossReasons;

  MachineStateService({
    FirebaseFirestore? firestore,
    OoeLossReasonService? ooeLossReasonService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _ooeLossReasons = ooeLossReasonService ??
            OoeLossReasonService(
              firestore: firestore ?? FirebaseFirestore.instance,
            );

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

  static const Set<String> _allowedStates = {
    MachineStateEvent.stateRunning,
    MachineStateEvent.stateStopped,
    MachineStateEvent.stateSetup,
    MachineStateEvent.stateWaitingMaterial,
    MachineStateEvent.stateWaitingOperator,
    MachineStateEvent.stateMaintenance,
    MachineStateEvent.stateQualityHold,
    MachineStateEvent.statePlannedBreak,
    MachineStateEvent.stateIdle,
  };

  void _validateState(String state) {
    if (!_allowedStates.contains(state)) {
      throw Exception('Nepoznato machine state: $state');
    }
  }

  Future<void> _assertDocTenant({
    required DocumentReference<Map<String, dynamic>> ref,
    required String companyId,
    required String plantKey,
  }) async {
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Machine state događaj ne postoji.');
    }
    final data = snap.data();
    if (data == null) throw Exception('Događaj nema podataka.');
    if (_s(data['companyId']) != companyId || _s(data['plantKey']) != plantKey) {
      throw Exception('Nemaš pristup ovom događaju.');
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

  /// Otvara novi segment stanja (npr. nakon start execution ili PLC signala).
  Future<String> openState({
    required String companyId,
    required String plantKey,
    required String machineId,
    required String state,
    required DateTime startedAt,
    required String source,
    String? lineId,
    String? workCenterId,
    String? orderId,
    String? productId,
    String? shiftId,
    DateTime? shiftDate,
    String? reasonCode,
    String? reasonCategory,
    String? tpmLossKey,
    String? createdBy,
    String? notes,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final st = _s(state);
    _validateState(st);
    if (_s(machineId).isEmpty) throw Exception('machineId je obavezan.');

    var resolvedTpm = _nullable(tpmLossKey);
    if (resolvedTpm == null) {
      final rc = _nullable(reasonCode);
      if (rc != null) {
        try {
          resolvedTpm = await _ooeLossReasons.resolveEffectiveTpmKeyForReasonCode(
            companyId: _s(companyId),
            plantKey: _s(plantKey),
            reasonCode: rc,
          );
        } catch (_) {
          resolvedTpm = null;
        }
      }
    }

    final now = DateTime.now();
    final docRef = _col.doc();
    final event = MachineStateEvent(
      id: docRef.id,
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      machineId: _s(machineId),
      lineId: _nullable(lineId),
      workCenterId: _nullable(workCenterId),
      orderId: _nullable(orderId),
      productId: _nullable(productId),
      shiftId: _nullable(shiftId),
      shiftDate: shiftDate,
      state: st,
      reasonCode: _nullable(reasonCode),
      reasonCategory: _nullable(reasonCategory),
      tpmLossKey: _nullable(resolvedTpm),
      startedAt: startedAt,
      endedAt: null,
      durationSeconds: null,
      source: _s(source).isEmpty ? 'manual' : _s(source),
      createdBy: _nullable(createdBy),
      createdAt: now,
      notes: _nullable(notes),
    );

    await docRef.set(event.toMap());
    return docRef.id;
  }

  /// Zatvara segment (postavlja [endedAt] i [durationSeconds] u sekundama).
  /// Posljednji otvoreni segment (bez [endedAt]) za mašinu — za integraciju execution / SCADA.
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

  Future<void> closeState({
    required String eventId,
    required String companyId,
    required String plantKey,
    required DateTime endedAt,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final ref = _col.doc(eventId);
    await _assertDocTenant(ref: ref, companyId: companyId, plantKey: plantKey);

    final snap = await ref.get();
    final ev = MachineStateEvent.fromDoc(snap);
    if (ev.endedAt != null) {
      throw Exception('Događaj je već zatvoren.');
    }
    if (endedAt.isBefore(ev.startedAt)) {
      throw Exception('endedAt mora biti nakon ili jednak startedAt.');
    }

    final durationSeconds = endedAt.difference(ev.startedAt).inSeconds;

    await ref.update({
      'endedAt': endedAt,
      'durationSeconds': durationSeconds,
    });
  }

  String? _nullable(String? v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
