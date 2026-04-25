import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_attendance_workspace_screen.dart';

/// Dnevna evidencija — ORV mreža: radnici, događaji, sažetak, 0–24.
///
/// Vidi: [WorkTimeAttendanceWorkspaceScreen] (stvarni layout; demo podaci u `orv_demo_data`).
class WorkTimeDailyScreen extends StatelessWidget {
  const WorkTimeDailyScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    return WorkTimeAttendanceWorkspaceScreen(companyData: companyData);
  }
}
