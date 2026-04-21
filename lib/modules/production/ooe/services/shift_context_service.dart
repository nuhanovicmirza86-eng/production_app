import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shift_context.dart';
import 'ooe_path_ids.dart';

/// Konfiguracija smjene po danu (`shift_contexts`) — osnova za stabilan availability u OOE.
///
/// Kolekcija: root `shift_contexts`, dokument ID = [OoePathIds.shiftContextDocId].
class ShiftContextService {
  ShiftContextService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('shift_contexts');

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _assertTenant({required String companyId, required String plantKey}) {
    if (_s(companyId).isEmpty || _s(plantKey).isEmpty) {
      throw Exception('companyId i plantKey su obavezni.');
    }
  }

  /// Jedna smjena na dan (npr. DAY + 2026-04-22). Neaktivni zapisi vraćaju `null`.
  Future<ShiftContext?> getContext({
    required String companyId,
    required String plantKey,
    required DateTime shiftDateLocal,
    required String shiftCode,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final dk = ShiftContext.shiftDateKeyFromLocal(shiftDateLocal);
    final id = OoePathIds.shiftContextDocId(
      companyId: companyId,
      plantKey: plantKey,
      shiftDateKey: dk,
      shiftCode: shiftCode,
    );
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    final ctx = ShiftContext.fromDoc(snap);
    if (ctx.companyId != _s(companyId) || ctx.plantKey != _s(plantKey)) {
      return null;
    }
    if (!ctx.active) return null;
    return ctx;
  }

  /// Zadnji unosi za pogon (administracija / provjera konfiguracije).
  Stream<List<ShiftContext>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 60,
  }) {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final cid = _s(companyId);
    final pk = _s(plantKey);
    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .orderBy('shiftDateKey', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ShiftContext.fromDoc).toList());
  }

  /// Spremi kontekst smjene (merge: ažurira polja, čuva `createdAt` ako već postoji).
  Future<void> upsertContext({
    required String companyId,
    required String plantKey,
    required DateTime shiftDateLocal,
    required String shiftCode,
    required int operatingTimeSeconds,
    int plannedBreakSeconds = 0,
    DateTime? plannedStartAt,
    DateTime? plannedEndAt,
    bool isWorkingShift = true,
    bool active = true,
    String? notes,
    String? createdBy,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final code = _s(shiftCode);
    if (code.isEmpty) {
      throw Exception('shiftCode je obavezan.');
    }
    if (operatingTimeSeconds <= 0) {
      throw Exception('operatingTimeSeconds mora biti > 0.');
    }
    if (plannedBreakSeconds < 0) {
      throw Exception('plannedBreakSeconds ne smije biti negativan.');
    }
    if (plannedStartAt != null &&
        plannedEndAt != null &&
        !plannedEndAt.isAfter(plannedStartAt)) {
      throw Exception('plannedEndAt mora biti nakon plannedStartAt.');
    }

    final dk = ShiftContext.shiftDateKeyFromLocal(shiftDateLocal);
    final id = OoePathIds.shiftContextDocId(
      companyId: companyId,
      plantKey: plantKey,
      shiftDateKey: dk,
      shiftCode: code,
    );
    final ref = _col.doc(id);
    final existing = await ref.get();
    final cid = _s(companyId);
    final pk = _s(plantKey);

    final payload = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'shiftCode': code,
      'shiftDateKey': dk,
      'shiftId': id,
      'operatingTimeSeconds': operatingTimeSeconds,
      'plannedBreakSeconds': plannedBreakSeconds,
      'isWorkingShift': isWorkingShift,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (plannedStartAt != null) {
      payload['plannedStartAt'] = Timestamp.fromDate(plannedStartAt);
    } else {
      payload['plannedStartAt'] = FieldValue.delete();
    }
    if (plannedEndAt != null) {
      payload['plannedEndAt'] = Timestamp.fromDate(plannedEndAt);
    } else {
      payload['plannedEndAt'] = FieldValue.delete();
    }

    if (notes != null && _s(notes).isNotEmpty) {
      payload['notes'] = _s(notes);
    } else {
      payload['notes'] = FieldValue.delete();
    }

    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      if (createdBy != null && _s(createdBy).isNotEmpty) {
        payload['createdBy'] = _s(createdBy);
      }
    } else {
      final prev = existing.data();
      if (prev != null && prev['createdAt'] != null) {
        payload['createdAt'] = prev['createdAt'];
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      final prevBy = prev?['createdBy'];
      if (prevBy != null && _s(prevBy).isNotEmpty) {
        payload['createdBy'] = prevBy;
      } else if (createdBy != null && _s(createdBy).isNotEmpty) {
        payload['createdBy'] = _s(createdBy);
      }
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  /// Trajno ukloni kontekst smjene (istu putanju kao [upsertContext]).
  Future<void> deleteContext({
    required String companyId,
    required String plantKey,
    required DateTime shiftDateLocal,
    required String shiftCode,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final code = _s(shiftCode);
    if (code.isEmpty) {
      throw Exception('shiftCode je obavezan.');
    }
    final dk = ShiftContext.shiftDateKeyFromLocal(shiftDateLocal);
    final id = OoePathIds.shiftContextDocId(
      companyId: companyId,
      plantKey: plantKey,
      shiftDateKey: dk,
      shiftCode: code,
    );
    final snap = await _col.doc(id).get();
    if (!snap.exists) return;
    final ctx = ShiftContext.fromDoc(snap);
    final cid = _s(companyId);
    final pk = _s(plantKey);
    if (ctx.companyId != cid || ctx.plantKey != pk) {
      throw Exception('Zapis ne pripada ovom pogonskom kontekstu.');
    }
    await _col.doc(id).delete();
  }
}
