import 'package:cloud_functions/cloud_functions.dart';

/// Callable mutacije za `inventory_movements` / `inventory_balances` (Admin SDK).
class InventoryCallableService {
  InventoryCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Potvrda `production_output_pending` → `production_output_confirmed` + zaliha u magacinu.
  Future<void> confirmInventoryMovement({
    required String companyId,
    required String movementId,
  }) async {
    final cid = companyId.trim();
    final mid = movementId.trim();
    if (cid.isEmpty || mid.isEmpty) {
      throw Exception('companyId i movementId su obavezni.');
    }
    final res = await _functions
        .httpsCallable('confirmInventoryMovement')
        .call<Map<String, dynamic>>({'companyId': cid, 'movementId': mid});
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Potvrda kretanja nije uspjela.');
    }
  }

  /// Početna / dodatna zaliha (admin) — `createWarehouseSeedBalance`.
  Future<void> createWarehouseSeedBalance({
    required String companyId,
    required String warehouseId,
    required String productId,
    required double quantityOnHand,
    String? unit,
    String? plantKey,
  }) async {
    final cid = companyId.trim();
    final wid = warehouseId.trim();
    final pid = productId.trim();
    if (cid.isEmpty || wid.isEmpty || pid.isEmpty) {
      throw Exception('companyId, warehouseId i productId su obavezni.');
    }
    if (!(quantityOnHand > 0)) {
      throw Exception('quantityOnHand mora biti > 0.');
    }
    final payload = <String, dynamic>{
      'companyId': cid,
      'warehouseId': wid,
      'productId': pid,
      'quantityOnHand': quantityOnHand,
      if (unit != null && _s(unit).isNotEmpty) 'unit': _s(unit),
      if (plantKey != null && _s(plantKey).isNotEmpty) 'plantKey': _s(plantKey),
    };
    final res = await _functions
        .httpsCallable('createWarehouseSeedBalance')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Seed zalihe nije uspio.');
    }
  }
}
