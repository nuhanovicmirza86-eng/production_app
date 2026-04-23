import 'package:flutter/material.dart';

import '../planning_session_controller.dart';
import '../planning_ui_formatters.dart';
import 'planning_kpi_strip.dart';

/// Zajednički desni stupac: odabrani nalog, sažetak upozorenja, placeholder za AI uvid.
class PlanningContextSidebar extends StatelessWidget {
  const PlanningContextSidebar({
    super.key,
    required this.session,
    required this.onOpenGanttFullscreen,
    required this.onSaveDraft,
    this.onReoptimizeFcs,
  });

  final PlanningSessionController session;
  final VoidCallback? onOpenGanttFullscreen;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onReoptimizeFcs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, minWidth: 280),
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Text(
              'Kontekst / detalj',
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (session.selectedOrder == null)
              Text(
                'Odaberite nalog (tab Nalozi).',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              )
            else ...[
              _line(t, 'Nalog', session.selectedOrder!.productionOrderCode),
              _line(t, 'Proizvod', session.selectedOrder!.productName),
              _line(
                t,
                'Preostalo',
                '${(session.selectedOrder!.plannedQty - session.selectedOrder!.producedGoodQty).clamp(0.0, double.infinity).toStringAsFixed(1)} ${session.selectedOrder!.unit}',
              ),
            ],
            const Divider(height: 20),
            Text('Uvid (motor / LLM)', style: t.textTheme.labelLarge),
            const SizedBox(height: 4),
            if (session.result != null && session.visibleEngineConflicts.isNotEmpty) ...[
              ...session.visibleEngineConflicts.take(3).map(
                    (c) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 10, right: 4),
                            leading: Icon(Icons.warning_amber_outlined, color: t.colorScheme.tertiary, size: 22),
                            title: Text(
                              PlanningUiFormatters.conflictTypeLabel(c.type.name),
                              style: t.textTheme.labelMedium,
                            ),
                            subtitle: Text(c.message, style: const TextStyle(fontSize: 12)),
                            trailing: session.isLocked
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    tooltip: 'Zanemari (ovaj ciklus)',
                                    onPressed: () => session.dismissEngineConflict(c),
                                  ),
                          ),
                          if (!session.isLocked)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      session.setScenarioIndex(1);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Primijenjeno: Scenarij Simulacija — tab Nalozi → Generiši plan.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Primijeni'),
                                  ),
                                  TextButton(
                                    onPressed: () => session.dismissEngineConflict(c),
                                    child: const Text('Zanemari'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              if (!session.isLocked && session.visibleEngineConflicts.length > 1)
                TextButton(
                  onPressed: () {
                    for (final c in List.of(session.visibleEngineConflicts)) {
                      session.dismissEngineConflict(c);
                    }
                  },
                  child: const Text('Zanemari sva vidljiva upozorenja'),
                ),
              if (!session.isLocked) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        session.setScenarioIndex(1);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Scenarij: Simulacija. Na tabu Nalozi podesite parametre pa Generiši plan.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Simulacija (scenarij)'),
                    ),
                    if (onReoptimizeFcs != null)
                      FilledButton.tonal(
                        onPressed: onReoptimizeFcs,
                        child: const Text('FCS ponovno uklopi'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                'Generativni LLM nije povezan — gumbi su lokalne akcije (scenarij / uklanjanje / FCS) iz motora.',
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ] else
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline, color: t.colorScheme.primary, size: 20),
                  title: const Text('Nema upozorenja u zadnjem planu'),
                  subtitle: const Text('Generirajte plan ili provjerite tab Nalozi. LLM nije uključen.'),
                  isThreeLine: true,
                ),
              ),
            if (session.result != null) ...[
              const Divider(height: 16),
              PlanningKpiStrip(
                r: session.result!,
                companyId: session.companyId,
                plantKey: session.plantKey,
                compact: false,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: session.isLocked ? null : onOpenGanttFullscreen,
                  child: const Text('Gantt cijeli ekran'),
                ),
                FilledButton.tonal(
                  onPressed: session.isLocked || session.result == null ? null : onSaveDraft,
                  child: const Text('Spremi nacrt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _line(ThemeData t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$k: $v',
        style: t.textTheme.bodySmall,
      ),
    );
  }
}
