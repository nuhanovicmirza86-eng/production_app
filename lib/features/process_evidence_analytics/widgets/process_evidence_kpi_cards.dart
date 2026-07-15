import 'package:flutter/material.dart';

import '../models/process_evidence_analytics_models.dart';

class ProcessEvidenceKpiCards extends StatelessWidget {
  const ProcessEvidenceKpiCards({
    super.key,
    required this.summary,
    this.truncated = false,
    this.normativeComparisonNote,
  });

  final ProcessEvidenceAnalyticsSummary summary;
  final bool truncated;
  final String? normativeComparisonNote;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final materialText = summary.materialConsumption.isEmpty
        ? '—'
        : summary.materialConsumption
              .take(4)
              .map((m) {
                final name = (m.materialName ?? m.materialType ?? 'Materijal')
                    .trim();
                final qty = formatAnalyticsNumber(m.quantity, fractionDigits: 2);
                final unit = (m.unit ?? '').trim();
                return unit.isEmpty ? '$name: $qty' : '$name: $qty $unit';
              })
              .join('\n');

    final sourceLabels = summary.activitySourcesIncluded
        .map(formatActivitySourceLabel)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _KpiCard(
              label: 'Broj evidencija',
              value: '${summary.evidenceCount}',
              icon: Icons.fact_check_outlined,
            ),
            _KpiCard(
              label: 'Ukupno obrađeno',
              value: formatAnalyticsNumber(summary.processedTotalQty),
              icon: Icons.inventory_2_outlined,
            ),
            _KpiCard(
              label: 'OK količina',
              value: formatAnalyticsNumber(summary.okTotalQty),
              icon: Icons.check_circle_outline,
            ),
            _KpiCard(
              label: 'Škart',
              value: formatAnalyticsNumber(summary.scrapTotalQty),
              icon: Icons.warning_amber_outlined,
            ),
            _KpiCard(
              label: 'Ponovna dorada',
              value: formatAnalyticsNumber(summary.reworkAgainTotalQty),
              icon: Icons.replay_outlined,
            ),
            _KpiCard(
              label: 'Utrošeno vrijeme',
              value: formatDurationMinutes(summary.durationMinutesTotal),
              icon: Icons.schedule_outlined,
            ),
            _KpiCard(
              label: 'Komada/sat',
              value: formatAnalyticsNumber(summary.averagePiecesPerHour),
              icon: Icons.speed_outlined,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.construction_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Utrošak materijala',
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  materialText,
                  style: t.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status izvora podataka',
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Izvori: ${sourceLabels.isEmpty ? '—' : sourceLabels}',
                  style: t.textTheme.bodyMedium,
                ),
                Text(
                  'Normativi: ${summary.normativeReady ? 'povezani' : 'nisu još povezani (M2-F1)'}',
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: summary.normativeReady
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                ),
                if ((normativeComparisonNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    normativeComparisonNote!,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
                if (truncated) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rezultat je skraćen na maksimalan broj sesija u periodu.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: cs.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: 170,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: t.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: t.textTheme.labelMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
