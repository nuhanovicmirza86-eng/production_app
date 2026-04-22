/// Tip ograničenja / razloga zašto nalog ne staje u plan.
enum PlanningConflictType {
  noMachineCapacity,
  noMachineAssigned,
  noToolCapacity,
  noOperatorCapacity,
  materialNotAvailable,
  dueDateRisk,
  beyondHorizon,
  sequenceNotFeasible,
  other,
}

class PlanningConflict {
  const PlanningConflict({
    this.planId,
    this.productionOrderId,
    this.relatedMachineId,
    this.relatedToolId,
    required this.type,
    required this.message,
    this.suggestion,
    this.severity = 1,
  });

  final String? planId;
  final String? productionOrderId;
  final String? relatedMachineId;
  final String? relatedToolId;
  final PlanningConflictType type;
  final String message;
  final String? suggestion;
  final int severity;
}
