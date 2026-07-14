import 'aps_gantt_resource_lane.dart';
import 'aps_scenario_view.dart';
import 'aps_schedule_operation_view.dart';

/// Agregat za read-only Gantt ekran.
class ApsGanttViewData {
  const ApsGanttViewData({
    required this.scenario,
    required this.lanes,
    required this.operations,
  });

  final ApsScenarioView scenario;
  final List<ApsGanttResourceLane> lanes;
  final List<ApsScheduleOperationView> operations;

  bool get hasOperations => operations.isNotEmpty;

  /// Sve operacije u nacrtu plana — preduvjet za P4a potvrdu.
  bool get allOperationsDraftPlanned =>
      operations.isNotEmpty &&
      operations.every((op) => op.status == 'draft_planned');

  DateTime? get horizonStart => scenario.periodStart;

  DateTime? get horizonEnd => scenario.periodEnd;
}
