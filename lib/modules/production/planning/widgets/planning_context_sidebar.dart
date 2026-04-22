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
  });

  final PlanningSessionController session;
  final VoidCallback? onOpenGanttFullscreen;
  final VoidCallback? onSaveDraft;

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
            if (session.result != null && session.result!.conflicts.isNotEmpty) ...[
              ...session.result!.conflicts.take(3).map(
                    (c) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.warning_amber_outlined, color: t.colorScheme.tertiary, size: 22),
                        title: Text(
                          PlanningUiFormatters.conflictTypeLabel(c.type.name),
                          style: t.textTheme.labelMedium,
                        ),
                        subtitle: Text(c.message, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
              Text(
                'Generativni LLM nije povezan — kartice su iz pravila motora. Kasnije: prijedlozi akcija.',
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
