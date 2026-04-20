import 'package:flutter/material.dart';

import 'capa_tracking_screen.dart';
import 'control_plans_list_screen.dart';
import 'execute_inspection_screen.dart';
import 'inspection_plans_list_screen.dart';
import 'ncr_list_screen.dart';
import 'quality_dashboard_screen.dart';

/// Centralni ulaz u QMS modul (pretplata `quality` + uloga iz matrice).
class QualityHubScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const QualityHubScreen({super.key, required this.companyData});

  void _open(BuildContext context, Widget screen) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvalitet (QMS)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'IATF-friendly QMS: kontrolni plan → inspekcija → NCR → CAPA → sljedljivost.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _HubTile(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            subtitle: 'KPI, otvoreni NCR/CAPA',
            onTap: () => _open(context, QualityDashboardScreen(companyData: companyData)),
          ),
          _HubTile(
            icon: Icons.engineering_outlined,
            title: 'Kontrolni planovi',
            subtitle: 'Master data (APQP)',
            onTap: () => _open(context, ControlPlansListScreen(companyData: companyData)),
          ),
          _HubTile(
            icon: Icons.fact_check_outlined,
            title: 'Planovi inspekcije',
            subtitle: 'Ulaz / u procesu / finalno',
            onTap: () =>
                _open(context, InspectionPlansListScreen(companyData: companyData)),
          ),
          _HubTile(
            icon: Icons.qr_code_scanner,
            title: 'Izvrši inspekciju',
            subtitle: 'Sken LOT-a ili naloga',
            onTap: () => _open(context, ExecuteInspectionScreen(companyData: companyData)),
          ),
          _HubTile(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'NCR',
            subtitle: 'Neskladi',
            onTap: () => _open(context, NcrListScreen(companyData: companyData)),
          ),
          _HubTile(
            icon: Icons.task_alt_outlined,
            title: 'CAPA',
            subtitle: 'Korektivne akcije',
            onTap: () => _open(context, CapaTrackingScreen(companyData: companyData)),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
