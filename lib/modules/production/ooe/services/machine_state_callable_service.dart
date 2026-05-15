import 'package:cloud_functions/cloud_functions.dart';

/// Odgovor Callable-a [mutateMachineStateEvent] (`action: transitionState`).
class MachineStateTransitionResult {
  const MachineStateTransitionResult({
    required this.closedEventId,
    required this.openedEventId,
    required this.alreadyApplied,
  });

  final String? closedEventId;
  final String? openedEventId;
  final bool alreadyApplied;
}

/// Wrappper za `mutateMachineStateEvent` (codebase `functions_production`, regija `europe-west1`).
///
/// Samo [transitionState]; ostale akcije idu direktno u Callable kad backend podrži.
class MachineStateCallableService {
  MachineStateCallableService({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  static const defaultSource = 'mes_execution';

  String _t(String? v) => (v ?? '').toString().trim();

  MachineStateTransitionResult _parseMap(dynamic raw) {
    if (raw is! Map) {
      throw Exception('Odgovor mutateMachineStateEvent nije mapa.');
    }
    final m = Map<String, dynamic>.from(raw);
    final closed = _t(m['closedEventId']);
    final opened = _t(m['openedEventId']);
    final already = m['alreadyApplied'] == true;
    return MachineStateTransitionResult(
      closedEventId: closed.isEmpty ? null : closed,
      openedEventId: opened.isEmpty ? null : opened,
      alreadyApplied: already,
    );
  }

  /// `action` je fiksno `transitionState`; tijelo usklađeno s backend kontraktom.
  Future<MachineStateTransitionResult> transitionState({
    required String companyId,
    required String plantKey,
    required String machineId,
    required String toState,
    required DateTime effectiveTimestamp,
    required String source,
    required String idempotencyKey,
    String? fromState,
    String? orderId,
    String? productId,
    String? shiftId,
    String? reasonCode,
    String? tpmLossKey,
    String? notes,
  }) async {
    final cid = _t(companyId);
    final pk = _t(plantKey);
    final mid = _t(machineId);
    final tState = _t(toState);
    final src = _t(source);
    final iKey = _t(idempotencyKey);

    if (cid.isEmpty || pk.isEmpty || mid.isEmpty) {
      throw ArgumentError('companyId, plantKey i machineId su obavezni.');
    }
    if (tState.isEmpty) {
      throw ArgumentError('toState je obavezan.');
    }
    if (src.isEmpty) {
      throw ArgumentError('source je obavezan.');
    }
    if (iKey.isEmpty) {
      throw ArgumentError('idempotencyKey je obavezan.');
    }

    final body = <String, dynamic>{
      'action': 'transitionState',
      'companyId': cid,
      'plantKey': pk,
      'machineId': mid,
      'toState': tState,
      'effectiveTimestamp': effectiveTimestamp.toUtc().toIso8601String(),
      'source': src,
      'idempotencyKey': iKey,
      if (_t(fromState).isNotEmpty) 'fromState': _t(fromState),
      if (_t(orderId).isNotEmpty) 'orderId': _t(orderId),
      if (_t(productId).isNotEmpty) 'productId': _t(productId),
      if (_t(shiftId).isNotEmpty) 'shiftId': _t(shiftId),
      if (_t(reasonCode).isNotEmpty) 'reasonCode': _t(reasonCode),
      if (_t(tpmLossKey).isNotEmpty) 'tpmLossKey': _t(tpmLossKey),
      if (_t(notes).isNotEmpty) 'notes': _t(notes),
    };

    final res = await _f.httpsCallable('mutateMachineStateEvent').call(body);
    return _parseMap(res.data);
  }
}
