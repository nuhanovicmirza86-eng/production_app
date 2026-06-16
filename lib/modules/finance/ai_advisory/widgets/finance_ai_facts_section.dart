import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_ai_alert.dart';

class FinanceAiFactsSection extends StatelessWidget {
  const FinanceAiFactsSection({
    super.key,
    required this.facts,
  });

  final List<FinanceAiAlertFact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) {
      return Text(
        FinanceStrings.t(context, 'advisory_facts_empty'),
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: facts.map((fact) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FinanceDisplayLabels.advisoryFactType(context, fact.factType),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fact.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (fact.asOfAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    FinanceStrings.t(context, 'advisory_fact_as_of')
                        .replaceAll('{date}', df.format(fact.asOfAt!.toLocal())),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (fact.snapshot.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...fact.snapshot.entries.map((e) {
                    return Text(
                      '${FinanceDisplayLabels.advisorySnapshotKey(context, e.key)}: '
                      '${FinanceDisplayLabels.advisorySnapshotValue(context, e.key, e.value)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
