import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mes_tpm_six_losses.dart';
import '../models/ooe_loss_reason.dart';
import 'ooe_mes_callable_service.dart';

/// Katalog razloga gubitaka — master podaci; upis preko Callables (`upsertOoeLossReason`).
class OoeLossReasonService {
  final FirebaseFirestore _firestore;
  final OoeMesCallableService _cf = OoeMesCallableService();

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

  /// Efektivni TPM klaster za šifru razloga (denormalizacija u `machine_state_events`).
  Future<String?> resolveEffectiveTpmKeyForReasonCode({
    required String companyId,
    required String plantKey,
    required String reasonCode,
  }) async {
    final c = _s(reasonCode);
    if (c.isEmpty) return null;
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final id = await findIdByCode(
      companyId: companyId,
      plantKey: plantKey,
      code: c,
    );
    if (id == null) return null;
    final r = await getReason(
      reasonId: id,
      companyId: companyId,
      plantKey: plantKey,
    );
    return r?.effectiveTpmLossKey;
  }

  /// Kreira novi red u katalogu. [code] mora biti jedinstven u okviru company+plant.
  Future<String> createReason({
    required String companyId,
    required String plantKey,
    required String code,
    required String name,
    String? description,
    required String category,
    String? tpmLossKey,
    required bool isPlanned,
    required bool affectsAvailability,
    required bool affectsPerformance,
    required bool affectsQuality,
    int? sortOrder,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final codeNorm = _s(code);
    final nameNorm = _s(name);
    if (codeNorm.isEmpty) throw Exception('Šifra razloga (code) je obavezna.');
    if (nameNorm.isEmpty) throw Exception('Naziv razloga je obavezan.');

    return _cf.upsertOoeLossReasonCreate(
      companyId: companyId,
      plantKey: plantKey,
      code: codeNorm.toUpperCase(),
      name: nameNorm,
      description: description,
      category: _s(category).isEmpty ? OoeLossReason.categoryOther : _s(category),
      tpmLossKey: _nullableTpm(tpmLossKey),
      isPlanned: isPlanned,
      affectsAvailability: affectsAvailability,
      affectsPerformance: affectsPerformance,
      affectsQuality: affectsQuality,
      sortOrder: sortOrder ?? 0,
    );
  }

  Future<void> updateReason({
    required String reasonId,
    required String companyId,
    required String plantKey,
    required String name,
    required String description,
    required String category,
    required String tpmLossKey,
    required bool isPlanned,
    required bool affectsAvailability,
    required bool affectsPerformance,
    required bool affectsQuality,
    required bool active,
    required int sortOrder,
  }) async {
    _assertTenant(companyId: companyId, plantKey: plantKey);
    final n = _s(name);
    if (n.isEmpty) {
      throw Exception('Naziv ne može biti prazan.');
    }
    await _cf.upsertOoeLossReasonUpdate(
      reasonId: reasonId,
      companyId: companyId,
      plantKey: plantKey,
      name: n,
      description: description,
      category: _s(category).isEmpty ? OoeLossReason.categoryOther : _s(category),
      tpmLossKey: tpmLossKey,
      isPlanned: isPlanned,
      affectsAvailability: affectsAvailability,
      affectsPerformance: affectsPerformance,
      affectsQuality: affectsQuality,
      active: active,
      sortOrder: sortOrder,
    );
  }

  String? _nullableTpm(String? v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
