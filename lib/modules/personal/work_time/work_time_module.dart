/// Personal → Obračun radnog vremena — podmodul `work_time/`.
///
/// Arhiva: `maintenance_app/docs/architecture/archive/2026-04-24_TIME_AND_ATTENDANCE_PAYROLL_MODULE.md` (§12–15).
/// UI ulaz: [WorkTimeHubScreen]; dashboard kartica ako je u `enabledModules` modul `personal` (u debugu i bez modula radi dema).
library;

export 'models/work_time_absence_types.dart';
export 'models/work_time_annual_leave_display.dart';
export 'models/work_time_data_pipeline.dart';
export 'models/work_time_hr_kpi_rollup.dart';
export 'models/work_time_matrix_demo.dart';
export 'models/work_time_rules_draft.dart';
export 'models/work_time_settlement_status.dart';
export 'screens/work_time_attendance_workspace_screen.dart';
export 'screens/work_time_audit_log_screen.dart';
export 'screens/work_time_corrections_screen.dart';
export 'screens/work_time_daily_screen.dart';
export 'screens/work_time_devices_screen.dart';
export 'screens/work_time_hr_ai_insights_screen.dart';
export 'screens/work_time_hr_kpi_report_screen.dart';
export 'screens/work_time_hub_screen.dart';
export 'screens/work_time_manager_assignment_screen.dart';
export 'screens/work_time_monthly_screen.dart';
export 'screens/work_time_overview_screen.dart';
export 'screens/work_time_payroll_export_screen.dart';
export 'screens/work_time_rules_screen.dart';
export 'screens/work_time_worker_absences_screen.dart';
export 'services/work_time_access.dart';
export 'services/work_time_recompute_service.dart';
export 'services/work_time_rules_service.dart';
export 'models/orv_demo_data.dart';
export 'widgets/orv_employee_list_column.dart';
export 'widgets/orv_event_control_block.dart';
export 'widgets/orv_summary_rail.dart';
export 'widgets/orv_work_time_timeline.dart';
export 'widgets/work_time_data_layers_hint.dart';
export 'widgets/work_time_demo_banner.dart';
export 'widgets/work_time_kpi_grid.dart';
export 'widgets/work_time_period_bar.dart';
export 'widgets/work_time_settlement_status_badge.dart';
