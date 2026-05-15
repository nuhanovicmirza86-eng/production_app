import 'package:cloud_functions/cloud_functions.dart';

/// Odgovor Callable-a [refreshOoeLiveStatusForMachine] (codebase production).
///
/// [id] je Firestore doc id projekcije (`liveId` u payloadu odgovora).
/// [data] je puna mapa odgovora (npr. `currentShiftOoe`, `availability`, …).
class OoeLiveRefreshCallableResult {
  const OoeLiveRefreshCallableResult({
    required this.success,
    required this.id,
    required this.data,
  });

  final bool success;
  final String? id;
  final Map<String, dynamic> data;
}

/// Wrapper za OOE live Callablee iz `functions_production`, regija `europe-west1`.
class OoeLiveCallableService {
  OoeLiveCallableService({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  String _t(String? v) => (v ?? '').toString().trim();

  /// Materijalizacija `ooe_live_status` preko backend Callablea.
  Future<OoeLiveRefreshCallableResult> refreshOoeLiveStatusForMachine({
    required String companyId,
    required String plantKey,
    required String machineId,
    String? lineId,
    String? activeOrderId,
    String? activeProductId,
    String? shiftId,
    double? idealCycleTimeSeconds,
  }) async {
    final cid = _t(companyId);
    final pk = _t(plantKey);
    final mid = _t(machineId);
    if (cid.isEmpty || pk.isEmpty || mid.isEmpty) {
      throw ArgumentError('companyId, plantKey i machineId su obavezni.');
    }

    final body = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'machineId': mid,
      if (_t(lineId).isNotEmpty) 'lineId': _t(lineId),
      if (_t(activeOrderId).isNotEmpty) 'activeOrderId': _t(activeOrderId),
      if (_t(activeProductId).isNotEmpty) 'activeProductId': _t(activeProductId),
      if (_t(shiftId).isNotEmpty) 'shiftId': _t(shiftId),
      if (idealCycleTimeSeconds != null && idealCycleTimeSeconds > 0)
        'idealCycleTimeSeconds': idealCycleTimeSeconds,
    };

    final res = await _f.httpsCallable('refreshOoeLiveStatusForMachine').call(body);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Odgovor refreshOoeLiveStatusForMachine nije mapa.');
    }
    final m = Map<String, dynamic>.from(raw);
    final ok = m['success'] == true;
    final liveId = _t(m['liveId'] as String?);

    return OoeLiveRefreshCallableResult(
      success: ok,
      id: liveId.isEmpty ? null : liveId,
      data: m,
    );
  }
}
