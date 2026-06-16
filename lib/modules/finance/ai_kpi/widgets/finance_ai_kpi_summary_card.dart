import 'package:flutter/material.dart';

import '../../shared/finance_strings.dart';
import '../models/finance_ai_recommendation_kpi_snapshot.dart';

class FinanceAiKpiSummaryCard extends StatelessWidget {
  const FinanceAiKpiSummaryCard({
    super.key,
    required this.metrics,
  });

  final FinanceAiRecommendationKpiMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = metrics.interactionTypeCounts;
    final shown = metrics.shownCount.value;
    final viewed = types['viewed'] ?? 0;
    final accepted = types['accepted'] ?? 0;
    final rejected = types['rejected'] ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FinanceStrings.t(context, 'kpi_section_engagement'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _countRow(
              context,
              FinanceStrings.t(context, 'kpi_shown_count'),
              shown,
            ),
            _countRow(
              context,
              FinanceStrings.t(context, 'kpi_viewed_count'),
              viewed,
            ),
            _countRow(
              context,
              FinanceStrings.t(context, 'kpi_accepted_count'),
              accepted,
            ),
            _countRow(
              context,
              FinanceStrings.t(context, 'kpi_rejected_count'),
              rejected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _countRow(BuildContext context, String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
