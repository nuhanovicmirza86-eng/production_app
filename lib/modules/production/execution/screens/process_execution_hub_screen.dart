import 'package:flutter/material.dart';

import '../../../auth/shared/services/auth_service.dart';
import '../../processes/screens/production_processes_list_screen.dart';
import '../../production_orders/screens/production_orders_list_screen.dart';
import '../../tracking/screens/production_operator_tracking_screen.dart';

/// Ulaz za **evidenciju procesa**: master procesi, nalozi (routing / izvršenje), operativno praćenje.
///
/// Zamjenjuje placeholder „Uskoro”; ne uvodi novi backend — grupira postojeće MES tokove.
class ProcessExecutionHubScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ProcessExecutionHubScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidencija procesa'),
        actions: [
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: () async => AuthService().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Procesi u šifrarniku, vezani nalozi i operativni unos moraju biti dosljedni '
            '(IATF, interni audit). Odaberi sljedeći korak prema ulozi.',
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Proizvodni procesi'),
              subtitle: const Text(
                'Master šifarnik — tip, status, IATF, QC obavezan, sljedljivost.',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProductionProcessesListScreen(companyData: companyData),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Proizvodni nalozi'),
              subtitle: const Text(
                'Lista naloga → detalji → routing i izvršenje koraka na radnom mjestu.',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProductionOrdersListScreen(companyData: companyData),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Praćenje proizvodnje'),
              subtitle: const Text(
                'Tabovi za pripremu, kontrolu i završetak — KPI i unos po fazama.',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProductionOperatorTrackingScreen(
                      companyData: companyData,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
