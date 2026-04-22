/// Sažetak opterećenja resursa nakon (ili tijekom) planiranja — za KPI i Gantt.
class MachineLoadEntry {
  const MachineLoadEntry({
    required this.machineId,
    required this.assignedMinutes,
    required this.horizonMinutes,
  });

  final String machineId;
  final int assignedMinutes;
  final int horizonMinutes;

  double get utilization01 =>
      horizonMinutes <= 0 ? 0 : (assignedMinutes / horizonMinutes).clamp(0, 1);
}

class PlanningResourceSnapshot {
  const PlanningResourceSnapshot({
    this.machineEntries = const [],
    this.bottleneckMachineId,
    this.horizonStart,
    this.horizonEnd,
  });

  final List<MachineLoadEntry> machineEntries;
  final String? bottleneckMachineId;
  final DateTime? horizonStart;
  final DateTime? horizonEnd;
}
