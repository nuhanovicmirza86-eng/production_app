import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario_result.dart';

class FinanceScenarioResultSection extends StatelessWidget {
  const FinanceScenarioResultSection({
    super.key,
    required this.snapshot,
    this.titleKey = 'scenario_section_result',
  });

  final FinanceCashFlowScenarioSnapshot snapshot;
  final String titleKey;

  String _formatYmd(BuildContext context, String? ymd) {
    if (ymd == null || ymd.isEmpty) return '—';
    final parsed = DateTime.tryParse(ymd);
    if (parsed == null) return ymd;
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final currency = snapshot.baseCurrency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FinanceStrings.t(context, titleKey),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_result_closing'),
          FinanceMoneyFormat.format(snapshot.nominalClosingBalance, currency),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_result_minimum'),
          snapshot.minimumNominalBalance != null
              ? FinanceMoneyFormat.format(
                  snapshot.minimumNominalBalance!,
                  currency,
                )
              : '—',
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_result_minimum_date'),
          _formatYmd(context, snapshot.minimumNominalBalanceDate),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_result_periods_below'),
          snapshot.periodsBelowThreshold.toString(),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_result_inflows'),
          FinanceMoneyFormat.format(snapshot.totalProjectedInflows, currency),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_result_outflows'),
          FinanceMoneyFormat.format(snapshot.totalProjectedOutflows, currency),
        ),
        if (snapshot.accountBreakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            FinanceStrings.t(context, 'scenario_result_by_currency'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final line in snapshot.accountBreakdown)
            _row(
              context,
              line.sourceCurrency,
              FinanceMoneyFormat.format(line.sourceAmount, line.sourceCurrency),
            ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
