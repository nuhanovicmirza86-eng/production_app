import 'package:cloud_functions/cloud_functions.dart';

/// Odgovor Callable-a [appendProductionCountEvent] (codebase production).
class AppendProductionCountCallableResult {
  const AppendProductionCountCallableResult({
    required this.success,
    required this.alreadyApplied,
    required this.eventId,
    required this.requestHash,
  });

  final bool success;
  final bool alreadyApplied;
  final String? eventId;
  final String? requestHash;
}

/// Wrapper za upis `production_count_events` preko `functions_production`, regija `europe-west1`.
class ProductionCountCallableService {
  ProductionCountCallableService({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  String _t(String? v) => (v ?? '').toString().trim();

  /// Backend materijalizira jedan dokument u [production_count_events] (idempotency na serveru).
  Future<AppendProductionCountCallableResult> appendProductionCountEvent({
    required String companyId,
    required String plantKey,
    required String machineId,
    required DateTime timestamp,
    required double totalCountIncrement,
    required double goodCountIncrement,
    required double scrapCountIncrement,
    required String source,
    required String idempotencyKey,
    String? lineId,
    String? orderId,
    String? productId,
    String? shiftId,
  }) async {
    final cid = _t(companyId);
    final pk = _t(plantKey);
    final mid = _t(machineId);
    final src = _t(source);
    final iKey = _t(idempotencyKey);
    if (cid.isEmpty || pk.isEmpty || mid.isEmpty) {
      throw ArgumentError('companyId, plantKey i machineId su obavezni.');
    }
    if (src.isEmpty) {
      throw ArgumentError('source je obavezan.');
    }
    if (iKey.isEmpty) {
      throw ArgumentError('idempotencyKey je obavezan.');
    }

    final body = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
      'machineId': mid,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'totalCountIncrement': totalCountIncrement,
      'goodCountIncrement': goodCountIncrement,
      'scrapCountIncrement': scrapCountIncrement,
      'source': src,
      'idempotencyKey': iKey,
      if (_t(lineId).isNotEmpty) 'lineId': _t(lineId),
      if (_t(orderId).isNotEmpty) 'orderId': _t(orderId),
      if (_t(productId).isNotEmpty) 'productId': _t(productId),
      if (_t(shiftId).isNotEmpty) 'shiftId': _t(shiftId),
    };

    final res = await _f.httpsCallable('appendProductionCountEvent').call(body);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Odgovor appendProductionCountEvent nije mapa.');
    }
    final m = Map<String, dynamic>.from(raw);
    final ok = m['success'] == true;
    final applied = m['alreadyApplied'] == true;
    final eid = _t(m['eventId'] as String?);
    final rh = _t(m['requestHash'] as String?);

    return AppendProductionCountCallableResult(
      success: ok,
      alreadyApplied: applied,
      eventId: eid.isEmpty ? null : eid,
      requestHash: rh.isEmpty ? null : rh,
    );
  }
}
