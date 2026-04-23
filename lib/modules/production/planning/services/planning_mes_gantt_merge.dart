import 'package:cloud_firestore/cloud_firestore.dart';

import 'planning_gantt_dto.dart';

/// Iz MES zapisa gradi blokove [PlanningGanttOp] s [PlanningGanttBlockKind.mesActual].
List<PlanningGanttOp> planningMesGanttOpsFromExecutions({
  required Map<String, List<Map<String, dynamic>>> mesByOrderId,
  required Set<String> productionOrderIdsInPlan,
  required String Function(String orderId) orderCodeFor,
}) {
  final out = <PlanningGanttOp>[];
  for (final oid in productionOrderIdsInPlan) {
    final list = mesByOrderId[oid] ?? const <Map<String, dynamic>>[];
    final code = orderCodeFor(oid);
    for (final m in list) {
      final s = m['startedAt'];
      if (s is! Timestamp) {
        continue;
      }
      final start = s.toDate();
      final machineId = (m['machineId'] ?? '').toString().trim();
      if (machineId.isEmpty) {
        continue;
      }
      final eEnd = m['endedAt'];
      final status = (m['status'] ?? '').toString().toLowerCase();
      late final DateTime end;
      if (eEnd is Timestamp) {
        end = eEnd.toDate();
      } else if (status == 'started' || status == 'paused') {
        end = DateTime.now();
      } else {
        end = start.add(const Duration(minutes: 1));
      }
      var e = end;
      if (!e.isAfter(start)) {
        e = start.add(const Duration(minutes: 1));
      }
      final exId = (m['id'] ?? '').toString().trim();
      out.add(
        PlanningGanttOp(
          orderCode: code,
          machineId: machineId,
          plannedStart: start,
          plannedEnd: e,
          productionOrderId: oid,
          scheduledOperationId: exId.isEmpty ? 'mes_${Object.hash(oid, start, machineId)}' : 'mes_$exId',
          runStart: null,
          runEnd: null,
          operationLabel: 'Stvarno (MES)',
          blockKind: PlanningGanttBlockKind.mesActual,
        ),
      );
    }
  }
  return out;
}

PlanningGanttDto appendGanttOperations(PlanningGanttDto base, List<PlanningGanttOp> extra) {
  if (extra.isEmpty) {
    return base;
  }
  final all = [...base.operations, ...extra];
  var w0 = base.windowStart;
  var w1 = base.windowEnd;
  for (final o in all) {
    if (o.plannedStart.isBefore(w0)) {
      w0 = o.plannedStart;
    }
    if (o.plannedEnd.isAfter(w1)) {
      w1 = o.plannedEnd;
    }
  }
  return PlanningGanttDto(
    planId: base.planId,
    planCode: base.planCode,
    operations: all,
    windowStart: w0,
    windowEnd: w1,
  );
}
