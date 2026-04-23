import 'package:flutter/material.dart';

import '../../tracking/screens/production_operator_tracking_screen.dart';
import '../planning_workflow_scope.dart';
import '../widgets/planning_execution_shift_board.dart';
import '../widgets/planning_variance_panel.dart';

/// Tab **Provedba**: plan vs stvarno, smjenska tabla — postupno povezivanje s MES.
class ProductionPlanExecutionScreen extends StatelessWidget {
  const ProductionPlanExecutionScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  Widget build(BuildContext context) {
    final session = PlanningWorkflowScope.of(context);
    final t = Theme.of(context);
    final r = session.result;
    final bid = r?.kpi?.bottleneckMachineId?.trim();
    final hasBottleneck = bid != null && bid.isNotEmpty;
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
        Text('Operativni sažetak (iz zadnjeg plana)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: r == null
                ? Text(
                    'Nema učitana plana — generirajte plan u zaglavlju.',
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasBottleneck) ...[
                        Text(
                          'Usko grlo (najdulje iskorištenje u ovom potezanju):',
                          style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.poolMachineLabel(bid),
                          style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (session.ganttMachineOverlapMessages.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.layers_clear, size: 20, color: t.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Preklapanja na Gantt strojevima: ${session.ganttMachineOverlapMessages.length} upozorenje/a. '
                                'Tab Raspored — oštrica na blokovima, legenda, ili FCS ponovno uklopi.',
                                style: t.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Nema detektiranog preklapanja u Gantt vremenima nakon zadnjeg generiranja.',
                          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Smjenska tabla (plan)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Sve operacije u planu po stroju (sortirano po vremenu). „Stvarno (nalog)“: kumulativno s naloga. „Danas (MES, stroj)“: zbroj polja dobro iz execution zapisa za taj stroj i nalog u lokalnom danu.',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton.icon(
              onPressed: session.isLocked ? null : session.bumpMesBoardRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Osvježi MES'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PlanningExecutionShiftBoard(session: session),
          ),
        ),
        const SizedBox(height: 12),
        Text('Varijanca i uzrok (Faza 3 — closed loop)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Planirani početak vs zadnji MES startedAt na istom stroju; uzrok i bilješka u `execution_variances` nakon što je nacrt spremljen. „Ponovno uklopi“ = assisted replan (FCS), ne auto-global.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PlanningVariancePanel(session: session),
          ),
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
