import 'package:flutter/foundation.dart';

import 'planning_conflict.dart';
import 'planning_resource_snapshot.dart';
import 'production_plan.dart';
import 'scheduled_operation.dart';

@immutable
class PlanningEngineKpi {
  const PlanningEngineKpi({
    required this.totalPlannedOrders,
    required this.feasibleOrders,
    required this.infeasibleOrders,
    this.onTimeRate01,
    this.totalLatenessMinutes = 0,
    this.bottleneckMachineId,
  });

  final int totalPlannedOrders;
  final int feasibleOrders;
  final int infeasibleOrders;
  final double? onTimeRate01;
  final int totalLatenessMinutes;
  final String? bottleneckMachineId;
}

@immutable
class PlanningEngineResult {
  const PlanningEngineResult({
    required this.plan,
    this.scheduledOperations = const [],
    this.conflicts = const [],
    this.resourceSnapshot,
    this.kpi,
  });

  final ProductionPlan plan;
  final List<ScheduledOperation> scheduledOperations;
  final List<PlanningConflict> conflicts;
  final PlanningResourceSnapshot? resourceSnapshot;
  final PlanningEngineKpi? kpi;
}
