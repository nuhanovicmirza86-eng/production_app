import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/warehouse_route_row.dart';

class WarehouseRoutesService {
  WarehouseRoutesService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _db = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _routes =>
      _db.collection('warehouse_routes');

  Future<List<WarehouseRouteRow>> listRoutes({required String companyId}) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final snap = await _routes.where('companyId', isEqualTo: cid).get();
    final rows = snap.docs
        .map((d) => WarehouseRouteRow.fromDoc(d.id, d.data()))
        .toList();
    rows.sort((a, b) {
      final c = a.fromWarehouseId.compareTo(b.fromWarehouseId);
      if (c != 0) return c;
      return a.toWarehouseId.compareTo(b.toWarehouseId);
    });
    return rows;
  }

  Future<void> upsertRoute({
    required String companyId,
    String? routeId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<String> allowedItemTypes,
    required bool requiresQualityCheck,
    required bool active,
    String? notes,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw Exception('Nedostaje companyId.');

    final res = await _functions
        .httpsCallable('upsertWarehouseRoute')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          if (routeId != null && routeId.trim().isNotEmpty)
            'routeId': routeId.trim(),
          'fromWarehouseId': fromWarehouseId.trim(),
          'toWarehouseId': toWarehouseId.trim(),
          'allowedItemTypes': allowedItemTypes,
          'requiresQualityCheck': requiresQualityCheck,
          'active': active,
          'notes': notes?.trim() ?? '',
        });

    if (res.data['success'] != true) {
      throw Exception('Snimanje rute nije potvrđeno.');
    }
  }
}
