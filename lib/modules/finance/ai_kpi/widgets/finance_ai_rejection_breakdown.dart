import 'package:flutter/material.dart';

import '../../shared/finance_strings.dart';
import '../models/finance_ai_recommendation_kpi_snapshot.dart';
import 'finance_ai_kpi_formatters.dart';

/// Kanonski redoslijed pet rejection kodova.
const kFinanceAiKpiRejectionCodes = [
  'not_relevant',
  'already_resolved',
  'incorrect_incomplete_data',
  'other_business_decision',
  'other',
];

class FinanceAiRejectionBreakdown extends StatelessWidget {
  const FinanceAiRejectionBreakdown({
    super.key,
    required this.rejectionRateByReason,
    required this.rejectionCountByReason,
    required this.totalRejected,
  });

  final Map<String, FinanceAiKpiRateMetric> rejectionRateByReason;
  final Map<String, int> rejectionCountByReason;
  final int totalRejected;

  String _reasonLabel(BuildContext context, String code) {
    const keys = <String, String>{
      'not_relevant': 'advisory_reject_reason_not_relevant',
      'already_resolved': 'advisory_reject_reason_already_resolved',
      'incorrect_incomplete_data':
          'advisory_reject_reason_incorrect_incomplete_data',
      'other_business_decision': 'advisory_reject_reason_other_business_decision',
      'other': 'advisory_reject_reason_other',
    };
    return FinanceStrings.t(context, keys[code] ?? code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (totalRejected <= 0) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            FinanceStrings.t(context, 'kpi_rejection_empty'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FinanceStrings.t(context, 'kpi_section_rejection'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final code in kFinanceAiKpiRejectionCodes) ...[
              _reasonRow(context, code),
              if (code != kFinanceAiKpiRejectionCodes.last)
                const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reasonRow(BuildContext context, String code) {
    final theme = Theme.of(context);
    final metric = rejectionRateByReason[code] ??
        FinanceAiKpiRateMetric(numerator: 0, denominator: totalRejected);
    final count = rejectionCountByReason[code] ?? metric.numerator;
    final pct = FinanceAiKpiFormatters.percentOnly(context, metric);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _reasonLabel(context, code),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pct,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$count / $totalRejected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
