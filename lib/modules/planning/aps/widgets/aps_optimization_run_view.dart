import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../models/aps_optimization_run_view.dart' as run_model;

/// Detalj jednog prijedloga optimizacije (P5.3).
class ApsOptimizationRunDetailView extends StatelessWidget {
  const ApsOptimizationRunDetailView({
    super.key,
    required this.run,
    this.objectiveProfileLabel,
  });

  final run_model.ApsOptimizationRunView run;
  final String? objectiveProfileLabel;

  static final _dateTimeFmt = DateFormat('d.M.yyyy. HH:mm');

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
                    ApsGanttInfoCopy.optimizationRunDetailTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    run.statusLabel,
                    style: theme.textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _statusColor(cs, run.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(theme, 'Identifikator', _shortId(run.id)),
            if (objectiveProfileLabel != null &&
                objectiveProfileLabel!.trim().isNotEmpty)
              _row(theme, ApsGanttInfoCopy.optimizationGoalLabel,
                  objectiveProfileLabel!),
            if (run.startedAt != null)
              _row(
                theme,
                'Pokrenuto',
                _dateTimeFmt.format(run.startedAt!),
              ),
            if (run.completedAt != null)
              _row(
                theme,
                'Završeno',
                _dateTimeFmt.format(run.completedAt!),
              ),
            if (run.baselineObjectiveScore != null)
              _row(
                theme,
                ApsGanttInfoCopy.optimizationBaselineScoreLabel,
                run.baselineObjectiveScore!.toStringAsFixed(1),
              ),
            if (run.objectiveScore != null)
              _row(
                theme,
                ApsGanttInfoCopy.optimizationProposalScoreLabel,
                run.objectiveScore!.toStringAsFixed(1),
              ),
            if (run.isFailed && run.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  run.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Color? _statusColor(ColorScheme cs, String status) {
    switch (status) {
      case 'completed':
        return cs.primaryContainer;
      case 'applied':
        return cs.tertiaryContainer;
      case 'discarded':
        return cs.surfaceContainerHighest;
      case 'failed':
      case 'infeasible':
        return cs.errorContainer;
      default:
        return cs.surfaceContainerHighest;
    }
  }

  String _shortId(String id) {
    final t = id.trim();
    if (t.length <= 14) return t;
    return '${t.substring(0, 8)}…${t.substring(t.length - 4)}';
  }
}
