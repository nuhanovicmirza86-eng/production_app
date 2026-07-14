/// Zajedničko stanje APS Debug Hub-a — preživljava prebacivanje P0/P1/P2 tabova.
class ApsDebugHubSharedState {
  String lastDemandId = '';
  String lastScenarioId = '';
  String lastScenarioItemId = '';
  String lastScheduleRunId = '';
  String lastPlanningInputSnapshotId = '';
  String lastOptimizationRunId = '';
  String lastCandidateScheduleRunId = '';

  /// Primijeni samo ne-prazne patch vrijednosti.
  void applyPatch({
    String? lastDemandId,
    String? lastScenarioId,
    String? lastScenarioItemId,
    String? lastScheduleRunId,
    String? lastPlanningInputSnapshotId,
    String? lastOptimizationRunId,
    String? lastCandidateScheduleRunId,
  }) {
    if (lastDemandId != null && lastDemandId.trim().isNotEmpty) {
      this.lastDemandId = lastDemandId.trim();
    }
    if (lastScenarioId != null && lastScenarioId.trim().isNotEmpty) {
      this.lastScenarioId = lastScenarioId.trim();
    }
    if (lastScenarioItemId != null && lastScenarioItemId.trim().isNotEmpty) {
      this.lastScenarioItemId = lastScenarioItemId.trim();
    }
    if (lastScheduleRunId != null && lastScheduleRunId.trim().isNotEmpty) {
      this.lastScheduleRunId = lastScheduleRunId.trim();
    }
    if (lastPlanningInputSnapshotId != null &&
        lastPlanningInputSnapshotId.trim().isNotEmpty) {
      this.lastPlanningInputSnapshotId = lastPlanningInputSnapshotId.trim();
    }
    if (lastOptimizationRunId != null && lastOptimizationRunId.trim().isNotEmpty) {
      this.lastOptimizationRunId = lastOptimizationRunId.trim();
    }
    if (lastCandidateScheduleRunId != null &&
        lastCandidateScheduleRunId.trim().isNotEmpty) {
      this.lastCandidateScheduleRunId = lastCandidateScheduleRunId.trim();
    }
  }

  bool get hasScenarioId => lastScenarioId.isNotEmpty;
}
