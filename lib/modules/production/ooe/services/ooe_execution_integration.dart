import '../models/machine_state_event.dart';
import 'machine_state_service.dart';
import 'ooe_live_service.dart';
import 'production_count_service.dart';

/// Povezuje production execution događaje s OOE machine state / count eventima (bez logike u [ProductionOrderService]).
///
/// Pozivi su best-effort: greška u OOE ne smije srušiti execution.
class OoeExecutionIntegration {
  OoeExecutionIntegration._();

  static final MachineStateService _machine = MachineStateService();
  static final ProductionCountService _counts = ProductionCountService();
  static final OoeLiveService _live = OoeLiveService();

  static String _s(dynamic v) => (v ?? '').toString().trim();

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
      final operatorId = _s(executionPayload['operatorId']);
      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );
      if (open != null) {
        await _machine.closeState(
          eventId: open.id,
          companyId: companyId,
          plantKey: plantKey,
          endedAt: now,
        );
      }

      await _machine.openState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        state: MachineStateEvent.stateRunning,
        startedAt: now,
        source: 'execution',
        lineId: _nullable(executionPayload['lineId']),
        workCenterId: _nullable(executionPayload['workCenterId']),
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        shiftDate: DateTime(now.year, now.month, now.day),
        createdBy: operatorId.isEmpty ? null : operatorId,
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
      final operatorId = _s(executionPayload['operatorId']);
      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );
      if (open != null) {
        await _machine.closeState(
          eventId: open.id,
          companyId: companyId,
          plantKey: plantKey,
          endedAt: now,
        );
      }

      final pauseCode = _s(executionPayload['ooePauseReasonCode']);
      await _machine.openState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        state: MachineStateEvent.stateStopped,
        startedAt: now,
        source: 'execution',
        lineId: _nullable(executionPayload['lineId']),
        workCenterId: _nullable(executionPayload['workCenterId']),
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        shiftDate: DateTime(now.year, now.month, now.day),
        reasonCode: pauseCode.isEmpty ? null : pauseCode,
        createdBy: operatorId.isEmpty ? null : operatorId,
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
      final operatorId = _s(executionPayload['operatorId']);
      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );
      if (open != null) {
        await _machine.closeState(
          eventId: open.id,
          companyId: companyId,
          plantKey: plantKey,
          endedAt: now,
        );
      }

      await _machine.openState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        state: MachineStateEvent.stateRunning,
        startedAt: now,
        source: 'execution',
        lineId: _nullable(executionPayload['lineId']),
        workCenterId: _nullable(executionPayload['workCenterId']),
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        shiftDate: DateTime(now.year, now.month, now.day),
        createdBy: operatorId.isEmpty ? null : operatorId,
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
      final operatorId = _s(
        executionAfterPayload['updatedBy'] ?? executionAfterPayload['operatorId'],
      );

      final good = _d(executionAfterPayload['goodQty']);
      final scrap = _d(executionAfterPayload['scrapQty']);

      final now = DateTime.now();

      final open = await _machine.getLatestOpenEventForMachine(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
      );
      if (open != null) {
        await _machine.closeState(
          eventId: open.id,
          companyId: companyId,
          plantKey: plantKey,
          endedAt: now,
        );
      }

      await _machine.openState(
        companyId: companyId,
        plantKey: plantKey,
        machineId: machineId,
        state: MachineStateEvent.stateIdle,
        startedAt: now,
        source: 'execution',
        lineId: _nullable(executionAfterPayload['lineId']),
        workCenterId: _nullable(executionAfterPayload['workCenterId']),
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        shiftDate: DateTime(now.year, now.month, now.day),
        createdBy: operatorId.isEmpty ? null : operatorId,
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
        lineId: _nullable(executionAfterPayload['lineId']),
        orderId: orderId.isEmpty ? null : orderId,
        productId: productId.isEmpty ? null : productId,
        shiftId: shiftId.isEmpty ? null : shiftId,
        createdBy: operatorId.isEmpty ? null : operatorId,
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
