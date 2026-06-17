import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario.dart';

class FinanceScenarioSummaryTile extends StatelessWidget {
  const FinanceScenarioSummaryTile({
    super.key,
    required this.scenario,
    required this.onTap,
  });

  final FinanceCashFlowScenario scenario;
  final VoidCallback onTap;

  String _formatDate(BuildContext context, DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  @override
  Widget build(BuildContext context) {
    final snap = scenario.displaySnapshot;
    final currency = snap.baseCurrency;
    final belowWarning = snap.belowReserveWarning;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (belowWarning)
                    Tooltip(
                      message: FinanceStrings.t(
                        context,
                        'scenario_liquidity_warning',
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(
                      FinanceDisplayLabels.scenarioType(
                        context,
                        scenario.scenarioType,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      FinanceDisplayLabels.scenarioStatus(
                        context,
                        scenario.status,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${_formatDate(context, scenario.periodFrom)} – '
                    '${_formatDate(context, scenario.periodTo)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                FinanceStrings.t(context, 'scenario_list_closing')
                    .replaceAll(
                      '{amount}',
                      FinanceMoneyFormat.format(
                        snap.nominalClosingBalance,
                        currency,
                      ),
                    ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (snap.minimumNominalBalance != null)
                Text(
                  FinanceStrings.t(context, 'scenario_list_minimum')
                      .replaceAll(
                        '{amount}',
                        FinanceMoneyFormat.format(
                          snap.minimumNominalBalance!,
                          currency,
                        ),
                      ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Text(
                FinanceStrings.t(context, 'scenario_list_meta')
                    .replaceAll(
                      '{version}',
                      scenario.revision.toString(),
                    )
                    .replaceAll(
                      '{updated}',
                      _formatDate(context, scenario.updatedAt),
                    )
                    .replaceAll(
                      '{user}',
                      _userLabel(scenario),
                    ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _userLabel(FinanceCashFlowScenario scenario) {
    final email = scenario.updatedByEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    final uid = scenario.updatedBy?.trim();
    if (uid != null && uid.isNotEmpty) {
      return uid.length > 12 ? '${uid.substring(0, 12)}…' : uid;
    }
    return '—';
  }
}
