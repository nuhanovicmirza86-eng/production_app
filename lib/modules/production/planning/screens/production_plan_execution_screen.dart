import 'package:flutter/material.dart';

import '../../tracking/screens/production_operator_tracking_screen.dart';
import '../planning_workflow_scope.dart';

/// Tab **Provedba**: plan vs stvarno, smjenska tabla — postupno povezivanje s MES.
class ProductionPlanExecutionScreen extends StatelessWidget {
  const ProductionPlanExecutionScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    final session = PlanningWorkflowScope.of(context);
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('KPI (iz plana / MES)', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _kpiCard(context, 'Aktivni nalozi (plan)', session.result != null ? '${session.result!.plan.items.length}' : '—'),
            _kpiCard(context, 'Operacija u planu', session.result != null ? '${session.result!.scheduledOperations.length}' : '—'),
            _kpiCard(context, 'Konflikti / upozorenja', session.result != null ? '${session.result!.conflicts.length}' : '—'),
            _kpiCard(context, 'Plan adherence', '— (MES)'),
          ],
        ),
        const Divider(height: 28),
        Text('Smjenska tabla (planirano)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Ovdje dolazi red–red: stroj, trenutni nalog, planirana količina smjene, stvarno, delta, zastoj, sljedeći nalog, rizik. '
          'Podaci se povezuju s unosima iz modula Praćenje i stvarnim stanjem resursa.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text('Varijanca / uzrok (placeholder)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Planirani vs stvarni početak/kraj, ciklus, setup, scrap — prema istom nalogu i operaciji.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProductionOperatorTrackingScreen(companyData: companyData),
              ),
            );
          },
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Operativno praćenje (smjena)'),
        ),
      ],
    );
  }

  Widget _kpiCard(BuildContext context, String title, String value) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
