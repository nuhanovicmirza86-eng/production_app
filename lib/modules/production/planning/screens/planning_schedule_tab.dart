import 'package:flutter/material.dart';

import '../planning_workflow_scope.dart';
import '../widgets/planning_fcs_reoptimize.dart';
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
            runSpacing: 6,
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
                        planningSession: session,
                      ),
                    ),
                  );
                },
                child: const Text('Gantt (nova ruta)'),
              ),
              Tooltip(
                message: 'Ponovno pokreće motor (FCS) s parametrima iz taba Nalozi. Ako ste ručno pomicali Gantt, ta pomicanja se gube.',
                child: FilledButton.icon(
                  onPressed: session.isLocked
                      ? null
                      : () => reoptimizeFcsWithOptionalDialog(context, session),
                  icon: const Icon(Icons.auto_mode, size: 18),
                  label: const Text('Ponovno uklopi (FCS)'),
                ),
              ),
            ],
          ),
        ),
        if (session.ganttMachineOverlapMessages.isNotEmpty) ...[
          Builder(
            builder: (context) {
              final msgs = session.ganttMachineOverlapMessages;
              const cap = 5;
              final shown = msgs.length <= cap ? msgs : msgs.sublist(0, cap);
              final more = msgs.length > cap ? ' (+${msgs.length - cap} još)' : '';
              final t = shown.length == 1
                  ? shown.first
                  : 'Preklapanja: ${shown.join(' · ')}$more';
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
              onOperationTimeNudge: session.isLocked
                  ? null
                  : session.nudgeScheduledOperationById,
              overlappingOperationIds: session.overlappingScheduledOperationIds,
            ),
          ),
        ),
      ],
    );
  }
}
