import 'package:flutter/material.dart';

import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_match_suggestion.dart';
import '../utils/finance_bank_match_suggestion_ui_helper.dart';

class FinanceBankMatchSuggestionCard extends StatelessWidget {
  const FinanceBankMatchSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onTap,
    this.dismissed = false,
  });

  final FinanceBankMatchSuggestion suggestion;
  final VoidCallback onTap;
  final bool dismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reasons = FinanceBankMatchSuggestionUiHelper.topReasonLabels(
      context,
      suggestion,
    );
    final bankLabel = suggestion.isInflow
        ? FinanceStrings.t(context, 'bank_match_card_bank_payment')
        : FinanceStrings.t(context, 'bank_match_card_bank_payout');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      FinanceStrings.t(context, 'bank_match_card_title')
                          .replaceAll('{number}', suggestion.invoiceNumber)
                          .replaceAll('{partner}', suggestion.displayPartnerName),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (dismissed) ...[
                const SizedBox(height: 4),
                Text(
                  FinanceStrings.t(context, 'bank_match_restore_suggestion'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${FinanceStrings.t(context, 'bank_match_card_open')}: '
                '${FinanceMoneyFormat.format(suggestion.invoiceOpenAmount, suggestion.currency)}',
              ),
              Text(
                '$bankLabel: '
                '${FinanceMoneyFormat.format(suggestion.bankAmount, suggestion.currency)}',
              ),
              Text(
                FinanceBankMatchSuggestionUiHelper.formatAmountDifference(
                  context,
                  suggestion,
                  FinanceMoneyFormat.format,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                FinanceBankMatchSuggestionUiHelper.confidenceLabel(
                  context,
                  suggestion,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: FinanceBankMatchSuggestionUiHelper.isHigh(suggestion)
                      ? cs.primary
                      : cs.onSurface,
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  FinanceStrings.t(context, 'bank_match_top_reasons'),
                  style: theme.textTheme.labelMedium,
                ),
                ...reasons.map(
                  (r) => Text('· $r', style: theme.textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                FinanceStrings.t(context, 'bank_match_tap_for_detail'),
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
}

extension on FinanceBankMatchSuggestion {
  bool get isInflow => direction.toLowerCase() == 'inflow';
}
