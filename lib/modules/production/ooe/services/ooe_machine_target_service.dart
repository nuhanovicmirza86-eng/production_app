import 'package:cloud_firestore/cloud_firestore.dart';

import 'ooe_path_ids.dart';
import 'ooe_catalog_callable_service.dart';

class OoeMachineTargetService {
  OoeMachineTargetService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final OoeCatalogCallableService _cc = OoeCatalogCallableService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('ooe_machine_targets');

  String _s(dynamic v) => (v ?? '').toString().trim();

  /// Svi [targetOoe] po `machineId` za pogon. Jedan upit (ne N× [get]).
  ///
  /// Pojedinačni [get] na nepostojeći doc s pravilima koja koriste
  /// [resource.data.companyId] daju `permission-denied` u pravilima v2
  /// (`resource` je `null` kad dokumenta nema).
  Future<Map<String, double?>> loadTargetOoeByMachineForPlant({
    required String companyId,
    required String plantKey,
  }) async {
    final c = _s(companyId);
    final p = _s(plantKey);
    if (c.isEmpty || p.isEmpty) {
      return const {};
    }
    final snap = await _col
        .where('companyId', isEqualTo: c)
        .where('plantKey', isEqualTo: p)
        .get();
    final out = <String, double?>{};
    for (final d in snap.docs) {
      final data = d.data();
      final mid = _s(data['machineId']);
      if (mid.isEmpty) {
        continue;
      }
      out[mid] = (data['targetOoe'] as num?)?.toDouble();
    }
    return out;
  }

  Future<double?> getTargetOoe({
    required String companyId,
    required String plantKey,
    required String machineId,
  }) async {
    final id = OoePathIds.liveStatusDocId(
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      machineId: _s(machineId),
    );
    final d = await _col.doc(id).get();
    if (!d.exists) return null;
    return (d.data()?['targetOoe'] as num?)?.toDouble();
  }

  /// `targetOoe` u [0,1] ili uklanjanje cilja.
  Future<void> upsertTargetOoe({
    required String companyId,
    required String plantKey,
    required String machineId,
    required double? targetOoe,
  }) async {
    await _cc.upsertOoeMachineTarget(
      companyId: _s(companyId),
      plantKey: _s(plantKey),
      machineId: _s(machineId),
      targetOoe: targetOoe,
    );
  }
}
