import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_ai_alert.dart';
import 'finance_ai_severity_chip.dart';

class FinanceAiAlertCard extends StatelessWidget {
  const FinanceAiAlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    this.plantDisplayName,
  });

  final FinanceAiAlert alert;
  final VoidCallback onTap;
  final String? plantDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();
    final isHighPriority = alert.severity == 'critical' || alert.severity == 'high';
    final borderColor = isHighPriority
        ? cs.error.withValues(alpha: 0.45)
        : cs.outlineVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isHighPriority ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    alert.headline.isNotEmpty
                        ? alert.headline
                        : FinanceDisplayLabels.advisoryRuleId(
                            context,
                            alert.ruleId,
                          ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FinanceAiSeverityChip(severity: alert.severity, compact: true),
              ],
            ),
            if (alert.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                alert.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    FinanceDisplayLabels.advisoryStatus(context, alert.status),
                  ),
                ),
                Text(
                  FinanceStrings.t(context, 'advisory_confidence_label')
                      .replaceAll('{score}', alert.confidenceScore.toStringAsFixed(0)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              FinanceDisplayLabels.advisoryRuleId(context, alert.ruleId),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (alert.primaryRecommendation.title.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alert.primaryRecommendation.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              _detectedLine(context, df),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if ((plantDisplayName ?? alert.plantKey).toString().trim().isNotEmpty)
              Text(
                FinanceStrings.t(context, 'advisory_plant_scope')
                    .replaceAll('{plant}', plantDisplayName ?? alert.plantKey),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _detectedLine(BuildContext context, DateFormat df) {
    final first = alert.firstDetectedAt;
    final last = alert.lastDetectedAt ?? alert.triggeredAt;
    final firstS = first != null ? df.format(first.toLocal()) : '—';
    final lastS = last != null ? df.format(last.toLocal()) : '—';
    return FinanceStrings.t(context, 'advisory_detected_range')
        .replaceAll('{first}', firstS)
        .replaceAll('{last}', lastS);
  }
}
