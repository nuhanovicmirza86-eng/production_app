import 'aps_schedule_operation_view.dart';

/// Red Gantt-a — jedan resurs i njegove operacije u horizontu.
class ApsGanttResourceLane {
  const ApsGanttResourceLane({
    required this.resourceCode,
    required this.operations,
  });

  final String resourceCode;
  final List<ApsScheduleOperationView> operations;

  String get displayLabel =>
      resourceCode.trim().isNotEmpty ? resourceCode.trim() : 'Resurs';
}
