import 'package:flutter/material.dart';

import '../models/teep_summary.dart';
import '../ooe_help_texts.dart';
import 'ooe_info_icon.dart';

/// Jedna kartica koja **hijerarhijski** objašnjava OEE / OOE / TEEP (ne tri „istovjetna“ %).
///
/// Ako je [summary] zadan, prikazuje i brojeve iz backend agregata.
class OeeOoeTeepHierarchyCard extends StatelessWidget {
  const OeeOoeTeepHierarchyCard({super.key, this.summary});

  final TeepSummary? summary;

  static String _pct(double x) => '${(x * 100).toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = summary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'OEE · OOE · TEEP',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                OoeInfoIcon(
                  tooltip: OoeHelpTexts.teepHierarchyTooltip,
                  dialogTitle: OoeHelpTexts.teepHierarchyTitle,
                  dialogBody: OoeHelpTexts.teepHierarchyBody,
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Različite baze vremena — ne uspoređuj brojke bez konteksta.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _kpiRow(
              context,
              label: 'OEE',
              subtitle: 'u planiranom vremenu proizvodnje',
              value: s == null ? null : _pct(s.oee),
              color: cs.primary,
            ),
            const SizedBox(height: 8),
            _kpiRow(
              context,
              label: 'OOE',
              subtitle: 'u operativnom vremenu',
              value: s == null ? null : _pct(s.ooe),
              color: cs.secondary,
            ),
            const SizedBox(height: 8),
            _kpiRow(
              context,
              label: 'TEEP',
              subtitle: 'u punom kalendarskom vremenu · TEEP = OEE × Utilization',
              value: s == null ? null : _pct(s.teep),
              color: cs.tertiary,
            ),
            if (s != null) ...[
              const Divider(height: 20),
              Text(
                'Iskorištenje kalendara (Utilization): ${_pct(s.utilization)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpiRow(
    BuildContext context, {
    required String label,
    required String subtitle,
    required String? value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (value != null)
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                )
              else
                Text(
                  '— (sažetak još nije na serveru)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
