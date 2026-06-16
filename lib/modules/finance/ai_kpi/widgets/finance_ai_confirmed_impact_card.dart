import 'package:flutter/material.dart';

import '../../shared/finance_strings.dart';
import '../models/finance_ai_recommendation_kpi_snapshot.dart';
import 'finance_ai_kpi_formatters.dart';

class FinanceAiConfirmedImpactCard extends StatelessWidget {
  const FinanceAiConfirmedImpactCard({
    super.key,
    required this.impact,
  });

  final FinanceAiKpiConfirmedImpactSum impact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byCurrency = impact.byCurrency;
    final sortedCurrencies = byCurrency.keys.toList()..sort();

    if (sortedCurrencies.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                FinanceStrings.t(context, 'kpi_confirmed_impact_title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                FinanceStrings.t(context, 'kpi_confirmed_impact_empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
              FinanceStrings.t(context, 'kpi_confirmed_impact_title'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              FinanceStrings.t(context, 'kpi_confirmed_impact_subtitle'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (impact.multiCurrencyWarning) ...[
              const SizedBox(height: 12),
              Material(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          FinanceStrings.t(context, 'kpi_multi_currency_warning'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final currency in sortedCurrencies)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  FinanceAiKpiFormatters.formatAmount(
                    context,
                    byCurrency[currency]!,
                    currency,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (impact.baseCurrencyTotal != null &&
                impact.baseCurrency != null &&
                !impact.multiCurrencyWarning) ...[
              const Divider(height: 16),
              Text(
                FinanceStrings.t(context, 'kpi_base_currency_total')
                    .replaceAll('{currency}', impact.baseCurrency!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                FinanceAiKpiFormatters.formatAmount(
                  context,
                  impact.baseCurrencyTotal!,
                  impact.baseCurrency!,
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
