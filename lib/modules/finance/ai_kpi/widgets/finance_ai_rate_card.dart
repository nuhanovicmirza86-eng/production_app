import 'package:flutter/material.dart';

import '../models/finance_ai_recommendation_kpi_snapshot.dart';
import 'finance_ai_kpi_formatters.dart';

class FinanceAiRateCard extends StatelessWidget {
  const FinanceAiRateCard({
    super.key,
    required this.title,
    required this.metric,
    this.numeratorLabel,
    this.denominatorLabel,
    this.subtitle,
  });

  final String title;
  final FinanceAiKpiRateMetric metric;
  final String? numeratorLabel;
  final String? denominatorLabel;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRate = metric.rate != null;
    final percentText = FinanceAiKpiFormatters.percentOnly(context, metric);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              percentText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: hasRate ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasRate &&
                numeratorLabel != null &&
                denominatorLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                '${metric.numerator} $numeratorLabel / ${metric.denominator} $denominatorLabel',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
