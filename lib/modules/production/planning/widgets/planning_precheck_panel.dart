import 'package:flutter/material.dart';

import '../planning_session_controller.dart';
import '../planning_ui_formatters.dart';

/// Provjere prije generiranja + konflikti nakon motora.
class PlanningPrecheckPanel extends StatelessWidget {
  const PlanningPrecheckPanel({
    super.key,
    required this.session,
  });

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pool = session.pool;
    final result = session.result;
    final pre = <String>[];
    var noRouting = 0;
    var noInputLotBom = 0;
    for (final o in pool) {
      if ((o.machineId ?? '').trim().isEmpty) {
        pre.add('${o.productionOrderCode}: nema stroja (kandidat za plan ili ne).');
      }
      final due = o.requestedDeliveryDate;
      if (due != null && due.difference(DateTime.now()).inDays < 2) {
        pre.add('${o.productionOrderCode}: rizik roka <2 d.');
      }
      if (o.routingId.trim().isEmpty) {
        noRouting++;
      }
      if (o.bomId.trim().isNotEmpty) {
        final lot = o.inputMaterialLot?.trim() ?? '';
        if (lot.isEmpty) {
          noInputLotBom++;
        }
      }
    }
    if (noRouting > 0) {
      pre.add('Routings: $noRouting naloga nema routings — motor radi sintetički jedan korak po nalogu.');
    }
    if (noInputLotBom > 0) {
      pre.add('Lota ulaza (SK): $noInputLotBom naloga s BOM-om, bez unesenog lota — IATF sljedivost.');
    }
    if (result != null) {
      var toolMissing = 0;
      var opMissing = 0;
      for (final op in result.scheduledOperations) {
        if ((op.toolId ?? '').trim().isEmpty) {
          toolMissing++;
        }
        if (op.operatorIds.isEmpty) {
          opMissing++;
        }
      }
      if (toolMissing > 0) {
        pre.add('Alat: u $toolMissing zadanih operacija nije naveden alat (routings / ručno).');
      }
      if (opMissing > 0) {
        pre.add('Operater: u $opMissing operacija nema dodijeljenog operatera (kapacitetska priprema).');
      }
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text('Pre-check (stalno)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (pre.isEmpty)
          Text(
            'Nema očitih upozorenja (stroj, routing, rok, lot, alat, operater).',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          )
        else
          ...pre.take(18).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $s', style: const TextStyle(fontSize: 12)),
              )),
        if (pre.length > 18) Text('… +${pre.length - 18}', style: t.textTheme.labelSmall),
        const Divider(height: 20),
        Text('Motor (nakon generiranja)', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (result == null)
          Text(
            'Još nema pokretanja plana.',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          )
        else if (result.conflicts.isEmpty)
          const Text('Nema konflikata u zadnjem rezultatu.', style: TextStyle(fontSize: 12))
        else
          ...result.conflicts.take(16).map(
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
