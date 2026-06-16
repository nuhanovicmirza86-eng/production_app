import 'package:flutter/material.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_ai_recommendation_kpi_snapshot.dart';

class FinanceAiAttributionBreakdown extends StatelessWidget {
  const FinanceAiAttributionBreakdown({
    super.key,
    required this.outcomeCountByAttribution,
    required this.confirmedImpact,
  });

  final Map<String, int> outcomeCountByAttribution;
  final FinanceAiKpiConfirmedImpactSum confirmedImpact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direct = outcomeCountByAttribution['direct'] ?? 0;
    final contributing = outcomeCountByAttribution['contributing'] ?? 0;
    final uncertain = outcomeCountByAttribution['uncertain'] ?? 0;
    final notAttributable = outcomeCountByAttribution['not_attributable'] ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FinanceStrings.t(context, 'kpi_section_attribution'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              FinanceStrings.t(context, 'kpi_attribution_eligible_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _row(
              context,
              FinanceDisplayLabels.advisoryOutcomeAttribution(context, 'direct'),
              direct,
              emphasized: true,
            ),
            _row(
              context,
              FinanceDisplayLabels.advisoryOutcomeAttribution(context, 'contributing'),
              contributing,
              emphasized: true,
            ),
            const Divider(height: 20),
            Text(
              FinanceStrings.t(context, 'kpi_attribution_excluded_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _row(
              context,
              FinanceDisplayLabels.advisoryOutcomeAttribution(context, 'uncertain'),
              uncertain,
              muted: true,
            ),
            _row(
              context,
              FinanceDisplayLabels.advisoryOutcomeAttribution(
                context,
                'not_attributable',
              ),
              notAttributable,
              muted: true,
            ),
            if (confirmedImpact.byCurrency.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                FinanceStrings.t(context, 'kpi_attribution_impact_note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int count, {
    bool emphasized = false,
    bool muted = false,
  }) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: muted ? theme.colorScheme.onSurfaceVariant : null,
      fontWeight: emphasized ? FontWeight.w600 : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('$count', style: style),
        ],
      ),
    );
  }
}
