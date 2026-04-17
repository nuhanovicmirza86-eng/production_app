import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_station_page.dart';

/// Callable mutacije za `production_station_pages` (Admin SDK — tanka Firestore pravila).
class ProductionStationPageCallableService {
  ProductionStationPageCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<void> upsertProductionStationPage({
    required ProductionStationPage page,
  }) async {
    final cid = page.companyId.trim();
    final pk = page.plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      throw Exception('companyId i plantKey su obavezni.');
    }
    final res = await _functions
        .httpsCallable('upsertProductionStationPage')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'plantKey': pk,
          'stationSlot': page.stationSlot,
          'phase': page.phase.trim(),
          'active': page.active,
          'displayName': page.displayName,
          'notes': page.notes,
          'inboundWarehouseId': page.inboundWarehouseId,
          'outboundWarehouseId': page.outboundWarehouseId,
        });
    if (res.data['success'] != true) {
      throw Exception('Spremanje stranice stanice nije uspjelo.');
    }
  }
}
