import 'package:flutter/material.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_audit_log_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_corrections_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_daily_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_devices_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_hr_ai_insights_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_hr_kpi_report_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_manager_assignment_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_monthly_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_overview_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_payroll_export_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_rules_screen.dart';
import 'package:production_app/modules/personal/work_time/screens/work_time_worker_absences_screen.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_access.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Centralni ulaz: **Personal / Obračun radnog vremena** (matrica ekrana).
class WorkTimeHubScreen extends StatelessWidget {
  const WorkTimeHubScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  String get _role =>
      ProductionAccessHelper.normalizeRole(companyData['role']);

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => page,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!WorkTimeAccess.canOpenHub(_role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Obračun radnog vremena')),
        body: const Center(
          child: Text('Nemaš pristup ovom modulu (uloga).'),
        ),
      );
    }

    final admin = WorkTimeAccess.canOpenTenantAdminScreens(_role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal / Obračun radnog vremena'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          if (!admin) ...[
            const SizedBox(height: 10),
            Text(
              'Kao menadžer vidiš pregled, dnevnu i mjesečnu evidenciju te korekcije. '
              'Pravila, uređaji, izvoz za plaće i dnevnik promjena — samo administrator tvrtke.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.dashboard_outlined,
            title: 'Pregled obračuna',
            subtitle: 'Mjesec, status, ključni brojevi i odstupanja',
            onTap: () => _open(
              context,
              WorkTimeOverviewScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.view_day_outlined,
            title: 'Dnevna evidencija',
            subtitle: 'Radnici, prijave, dnevna mreža i sažetak',
            onTap: () => _open(
              context,
              WorkTimeDailyScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.calendar_month_outlined,
            title: 'Mjesečni obračun',
            subtitle: 'Fond, kategorije sati',
            onTap: () => _open(
              context,
              WorkTimeMonthlyScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.event_busy_outlined,
            title: 'Odsustva po radniku',
            subtitle: 'Bolovanje, godišnji, ostala; saldo godišnjeg',
            onTap: () => _open(
              context,
              WorkTimeWorkerAbsencesScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.assessment_outlined,
            title: 'Izvještaj o ponašanju i odsustvima',
            subtitle: 'Ukupne brojke po vrstama i upozorenja',
            onTap: () => _open(
              context,
              WorkTimeHrKpiReportScreen(companyData: companyData),
            ),
          ),
          _tile(
            context,
            icon: Icons.psychology_outlined,
            title: 'Pomoćnik: kašnjenja, odsustva, prekovremene',
            subtitle: 'Predložena pitanja za asistenta',
            onTap: () => _open(
              context,
              WorkTimeHrAiInsightsScreen(companyData: companyData),
            ),
          ),
          if (admin)
            _tile(
              context,
              icon: Icons.tune,
              title: 'Pravila obračuna',
              subtitle: 'Norme, smjene, godišnji — samo administrator tvrtke',
              onTap: () => _open(
                context,
                WorkTimeRulesScreen(companyData: companyData),
              ),
            ),
          if (admin)
            _tile(
              context,
              icon: Icons.router_outlined,
              title: 'Uređaji',
              subtitle: 'LAN / sync status',
              onTap: () => _open(
                context,
                WorkTimeDevicesScreen(companyData: companyData),
              ),
            ),
          _tile(
            context,
            icon: Icons.edit_note_outlined,
            title: 'Korekcije',
            subtitle: 'Zahtjev, razlog, odobrenje, audit',
            onTap: () => _open(
              context,
              WorkTimeCorrectionsScreen(companyData: companyData),
            ),
          ),
          if (admin)
            _tile(
              context,
              icon: Icons.manage_accounts_outlined,
              title: 'Dodjela radnika managerima',
              subtitle: 'Tko u kojem timu vidi koje zaposlenike',
              onTap: () => _open(
                context,
                WorkTimeManagerAssignmentScreen(companyData: companyData),
              ),
            ),
          if (admin)
            _tile(
              context,
              icon: Icons.payments_outlined,
              title: 'Izvoz za plaće',
              subtitle: 'Zaključani mjesec, datoteka za obračun',
              onTap: () => _open(
                context,
                WorkTimePayrollExportScreen(companyData: companyData),
              ),
            ),
          if (admin)
            _tile(
              context,
              icon: Icons.history,
              title: 'Dnevnik promjena',
              subtitle: 'Tko je i kada išao na postavke i zapisnike',
              onTap: () => _open(
                context,
                WorkTimeAuditLogScreen(companyData: companyData),
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
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
