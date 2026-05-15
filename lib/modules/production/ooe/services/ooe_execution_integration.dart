import '../models/machine_state_event.dart';
import 'machine_state_callable_service.dart';
import 'machine_state_service.dart';
import 'ooe_live_service.dart';
import 'production_count_service.dart';

/// Povezuje production execution događaje s OOE machine state / count eventima (bez logike u [ProductionOrderService]).
///
/// Pozivi su best-effort: greška u OOE ne smije srušiti execution.
class OoeExecutionIntegration {
  OoeExecutionIntegration._();

  static final MachineStateService _machine = MachineStateService();
  static final MachineStateCallableService _machineCallable =
      MachineStateCallableService();
  static final ProductionCountService _counts = ProductionCountService();
  static final OoeLiveService _live = OoeLiveService();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Segment u ključu kad nema naloga — izbjegava dvostruke `::`.
  static String _orderKeySegment(String orderId) =>
      orderId.isEmpty ? '-' : orderId;

  static String _idempotencyKey({
    required String companyId,
    required String plantKey,
    required String machineId,
    required String orderId,
    required String handler,
    required DateTime effectiveAt,
  }) {
    final ts = effectiveAt.toUtc().toIso8601String();
    return 'machineState:${_s(companyId)}:${_s(plantKey)}:${_s(machineId)}:'
        '${_orderKeySegment(_s(orderId))}:$handler:$ts';
  }

  static String _productionCountIdempotencyKey({
    required String companyId,
    required String plantKey,
    required String machineId,
    required String orderId,
    required DateTime timestamp,
  }) {
    final ts = timestamp.toUtc().toIso8601String();
    return 'productionCount:${_s(companyId)}:${_s(plantKey)}:${_s(machineId)}:'
        '${_orderKeySegment(_s(orderId))}:completed:$ts';
  }

  static Future<void> onExecutionStarted({
    required Map<String, dynamic> companyScope,
    required Map<String, dynamic> executionPayload,
  }) async {
    try {
      final companyId = _s(companyScope['companyId'] ?? executionPayload['companyId']);
      final plantKey = _s(companyScope['plantKey'] ?? executionPayload['plantKey']);
      final machineId = _s(executionPayload['machineId']);
      if (machineId.isEmpty) return;

      final orderId = _s(executionPayload['productionOrderId']);
      final productId = _s(executionPayload['productId']);
      final shiftId = _s(executionPayload['shiftCode']);
      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );

      await _machineCallable.transitionState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        toState: MachineStateEvent.stateRunning,
        effectiveTimestamp: now,
        source: MachineStateCallableService.defaultSource,
        idempotencyKey: _idempotencyKey(
          companyId: companyId,
          plantKey: plantKey,
          machineId: machineId,
          orderId: orderId,
          handler: 'started',
          effectiveAt: now,
        ),
        fromState: open?.state,
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
      );

      await _live.refreshLiveKpiForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        activeOrderId: orderId.isEmpty ? null : orderId,
        activeProductId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        lineId: _nullable(executionPayload['lineId']),
      );
    } catch (_) {
      // OOE ne blokira execution
    }
  }

  static Future<void> onExecutionPaused({
    required Map<String, dynamic> companyScope,
    required Map<String, dynamic> executionPayload,
  }) async {
    try {
      final companyId = _s(companyScope['companyId'] ?? executionPayload['companyId']);
      final plantKey = _s(companyScope['plantKey'] ?? executionPayload['plantKey']);
      final machineId = _s(executionPayload['machineId']);
      if (machineId.isEmpty) return;

      final orderId = _s(executionPayload['productionOrderId']);
      final productId = _s(executionPayload['productId']);
      final shiftId = _s(executionPayload['shiftCode']);
      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );

      final pauseCode = _s(executionPayload['ooePauseReasonCode']);
      final toStopped = pauseCode.isNotEmpty;
      await _machineCallable.transitionState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        toState: toStopped
            ? MachineStateEvent.stateStopped
            : MachineStateEvent.stateIdle,
        effectiveTimestamp: now,
        source: MachineStateCallableService.defaultSource,
        idempotencyKey: _idempotencyKey(
          companyId: companyId,
          plantKey: plantKey,
          machineId: machineId,
          orderId: orderId,
          handler: 'paused',
          effectiveAt: now,
        ),
        fromState: open?.state,
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        reasonCode: toStopped ? pauseCode : null,
      );

      await _live.refreshLiveKpiForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        activeOrderId: orderId.isEmpty ? null : orderId,
        activeProductId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        lineId: _nullable(executionPayload['lineId']),
      );
    } catch (_) {}
  }

  static Future<void> onExecutionResumed({
    required Map<String, dynamic> companyScope,
    required Map<String, dynamic> executionPayload,
  }) async {
    try {
      final companyId = _s(companyScope['companyId'] ?? executionPayload['companyId']);
      final plantKey = _s(companyScope['plantKey'] ?? executionPayload['plantKey']);
      final machineId = _s(executionPayload['machineId']);
      if (machineId.isEmpty) return;

      final orderId = _s(executionPayload['productionOrderId']);
      final productId = _s(executionPayload['productId']);
      final shiftId = _s(executionPayload['shiftCode']);
      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );

      await _machineCallable.transitionState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        toState: MachineStateEvent.stateRunning,
        effectiveTimestamp: now,
        source: MachineStateCallableService.defaultSource,
        idempotencyKey: _idempotencyKey(
          companyId: companyId,
          plantKey: plantKey,
          machineId: machineId,
          orderId: orderId,
          handler: 'resumed',
          effectiveAt: now,
        ),
        fromState: open?.state,
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
      );

      await _live.refreshLiveKpiForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        activeOrderId: orderId.isEmpty ? null : orderId,
        activeProductId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        lineId: _nullable(executionPayload['lineId']),
      );
    } catch (_) {}
  }

  static Future<void> onExecutionCompleted({
    required Map<String, dynamic> companyScope,
    required Map<String, dynamic> executionAfterPayload,
  }) async {
    try {
      final companyId =
          _s(companyScope['companyId'] ?? executionAfterPayload['companyId']);
      final plantKey =
          _s(companyScope['plantKey'] ?? executionAfterPayload['plantKey']);
      final machineId = _s(executionAfterPayload['machineId']);
      if (machineId.isEmpty) return;

      final orderId = _s(executionAfterPayload['productionOrderId']);
      final productId = _s(executionAfterPayload['productId']);
      final shiftId = _s(executionAfterPayload['shiftCode']);

      final good = _d(executionAfterPayload['goodQty']);
      final scrap = _d(executionAfterPayload['scrapQty']);

      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );

      await _machineCallable.transitionState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        toState: MachineStateEvent.stateIdle,
        effectiveTimestamp: now,
        source: MachineStateCallableService.defaultSource,
        idempotencyKey: _idempotencyKey(
          companyId: companyId,
          plantKey: plantKey,
          machineId: machineId,
          orderId: orderId,
          handler: 'completed',
          effectiveAt: now,
        ),
        fromState: open?.state,
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
      );

      await _counts.appendIncrement(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        timestamp: now,
        totalCountIncrement: good + scrap,
        goodCountIncrement: good,
        scrapCountIncrement: scrap,
        source: 'execution',
        idempotencyKey: _productionCountIdempotencyKey(
          companyId: companyId,
          plantKey: plantKey,
          machineId: machineId,
          orderId: orderId,
          timestamp: now,
        ),
        lineId: _nullable(executionAfterPayload['lineId']),
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
      );

      await _live.refreshLiveKpiForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        activeOrderId: null,
        activeProductId: null,
        shiftId: shiftId.isEmpty ? null : shiftId,
        lineId: _nullable(executionAfterPayload['lineId']),
      );
    } catch (_) {}
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
  }

  static String? _nullable(dynamic v) {
    final t = _s(v);
    return t.isEmpty ? null : t;
  }
}
