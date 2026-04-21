import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ooe_loss_reason.dart';

/// Katalog razloga gubitaka — master podaci za mapiranje **planned** i **A/P/Q** zastoja.
///
/// Kolekcija: `ooe_loss_reasons` (root), dokument s `companyId` + `plantKey` kao kod
/// ostalih production kolekcija u ovom app-u.
class OoeLossReasonService {
  final FirebaseFirestore _firestore;

  OoeLossReasonService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ooe_loss_reasons');

  String _s(dynamic v) => (v ?? '').toString().trim();

  void _assertTenant({
    required String companyId,
    required String plantKey,
  }) {
    if (_s(companyId).isEmpty || _s(plantKey).isEmpty) {
      throw Exception('companyId i plantKey su obavezni za OOE katalog.');
    }
  }

  Future<void> _assertDocTenant({
    required DocumentReference<Map<String, dynamic>> ref,
    required String companyId,
    required String plantKey,
  }) async {
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Razlog gubitka ne postoji.');
    }
    final data = snap.data();
    if (data == null) throw Exception('Razlog gubitka nema podataka.');
    if (_s(data['companyId']) != companyId || _s(data['plantKey']) != plantKey) {
      throw Exception('Nemaš pristup ovom razlogu gubitka.');
    }
  }

  /// Svi razlozi (aktivni i neaktivni) — administracija kataloga.
  Stream<List<OoeLossReason>> watchAllReasonsForPlant({
    required String companyId,
    required String plantKey,
  }) {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final cid = _s(companyId);
    final pk = _s(plantKey);
    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(OoeLossReason.fromDoc).toList();
          list.sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            if (c != 0) return c;
            return a.code.compareTo(b.code);
          });
          return list;
        });
  }

  /// Aktivni razlozi, sortirani kao u katalogu.
  Stream<List<OoeLossReason>> watchActiveReasons({
    required String companyId,
    required String plantKey,
  }) {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final cid = _s(companyId);
    final pk = _s(plantKey);
    return _col
        .where('companyId', isEqualTo: cid)
        .where('plantKey', isEqualTo: pk)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(OoeLossReason.fromDoc)
              .where((r) => r.active)
              .toList();
          list.sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            if (c != 0) return c;
            return a.code.compareTo(b.code);
          });
          return list;
        });
  }

  /// Mapiranje šifre razloga → zapis (samo aktivni).
  Future<Map<String, OoeLossReason>> loadActiveReasonByCodeMap({
    required String companyId,
    required String plantKey,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final snap = await _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .get();

    final map = <String, OoeLossReason>{};
    for (final d in snap.docs) {
      final r = OoeLossReason.fromDoc(d);
      if (!r.active) continue;
      map[r.code] = r;
    }
    return map;
  }

  Future<OoeLossReason?> getReason({
    required String reasonId,
    required String companyId,
    required String plantKey,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final doc = await _col.doc(reasonId).get();
    if (!doc.exists) return null;
    final r = OoeLossReason.fromDoc(doc);
    if (r.companyId != companyId || r.plantKey != plantKey) return null;
    return r;
  }

  Future<String?> findIdByCode({
    required String companyId,
    required String plantKey,
    required String code,
  }) async {
    final c = _s(code);
    if (c.isEmpty) return null;
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final q = await _col
        .where('companyId', isEqualTo: _s(companyId))
        .where('plantKey', isEqualTo: _s(plantKey))
        .where('code', isEqualTo: c)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  /// Kreira novi red u katalogu. [code] mora biti jedinstven u okviru company+plant.
  Future<String> createReason({
    required String companyId,
    required String plantKey,
    required String code,
    required String name,
    String? description,
    required String category,
    required bool isPlanned,
    required bool affectsAvailability,
    required bool affectsPerformance,
    required bool affectsQuality,
    int? sortOrder,
    required String createdBy,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final codeNorm = _s(code);
    final nameNorm = _s(name);
    if (codeNorm.isEmpty) throw Exception('Šifra razloga (code) je obavezna.');
    if (nameNorm.isEmpty) throw Exception('Naziv razloga je obavezan.');

    final dup = await findIdByCode(
      companyId: companyId,
      plantKey: plantKey,
      code: codeNorm,
    );
    if (dup != null) {
      throw Exception('Razlog s tom šifrom već postoji u katalogu.');
    }

    final now = DateTime.now();
    final docRef = _col.doc();
    final reason = OoeLossReason(
      id: docRef.id,
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      code: codeNorm,
      name: nameNorm,
      description: description?.trim().isEmpty ?? true ? null : description!.trim(),
      category: _s(category).isEmpty ? OoeLossReason.categoryOther : _s(category),
      isPlanned: isPlanned,
      affectsAvailability: affectsAvailability,
      affectsPerformance: affectsPerformance,
      affectsQuality: affectsQuality,
      active: true,
      sortOrder: sortOrder ?? 0,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set({
      ...reason.toMap(),
      'createdBy': _s(createdBy),
      'updatedBy': _s(createdBy),
    });

    return docRef.id;
  }

  Future<void> updateReason({
    required String reasonId,
    required String companyId,
    required String plantKey,
    String? name,
    String? description,
    String? category,
    bool? isPlanned,
    bool? affectsAvailability,
    bool? affectsPerformance,
    bool? affectsQuality,
    bool? active,
    int? sortOrder,
    required String updatedBy,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final ref = _col.doc(reasonId);
    await _assertDocTenant(ref: ref, companyId: companyId, plantKey: plantKey);

    final now = DateTime.now();
    final patch = <String, dynamic>{
      'updatedAt': now,
      'updatedBy': _s(updatedBy),
    };

    if (name != null) {
      final n = _s(name);
      if (n.isEmpty) throw Exception('Naziv ne može biti prazan.');
      patch['name'] = n;
    }
    if (description != null) {
      patch['description'] =
          description.trim().isEmpty ? FieldValue.delete() : description.trim();
    }
    if (category != null) {
      patch['category'] = _s(category).isEmpty
          ? OoeLossReason.categoryOther
          : _s(category);
    }
    if (isPlanned != null) patch['isPlanned'] = isPlanned;
    if (affectsAvailability != null) {
      patch['affectsAvailability'] = affectsAvailability;
    }
    if (affectsPerformance != null) {
      patch['affectsPerformance'] = affectsPerformance;
    }
    if (affectsQuality != null) patch['affectsQuality'] = affectsQuality;
    if (active != null) patch['active'] = active;
    if (sortOrder != null) patch['sortOrder'] = sortOrder;

    await ref.update(patch);
  }
}
