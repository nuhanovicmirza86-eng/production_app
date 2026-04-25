import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';

/// Dodjela radnika managerima — manager_employee_access (samo Admin).
class WorkTimeManagerAssignmentScreen extends StatelessWidget {
  const WorkTimeManagerAssignmentScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodjela radnika managerima')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Ovdje se određuje tko u kojem timu vidi koje zaposlenike (pogon, odjel, smjene).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const ListTile(
            title: Text('Voditelj proizvodnje A'),
            subtitle: Text('Pogon I — dnevna i noćna smjena'),
          ),
        ],
      ),
    );
  }
}
