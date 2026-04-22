import 'package:flutter/foundation.dart';

import '../models/planning_engine_result.dart';

/// Jedan blok u Gantt prikazu (nakon učitavanja ili iz motora u memoriji).
@immutable
class PlanningGanttOp {
  const PlanningGanttOp({
    required this.orderCode,
    required this.machineId,
    required this.plannedStart,
    required this.plannedEnd,
    this.runStart,
    this.runEnd,
    this.operationLabel,
  });

  final String orderCode;
  final String machineId;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final DateTime? runStart;
  final DateTime? runEnd;
  /// Prikaz koraka (routings) ili sintetički; iz [ScheduledOperation.sourceFactors] / Firestorea.
  final String? operationLabel;
}

/// Ulaz za Gantt ekran (iz memorije ili nakon učitavanja iz baze).
@immutable
class PlanningGanttDto {
  const PlanningGanttDto({
    required this.planId,
    required this.planCode,
    required this.operations,
    required this.windowStart,
    required this.windowEnd,
  });

  final String planId;
  final String planCode;
  final List<PlanningGanttOp> operations;
  final DateTime windowStart;
  final DateTime windowEnd;

  static String? _operationLabelFromSource(Map<String, dynamic> sf) {
    final s = (sf['operationLabel'] as String?)?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static PlanningGanttDto fromEngineResult(PlanningEngineResult r) {
    final byOrder = {
      for (final it in r.plan.items) it.productionOrderId: it.productionOrderCode ?? '',
    };
    final ops = r.scheduledOperations
        .map(
          (op) => PlanningGanttOp(
            orderCode: (byOrder[op.productionOrderId] ?? '').trim().isEmpty
                ? '—'
                : (byOrder[op.productionOrderId] ?? '').trim(),
            machineId: op.machineId,
            plannedStart: op.plannedStart,
            plannedEnd: op.plannedEnd,
            runStart: op.runStart,
            runEnd: op.runEnd,
            operationLabel: _operationLabelFromSource(op.sourceFactors),
          ),
        )
        .toList();
    if (ops.isEmpty) {
      return PlanningGanttDto(
        planId: r.plan.id,
        planCode: r.plan.planCode,
        operations: const [],
        windowStart: r.plan.planningStart ?? DateTime.now(),
        windowEnd: r.plan.planningEnd ?? DateTime.now(),
      );
    }
    var w0 = ops.first.plannedStart;
    var w1 = ops.first.plannedEnd;
    for (final o in ops) {
      if (o.plannedStart.isBefore(w0)) w0 = o.plannedStart;
      if (o.plannedEnd.isAfter(w1)) w1 = o.plannedEnd;
    }
    return PlanningGanttDto(
      planId: r.plan.id,
      planCode: r.plan.planCode,
      operations: ops,
      windowStart: w0,
      windowEnd: w1,
    );
  }
}
