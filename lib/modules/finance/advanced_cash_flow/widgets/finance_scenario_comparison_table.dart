import 'package:flutter/material.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario.dart';

/// Jednostavna tablica — bez grafikona vremenske serije.
class FinanceScenarioComparisonTable extends StatelessWidget {
  const FinanceScenarioComparisonTable({
    super.key,
    required this.optimistic,
    required this.base,
    required this.pessimistic,
  });

  final FinanceCashFlowScenario? optimistic;
  final FinanceCashFlowScenario? base;
  final FinanceCashFlowScenario? pessimistic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FinanceStrings.t(context, 'scenario_comparison_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
          },
          border: TableBorder.all(
            color: Theme.of(context).dividerColor,
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: [
                _cell(context, FinanceStrings.t(context, 'scenario_comparison_metric')),
                _cell(
                  context,
                  FinanceDisplayLabels.scenarioType(context, 'optimistic'),
                ),
                _cell(
                  context,
                  FinanceDisplayLabels.scenarioType(context, 'base'),
                ),
                _cell(
                  context,
                  FinanceDisplayLabels.scenarioType(context, 'pessimistic'),
                ),
              ],
            ),
            _metricRow(
              context,
              FinanceStrings.t(context, 'scenario_result_closing'),
              (s) => _money(s),
            ),
            _metricRow(
              context,
              FinanceStrings.t(context, 'scenario_result_minimum'),
              (s) => _minMoney(s),
            ),
            _metricRow(
              context,
              FinanceStrings.t(context, 'scenario_result_periods_below'),
              (s) => s?.displaySnapshot.periodsBelowThreshold.toString() ?? '—',
            ),
            _metricRow(
              context,
              FinanceStrings.t(context, 'scenario_result_inflows'),
              (s) => s == null
                  ? '—'
                  : FinanceMoneyFormat.format(
                      s.displaySnapshot.totalProjectedInflows,
                      s.displaySnapshot.baseCurrency,
                    ),
            ),
            _metricRow(
              context,
              FinanceStrings.t(context, 'scenario_result_outflows'),
              (s) => s == null
                  ? '—'
                  : FinanceMoneyFormat.format(
                      s.displaySnapshot.totalProjectedOutflows,
                      s.displaySnapshot.baseCurrency,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  TableRow _metricRow(
    BuildContext context,
    String label,
    String? Function(FinanceCashFlowScenario?) value,
  ) {
    return TableRow(
      children: [
        _cell(context, label),
        _cell(context, value(optimistic) ?? '—'),
        _cell(context, value(base) ?? '—'),
        _cell(context, value(pessimistic) ?? '—'),
      ],
    );
  }

  String? _money(FinanceCashFlowScenario? s) {
    if (s == null) return null;
    return FinanceMoneyFormat.format(
      s.displaySnapshot.nominalClosingBalance,
      s.displaySnapshot.baseCurrency,
    );
  }

  String? _minMoney(FinanceCashFlowScenario? s) {
    if (s == null) return null;
    final min = s.displaySnapshot.minimumNominalBalance;
    if (min == null) return '—';
    return FinanceMoneyFormat.format(min, s.displaySnapshot.baseCurrency);
  }

  Widget _cell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
