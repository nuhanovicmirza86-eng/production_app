import 'package:flutter/material.dart';

import '../models/scheduled_operation.dart';
import '../planning_session_controller.dart';

/// Smjenska tabla (plan): po stroju prva operacija u planu; stvarno — kada MES poveže podatke.
class PlanningExecutionShiftBoard extends StatelessWidget {
  const PlanningExecutionShiftBoard({super.key, required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = session.result;
    if (r == null) {
      return Text(
        'Nema generiranog plana — tab Nalozi → Generiši plan.',
        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
      );
    }
    if (r.scheduledOperations.isEmpty) {
      return Text(
        'Nema zakazanih operacija u zadnjem rezultatu.',
        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
      );
    }

    final orderCodes = <String, String>{};
    for (final it in r.plan.items) {
      final c = (it.productionOrderCode ?? '').trim();
      orderCodes[it.productionOrderId] = c.isEmpty ? '—' : c;
    }

    final byMachine = <String, List<ScheduledOperation>>{};
    for (final op in r.scheduledOperations) {
      byMachine.putIfAbsent(op.machineId, () => []).add(op);
    }
    for (final list in byMachine.values) {
      list.sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
    }

    String labelFor(String id) {
      if (id.isEmpty) return 'Nije dodijeljen stroj';
      return session.ganttMachineLabels[id] ?? '…';
    }

    final machineKeys = byMachine.keys.toList()
      ..sort((a, b) => labelFor(a).compareTo(labelFor(b)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        columns: const [
          DataColumn(label: Text('Stroj')),
          DataColumn(label: Text('Nalog')),
          DataColumn(label: Text('Plan poč.')),
          DataColumn(label: Text('Plan kraj')),
          DataColumn(label: Text('Stvarno')),
          DataColumn(label: Text('Status (plan)')),
        ],
        rows: machineKeys.map((mk) {
          final op = byMachine[mk]!.first;
          return DataRow(
            cells: [
              DataCell(Text(labelFor(mk))),
              DataCell(Text(orderCodes[op.productionOrderId] ?? '—')),
              DataCell(Text(_fmtDt(op.plannedStart))),
              DataCell(Text(_fmtDt(op.plannedEnd))),
              const DataCell(Text('—')),
              DataCell(Text(_statusHr(op.status))),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _statusHr(String s) {
    switch (s) {
      case 'planned':
        return 'planirano';
      case 'running':
        return 'u toku';
      case 'done':
      case 'completed':
        return 'završeno';
      default:
        return s;
    }
  }

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}. '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
