import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/warehouse_hub_row.dart';

/// Katalog magacina + Callable `createWarehouseFromHub`.
class WarehouseHubService {
  WarehouseHubService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _db = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _db.collection('warehouses');

  /// Svi magacini kompanije (aktivni i neaktivni), sortirano po redoslijedu.
  Future<List<WarehouseHubRow>> listWarehouses({required String companyId}) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _warehouses.where('companyId', isEqualTo: cid).get();

    final rows = snap.docs
        .map((d) => WarehouseHubRow.fromDoc(d.id, d.data()))
        .toList();

    rows.sort((a, b) {
      final c = a.displayOrder.compareTo(b.displayOrder);
      if (c != 0) return c;
      return a.code.toLowerCase().compareTo(b.code.toLowerCase());
    });

    return rows;
  }

  /// Opcije pogona za padajući izbor (aktivni `company_plants`).
  Future<List<({String plantKey, String label})>> listPlantOptions({
    required String companyId,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _db
        .collection('company_plants')
        .where('companyId', isEqualTo: cid)
        .get();

    final out = <({String plantKey, String label})>[];
    for (final d in snap.docs) {
      final data = d.data();
      final active = data['active'];
      if (active is bool && active == false) continue;
      final pk = (data['plantKey'] ?? '').toString().trim();
      if (pk.isEmpty) continue;
      final name = (data['displayName'] ?? data['defaultName'] ?? pk)
          .toString()
          .trim();
      out.add((plantKey: pk, label: name.isEmpty ? pk : name));
    }
    out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return out;
  }

  /// Atomski: MAG_* + dokument u `warehouses`.
  Future<void> createWarehouse({
    required String companyId,
    required String displayName,
    required String type,
    String plantKey = '',
    bool isHub = false,
    bool canReceive = true,
    bool canShip = true,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw Exception('Nedostaje podatak o kompaniji. Obrati se administratoru.');

    final res = await _functions
        .httpsCallable('createWarehouseFromHub')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'displayName': displayName.trim(),
          'type': type.trim(),
          'plantKey': plantKey.trim(),
          'isHub': isHub,
          'canReceive': canReceive,
          'canShip': canShip,
        });

    final ok = res.data['success'] == true;
    if (!ok) {
      throw Exception('Kreiranje magacina nije potvrđeno.');
    }
  }

  /// Iste ovlasti kao [createWarehouse]; MAG_* se ne mijenja.
  Future<void> updateWarehouse({
    required String companyId,
    required String warehouseId,
    required String displayName,
    required String type,
    String plantKey = '',
    bool isHub = false,
    bool canReceive = true,
    bool canShip = true,
    required bool isActive,
    required int displayOrder,
  }) async {
    final cid = companyId.trim();
    final wid = warehouseId.trim();
    if (cid.isEmpty) throw Exception('Nedostaje podatak o kompaniji. Obrati se administratoru.');
    if (wid.isEmpty) throw Exception('Nedostaje warehouseId.');

    final res = await _functions
        .httpsCallable('updateWarehouseFromHub')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'warehouseId': wid,
          'displayName': displayName.trim(),
          'type': type.trim(),
          'plantKey': plantKey.trim(),
          'isHub': isHub,
          'canReceive': canReceive,
          'canShip': canShip,
          'isActive': isActive,
          'displayOrder': displayOrder,
        });

    final ok = res.data['success'] == true;
    if (!ok) {
      throw Exception('Ažuriranje magacina nije potvrđeno.');
    }
  }
}
