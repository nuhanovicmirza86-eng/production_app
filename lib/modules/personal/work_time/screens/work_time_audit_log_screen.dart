import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Audit log — company_audit_logs, entityType work_time.
class WorkTimeAuditLogScreen extends StatelessWidget {
  const WorkTimeAuditLogScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dnevnik promjena')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          const ListTile(
            title: Text('Ažurirana su pravila noćnog rada'),
            subtitle: Text(
              'Korisnik: glavni administrator · 24. 4. 2026. 10:00 · promjena početka noći',
            ),
          ),
          const ListTile(
            title: Text('Dodan red u korekcijama (evidencija)'),
            subtitle: Text('Zapis: C-100 · mjenjane su ulaz/izlaz'),
          ),
        ],
      ),
    );
  }
}
