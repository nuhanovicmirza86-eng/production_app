import 'package:flutter/material.dart';

import '../../ooe/screens/capacity_overview_screen.dart';
import '../../ooe/screens/teep_analysis_screen.dart';
import '../../ooe/widgets/oee_ooe_teep_hierarchy_card.dart';
import '../planning_workflow_scope.dart';

/// Tab **Kapacitet**: opterećenje, bottleneck, OEE / OOE / TEEP — jasno odvojeno.
class ProductionCapacityOverviewScreen extends StatelessWidget {
  const ProductionCapacityOverviewScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    final session = PlanningWorkflowScope.of(context);
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Poveznica s planom', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Zadnji plan: ${session.result?.plan.planCode ?? "—"} · operacija u horizontu: '
          '${session.result?.scheduledOperations.length ?? 0}',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        const OeeOoeTeepHierarchyCard(),
        const SizedBox(height: 16),
        Text('Brze akcije', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CapacityOverviewScreen(companyData: companyData),
                  ),
                );
              },
              child: const Text('Kalendar kapaciteta (puni ekran)'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TeepAnalysisScreen(companyData: companyData),
                  ),
                );
              },
              child: const Text('TEEP analiza'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Bottleneck (iz motora, ako postoji nacrt)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (session.result != null && (session.result!.kpi?.bottleneckMachineId ?? '').isNotEmpty)
          const Text(
            'Bottleneck resurs vidi se u KPI traci (naziv stroja iz šifrarnika), ne sirovi identifikator.',
            style: TextStyle(fontSize: 13),
          )
        else
          Text('Pokrenite generiranje plana u tabu Nalozi.', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text(
          'Alat / operator / materijal po resursu — proširenjem modela; vidi OOE modul i arhitekturu planiranja.',
          style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
