import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

import '../../execution/services/production_execution_service.dart';
import '../planning_root_cause_codes.dart';
import '../planning_session_controller.dart';
import 'planning_fcs_reoptimize.dart';

/// Faza 3: plan vs stvarno (MES) + uzrok; trajni zapis u `execution_variances` (Callable).
class PlanningVariancePanel extends StatefulWidget {
  const PlanningVariancePanel({super.key, required this.session});

  final PlanningSessionController session;

  @override
  State<PlanningVariancePanel> createState() => _PlanningVariancePanelState();
}

class _PlanningVariancePanelState extends State<PlanningVariancePanel> {
  static final _exec = ProductionExecutionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_reload());
    });
  }

  @override
  void didUpdateWidget(PlanningVariancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.lastSavedPlanId != widget.session.lastSavedPlanId) {
      unawaited(_reload());
    }
  }

  Future<void> _reload() async {
    await widget.session.loadExecutionVariancesForSavedPlan();
    if (mounted) {
      setState(() {});
    }
  }

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}. ${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static DateTime? _mesLatestStart(
    List<Map<String, dynamic>> list,
    String machineId,
  ) {
    final mid = machineId.trim();
    if (mid.isEmpty) {
      return null;
    }
    DateTime? best;
    for (final m in list) {
      if ((m['machineId'] ?? '').toString().trim() != mid) {
        continue;
      }
      final s = m['startedAt'];
      if (s is! Timestamp) {
        continue;
      }
      final t = s.toDate();
      final b = best;
      if (b == null || t.isAfter(b)) {
        best = t;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = widget.session;
    final r = s.result;
    if (r == null || r.scheduledOperations.isEmpty) {
      return Text(
        'Nema zadnjeg plana s operacijama — generirajte (tab Nalozi).',
        style: t.textTheme.bodySmall?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final ids = r.scheduledOperations.map((e) => e.productionOrderId).toSet();
    final canPersist =
        s.lastSavedPlanId != null && s.lastSavedPlanId!.isNotEmpty;
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _exec.getExecutionsByOrderIds(
        companyId: s.companyId,
        plantKey: s.plantKey,
        productionOrderIds: ids,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Text(
            'MES: ${snap.error}',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.error),
          );
        }
        final mes = snap.data ?? {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canPersist)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nacrt nije u bazi. Spremite nacrt plana, zatim možete uskladiti uzroke (pohranjuju se na poslužitelju).',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.tertiary,
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('Nalog')),
                  DataColumn(label: Text('Stroj')),
                  DataColumn(label: Text('Plan poč.')),
                  DataColumn(label: Text('Stvar. poč. (MES)')),
                  DataColumn(label: Text('Δ poč.')),
                  DataColumn(label: Text('Uzrok')),
                  DataColumn(label: Text('Bilješka')),
                ],
                rows: r.scheduledOperations.map((op) {
                  final list =
                      mes[op.productionOrderId] ??
                      const <Map<String, dynamic>>[];
                  final actualStart = _mesLatestStart(list, op.machineId);
                  final dMin = actualStart
                      ?.difference(op.plannedStart)
                      .inMinutes;
                  final dStr = dMin == null ? '—' : '$dMin min';
                  final key = op.id;
                  var root = s.getExecutionVarianceRootDraft(key) ?? 'unknown';
                  if (!planningRootCauseCodeLabels.containsKey(root)) {
                    root = 'unknown';
                  }
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(s.engineOrderCode(r, op.productionOrderId)),
                      ),
                      DataCell(Text(s.poolMachineLabel(op.machineId))),
                      DataCell(Text(_fmt(op.plannedStart))),
                      DataCell(
                        Text(actualStart == null ? '—' : _fmt(actualStart)),
                      ),
                      DataCell(Text(dStr)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: root,
                            items: [
                              for (final k in planningRootCauseCodeKeys)
                                DropdownMenuItem(
                                  value: k,
                                  child: Text(
                                    planningRootCauseCodeLabels[k] ?? k,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: s.isLocked
                                ? null
                                : (v) {
                                    if (v == null) {
                                      return;
                                    }
                                    s.setExecutionVarianceDraft(
                                      key,
                                      rootCauseCode: v,
                                      notes: s.getExecutionVarianceNotesDraft(
                                        key,
                                      ),
                                    );
                                    setState(() {});
                                  },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            key: ValueKey('vn-$key'),
                            initialValue:
                                s.getExecutionVarianceNotesDraft(key) ?? '',
                            enabled: !s.isLocked,
                            maxLines: 1,
                            decoration: const InputDecoration(),
                            onChanged: (v) {
                              s.setExecutionVarianceDraft(
                                key,
                                rootCauseCode: root,
                                notes: v,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.tonal(
                  onPressed:
                      s.isLocked ||
                          s.persistingExecutionVariances ||
                          !canPersist
                      ? null
                      : () async {
                          await s.persistAllExecutionVariancesToFirestore();
                          if (!context.mounted) {
                            return;
                          }
                          if (s.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.errorMessage!)),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Varijance / uzroci spremljeni.'),
                              ),
                            );
                          }
                          setState(() {});
                        },
                  child: s.persistingExecutionVariances
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Spremi uzroke'),
                ),
                OutlinedButton.icon(
                  onPressed: s.isLocked
                      ? null
                      : () => reoptimizeFcsWithOptionalDialog(context, s),
                  icon: const Icon(Icons.auto_mode, size: 18),
                  label: const Text('Pomoć: ponovno uklopi (FCS)'),
                ),
                TextButton(
                  onPressed: s.isLocked ? null : _reload,
                  child: const Text('Osvježi MES / uzroke'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
