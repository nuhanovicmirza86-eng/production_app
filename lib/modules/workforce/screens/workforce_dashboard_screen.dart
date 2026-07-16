import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../personal/work_time/screens/work_time_hub_screen.dart';
import '../../personal/work_time/services/work_time_access.dart';
import '../attendance/attendance_screen.dart';
import '../compliance_documents/compliance_list_screen.dart';
import '../employee_profiles/employee_list_screen.dart';
import '../employee_profiles/workforce_employee_qr_scan_screen.dart';
import '../leave_management/leave_operational_screen.dart';
import '../../../features/workforce_performance_norms/screens/workforce_performance_norms_list_screen.dart';
import '../performance_feedback/employee_kpi_dashboard_screen.dart';
import '../performance_feedback/feedback_list_screen.dart';
import '../../../features/worker_ai_planning/screens/worker_performance_ai_planning_screen.dart';
import '../recommendations/workforce_recommendations_screen.dart';
import '../shift_planning/shift_planning_screen.dart';
import '../skills_matrix/skills_matrix_screen.dart';
import '../training_records/training_list_screen.dart';

/// Radna snaga — operativni modul radnika (direktni importi: stabilnije na webu).
class WorkforceDashboardScreen extends StatelessWidget {
  const WorkforceDashboardScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  String get _role =>
      ProductionAccessHelper.normalizeRole(companyData['role']);

  bool get _canView => ProductionAccessHelper.canView(
        role: _role,
        card: ProductionDashboardCard.shifts,
      );

  bool get _canCompliance =>
      ProductionAccessHelper.isSuperAdminRole(_role) ||
      ProductionAccessHelper.isAdminRole(_role);

  bool get _canManageWorkforce => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.shifts,
      );

  bool get _canManageNorms =>
      ProductionAccessHelper.canManageWorkforcePerformanceNorms(_role);

  bool get _canViewEvidenceAiPlanning =>
      ProductionAccessHelper.canViewProfileDrivenEvidence(_role);

  bool get _canAccessPersonalWorkTime {
    if (!WorkTimeAccess.canOpenHub(_role)) return false;
    if (kDebugMode) return true;
    return ProductionModuleKeys.hasModule(companyData, ProductionModuleKeys.personal);
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Radna snaga')),
        body: const Center(child: Text('Nemaš pristup ovom modulu.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Radna snaga')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            context,
            icon: Icons.badge_outlined,
            title: 'Operativni profil radnika',
            subtitle: 'Šifra, ime, pogon, smjena, kontakt',
            onTap: () => _open(
              context,
              EmployeeListScreen(companyData: companyData),
            ),
          ),
          if (_canManageWorkforce)
            _tile(
              context,
              icon: Icons.qr_code_scanner,
              title: 'Skeniraj bedž radnika',
              subtitle: 'Otvara profil u ovom pogonu',
              onTap: () => _open(
                context,
                WorkforceEmployeeQrScanScreen(companyData: companyData),
              ),
            ),
          _tile(
            context,
            icon: Icons.calendar_month_outlined,
            title: 'Raspored smjena',
            subtitle: 'Plan po danu',
            onTap: () => _open(
              context,
              ShiftPlanningScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Prisutnost',
            subtitle: 'Operativni status',
            onTap: () => _open(
              context,
              AttendanceScreen(companyData: companyData),
            ),
          ),
          if (_canAccessPersonalWorkTime)
            _tile(
              context,
              icon: Icons.access_time_filled,
              title: 'Obračun radnog vremena',
              subtitle:
                  'Prijave, dnevna i mjesečna evidencija, korekcije (modul Osobno).',
              onTap: () => _open(
                context,
                WorkTimeHubScreen(companyData: companyData),
              ),
            ),
          _tile(
            context,
            icon: Icons.grid_on_outlined,
            title: 'Matrica kvalifikacija',
            subtitle: 'Osposobljenost za rad i strojeve',
            onTap: () => _open(
              context,
              SkillsMatrixScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.school_outlined,
            title: 'Evidencija obuka',
            subtitle: 'Planirane i završene obuke',
            onTap: () => _open(
              context,
              TrainingListScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.insights_outlined,
            title: 'KPI radnika',
            subtitle: 'Rezultati i praćenje rada',
            onTap: () => _open(
              context,
              EmployeeKpiDashboardScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.feedback_outlined,
            title: 'Performanse i povratne informacije',
            subtitle: 'Savjetovanje, priznanje i evidencija ocjena',
            onTap: () => _open(
              context,
              FeedbackListScreen(companyData: companyData),
            ),
          ),
          if (_canManageNorms)
            _tile(
              context,
              icon: Icons.rule_outlined,
              title: 'Normativi rada',
              subtitle: 'Unos, verzionisanje i test match-a normativa učinka',
              onTap: () => _open(
                context,
                WorkforcePerformanceNormsListScreen(companyData: companyData),
              ),
            ),
          if (_canViewEvidenceAiPlanning)
            _tile(
              context,
              icon: Icons.auto_awesome_outlined,
              title: 'AI preporuke za planiranje rada',
              subtitle: 'Savjetodavne preporuke iz evidencija procesa',
              onTap: () => _open(
                context,
                WorkerPerformanceAiPlanningScreen(companyData: companyData),
              ),
            ),
          if (_canCompliance)
            _tile(
              context,
              icon: Icons.gavel_outlined,
              title: 'Dokumenti usklađenosti',
              subtitle: 'Samo administrator',
              onTap: () => _open(
                context,
                ComplianceListScreen(companyData: companyData),
              ),
            ),
          _tile(
            context,
            icon: Icons.event_busy_outlined,
            title: 'Odsustva (operativno)',
            subtitle: 'Dostupnost za planiranje',
            onTap: () => _open(
              context,
              LeaveOperationalScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.auto_awesome_motion_outlined,
            title: 'Preporuke i rizik',
            subtitle: 'Sažetak za planiranje',
            onTap: () => _open(
              context,
              WorkforceRecommendationsScreen(companyData: companyData),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
