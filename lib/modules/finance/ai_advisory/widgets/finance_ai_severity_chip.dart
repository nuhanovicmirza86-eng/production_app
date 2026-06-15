import 'package:flutter/material.dart';

import '../../shared/finance_display_labels.dart';

class FinanceAiSeverityChip extends StatelessWidget {
  const FinanceAiSeverityChip({
    super.key,
    required this.severity,
    this.compact = false,
  });

  final String severity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = FinanceDisplayLabels.advisorySeverity(context, severity);
    final color = _colorForSeverity(severity, cs);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _colorForSeverity(String severity, ColorScheme cs) {
    switch (severity.trim().toLowerCase()) {
      case 'critical':
        return cs.error;
      case 'high':
        return cs.error.withValues(alpha: 0.85);
      case 'medium':
        return cs.tertiary;
      case 'info':
      default:
        return cs.primary;
    }
  }
}
