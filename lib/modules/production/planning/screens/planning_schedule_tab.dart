import 'package:flutter/material.dart';

import '../planning_workflow_scope.dart';
import 'production_plan_gantt_screen.dart';

/// Tab **Raspored**: Gantt iz zadnjeg rezultata + poveznica na puni ekran.
class PlanningScheduleTab extends StatelessWidget {
  const PlanningScheduleTab({super.key, required this.companyData, required this.onOpenFullscreen});

  final Map<String, dynamic> companyData;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final session = PlanningWorkflowScope.of(context);
    final d = session.ganttDto;
    if (session.result == null || d == null || d.operations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            session.result == null
                ? 'Generirajte plan u tabu Nalozi (gumb Generiši plan).'
                : 'Nema zakazanih operacija (npr. svi odbačeni).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    if (session.ganttLabelForResultId != session.result?.plan.id) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: session.isLocked ? null : onOpenFullscreen,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Cijeli ekran'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProductionPlanGanttScreen(
                        companyData: companyData,
                        gantt: d,
                      ),
                    ),
                  );
                },
                child: const Text('Gantt (nova ruta)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(6),
            clipBehavior: Clip.antiAlias,
            child: PlanningGanttChart(
              data: d,
              machineLabels: session.ganttMachineLabels,
              showNowLine: true,
              preferenceCompanyId: session.companyId,
              preferencePlantKey: session.plantKey,
            ),
          ),
        ),
      ],
    );
  }
}
