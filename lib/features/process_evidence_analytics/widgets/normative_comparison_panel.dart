import 'package:flutter/material.dart';

import '../models/normative_comparison_models.dart';
import '../models/process_evidence_analytics_models.dart';

class NormativeComparisonPanel extends StatelessWidget {
  const NormativeComparisonPanel({
    super.key,
    required this.comparison,
  });

  final NormativeComparisonData comparison;

  Color _statusColor(ColorScheme cs) {
    switch (comparison.normativeStatus) {
      case 'within_norm':
        return cs.primary;
      case 'below_speed_norm':
      case 'above_scrap_norm':
        return cs.tertiary;
      case 'mixed_warning':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final statusColor = _statusColor(cs);

    return Card(
      margin: EdgeInsets.zero,
      color: comparison.normativeReady
          ? cs.primaryContainer.withValues(alpha: 0.25)
          : cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  comparison.normativeReady
                      ? Icons.rule_outlined
                      : Icons.rule_folder_outlined,
                  size: 20,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comparison.headlineMessage,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(comparison.statusLabel),
                        side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                        labelStyle: TextStyle(color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comparison.normativeReady) ...[
              const SizedBox(height: 12),
              Text(
                comparison.matchedNormLabel,
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((comparison.normGroupId ?? '').isNotEmpty)
                Text(
                  'Grupa verzija · v${comparison.normVersion ?? '—'}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricTile(
                    context,
                    'Cilj kom/sat',
                    formatAnalyticsNumber(comparison.targetPiecesPerHour),
                  ),
                  _metricTile(
                    context,
                    'Stvarno kom/sat',
                    formatAnalyticsNumber(comparison.actualPiecesPerHour),
                  ),
                  _metricTile(
                    context,
                    'Std. min/kom',
                    formatAnalyticsNumber(comparison.standardMinutesPerPiece),
                  ),
                  _metricTile(
                    context,
                    'Stvarno min/kom',
                    formatAnalyticsNumber(comparison.actualMinutesPerPiece),
                  ),
                  _metricTile(
                    context,
                    'Dopušteni škart %',
                    formatAnalyticsPercent(comparison.allowedScrapRate),
                  ),
                  _metricTile(
                    context,
                    'Stvarni škart %',
                    formatAnalyticsPercent(comparison.actualScrapRate),
                  ),
                  _metricTile(
                    context,
                    'Varijacija brzine',
                    formatVariancePercent(comparison.speedVariancePercent),
                  ),
                  _metricTile(
                    context,
                    'Varijacija škarta',
                    formatVariancePoints(comparison.scrapVariancePercent),
                  ),
                  _metricTile(
                    context,
                    'U toleranciji brzine',
                    formatToleranceLabel(comparison.withinSpeedTolerance),
                  ),
                  _metricTile(
                    context,
                    'U toleranciji škarta',
                    formatToleranceLabel(comparison.withinScrapTolerance),
                  ),
                  _metricTile(
                    context,
                    'Težina operacije',
                    normativeDifficultyLabel(comparison.difficulty),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricTile(BuildContext context, String label, String value) {
    final t = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
