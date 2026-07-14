import 'package:flutter/material.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../models/aps_optimization_comparison_view.dart' as comparison_model;

/// Usporedba početnog rasporeda i prijedloga optimizacije (P5.3).
class ApsOptimizationComparisonView extends StatelessWidget {
  const ApsOptimizationComparisonView({
    super.key,
    required this.comparison,
  });

  final comparison_model.ApsOptimizationComparisonView comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ApsGanttInfoCopy.optimizationComparisonTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (comparison.isImprovement)
                  Chip(
                    avatar: Icon(Icons.trending_down, size: 16, color: cs.primary),
                    label: const Text('Poboljšanje'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: cs.primaryContainer,
                  )
                else
                  Chip(
                    label: const Text('Bez poboljšanja'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _compareRow(
              theme,
              ApsGanttInfoCopy.optimizationBaselineLabel,
              comparison.baselineObjectiveScore.toStringAsFixed(1),
            ),
            _compareRow(
              theme,
              ApsGanttInfoCopy.optimizationProposalLabel,
              comparison.candidateObjectiveScore.toStringAsFixed(1),
            ),
            if (comparison.deltaObjectiveScore != null)
              _compareRow(
                theme,
                'Razlika ciljne vrijednosti',
                _signedNum(comparison.deltaObjectiveScore!),
                highlight: true,
              ),
            if (comparison.deltaMakespanMinutes != null)
              _compareRow(
                theme,
                'Razlika trajanja (min)',
                _signedInt(comparison.deltaMakespanMinutes!),
              ),
            if (comparison.operationsMovedCount != null)
              _compareRow(
                theme,
                'Pomjerene operacije',
                '${comparison.operationsMovedCount}',
              ),
            if (comparison.hardViolationCount != null &&
                comparison.hardViolationCount! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Upozorenje: ${comparison.hardViolationCount} kršenja ograničenja.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(
    ThemeData theme,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: highlight ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _signedNum(num v) {
    if (v > 0) return '+${v.toStringAsFixed(1)}';
    return v.toStringAsFixed(1);
  }

  String _signedInt(int v) {
    if (v > 0) return '+$v';
    return '$v';
  }
}
