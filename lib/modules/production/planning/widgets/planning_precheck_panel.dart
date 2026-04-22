import 'package:flutter/material.dart';

import '../../production_orders/models/production_order_model.dart';
import '../models/planning_engine_result.dart';
import '../planning_ui_formatters.dart';

/// Provjere prije generiranja + konflikti nakon motora.
class PlanningPrecheckPanel extends StatelessWidget {
  const PlanningPrecheckPanel({
    super.key,
    required this.pool,
    required this.result,
  });

  final List<ProductionOrderModel> pool;
  final PlanningEngineResult? result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pre = <String>[];
    for (final o in pool) {
      if ((o.machineId ?? '').trim().isEmpty) {
        pre.add('${o.productionOrderCode}: nema stroja (kandidat za plan ili ne).');
      }
      final due = o.requestedDeliveryDate;
      if (due != null && due.difference(DateTime.now()).inDays < 2) {
        pre.add('${o.productionOrderCode}: rizik roka <2 d.');
      }
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text('Pre-check (stalno)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (pre.isEmpty)
          Text(
            'Nema očitih blokatora na nivou naloga (stroj/routing/ro).',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          )
        else
          ...pre.take(12).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $s', style: const TextStyle(fontSize: 12)),
              )),
        if (pre.length > 12)
          Text('… +${pre.length - 12}', style: t.textTheme.labelSmall),
        const Divider(height: 20),
        Text('Motor (nakon generiranja)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (result == null)
          Text(
            'Još nema pokretanja plana.',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          )
        else if (result!.conflicts.isEmpty)
          const Text('Nema konflikata u zadnjem rezultatu.', style: TextStyle(fontSize: 12))
        else
          ...result!.conflicts.take(16).map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${PlanningUiFormatters.conflictTypeLabel(c.type.name)}: ${c.message}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
      ],
    );
  }
}
