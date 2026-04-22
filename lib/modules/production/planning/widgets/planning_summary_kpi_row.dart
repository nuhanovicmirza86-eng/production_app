import 'package:flutter/material.dart';

import '../planning_session_controller.dart';

class PlanningSummaryKpiRow extends StatelessWidget {
  const PlanningSummaryKpiRow({super.key, required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final r = session.result;
    final k = r?.kpi;
    final u01 = r?.plan.estimatedUtilization01;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          _chip(context, 'Odabrano', '${session.selectedOrderIds.length}'),
          _chip(context, 'Mogući (motor)', k != null ? '${k.feasibleOrders}' : '—'),
          _chip(context, 'Rizik (rok)', '${session.countRiskOrders()}'),
          _chip(context, 'Nemogući', k != null ? '${k.infeasibleOrders}' : '—'),
          _chip(
            context,
            'Gruba iskor.',
            u01 != null ? '${(u01 * 100).toStringAsFixed(0)}%' : '—',
          ),
          _chip(
            context,
            'Zbir kašnjenja (min)',
            k != null && k.totalLatenessMinutes > 0 ? '${k.totalLatenessMinutes}' : '0',
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String l, String v) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$l: ',
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              Text(v, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
