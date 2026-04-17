import 'package:cloud_functions/cloud_functions.dart';

/// Callable mutacije za `packing_boxes` / `packing_operator_alerts` / `packedBoxId` (Admin SDK).
class PackingBoxCallableService {
  PackingBoxCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  Future<String> createPackingBox({
    required String companyId,
    required String plantKey,
    required String classification,
    required List<Map<String, dynamic>> lines,
    int stationSlot = 1,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty || lines.isEmpty) {
      throw Exception('companyId, plantKey i lines su obavezni.');
    }
    final slot = stationSlot < 1 || stationSlot > 3 ? 1 : stationSlot;
    final res = await _functions.httpsCallable('createPackingBox').call<Map<String, dynamic>>({
      'companyId': cid,
      'plantKey': pk,
      'classification': classification.trim(),
      'lines': lines,
      'stationSlot': slot,
    });
    final data = res.data;
    final id = _s(data['boxId']);
    if (data['success'] != true || id.isEmpty) {
      throw Exception('Kreiranje kutije nije uspjelo.');
    }
    return id;
  }

  Future<void> markPackingBoxReceived({
    required String companyId,
    required String boxId,
  }) async {
    final cid = companyId.trim();
    final bid = boxId.trim();
    if (cid.isEmpty || bid.isEmpty) {
      throw Exception('companyId i boxId su obavezni.');
    }
    final payload = <String, dynamic>{
      'companyId': cid,
      'boxId': bid,
    };
    final res = await _functions
        .httpsCallable('markPackingBoxReceived')
        .call<Map<String, dynamic>>(payload);
    if (res.data['success'] != true) {
      throw Exception('Prijem kutije nije uspio.');
    }
  }

  Future<void> writePackingOperatorAlertsUnpacked({
    required String companyId,
    required String plantKey,
    required String workDate,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final wd = workDate.trim();
    if (cid.isEmpty || pk.isEmpty || wd.isEmpty) {
      throw Exception('companyId, plantKey i workDate su obavezni.');
    }
    final res = await _functions
        .httpsCallable('writePackingOperatorAlertsUnpacked')
        .call<Map<String, dynamic>>({
      'companyId': cid,
      'plantKey': pk,
      'workDate': wd,
    });
    if (res.data['success'] != true) {
      throw Exception('Upozorenja nisu zapisana.');
    }
  }

  Future<void> setTrackingPackedBoxIds({
    required String companyId,
    required String plantKey,
    required List<String> entryIds,
    required String packedBoxId,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final pid = packedBoxId.trim();
    if (cid.isEmpty || pk.isEmpty || pid.isEmpty || entryIds.isEmpty) {
      return;
    }
    final res = await _functions.httpsCallable('setTrackingPackedBoxIds').call<Map<String, dynamic>>({
      'companyId': cid,
      'plantKey': pk,
      'packedBoxId': pid,
      'entryIds': entryIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    });
    if (res.data['success'] != true) {
      throw Exception('Povezivanje unosa s kutijom nije uspjelo.');
    }
  }
}
