import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_ai_outcome_evidence.dart';

/// Poslovni prikaz jednog evidence zapisa — bez internih ID-jeva.
class FinanceAiOutcomeEvidenceCard extends StatelessWidget {
  const FinanceAiOutcomeEvidenceCard({
    super.key,
    required this.evidence,
    this.confirmationMethod = '',
  });

  final FinanceAiOutcomeEvidence evidence;
  final String confirmationMethod;

  String _formatValue(BuildContext context, dynamic value, String currency) {
    if (value == null) {
      return FinanceStrings.t(context, 'advisory_outcome_value_unavailable');
    }
    if (value is num) {
      final cur = currency.trim();
      if (cur.isNotEmpty) {
        final fmt = NumberFormat.currency(name: cur);
        return fmt.format(value);
      }
      return NumberFormat.decimalPattern().format(value);
    }
    final text = value.toString().trim();
    return text.isEmpty
        ? FinanceStrings.t(context, 'advisory_outcome_value_unavailable')
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();
    final observedAt = evidence.observedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FinanceDisplayLabels.advisoryOutcomeEvidenceMeasured(
                context,
                evidence,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _row(
              context,
              FinanceStrings.t(context, 'advisory_outcome_evidence_before'),
              _formatValue(context, evidence.observedBefore, evidence.currency),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'advisory_outcome_evidence_after'),
              _formatValue(context, evidence.observedAfter, evidence.currency),
            ),
            if (observedAt != null)
              _row(
                context,
                FinanceStrings.t(context, 'advisory_outcome_evidence_observed_at'),
                df.format(observedAt.toLocal()),
              ),
            if (confirmationMethod.trim().isNotEmpty)
              _row(
                context,
                FinanceStrings.t(context, 'advisory_outcome_confirmation_method'),
                FinanceDisplayLabels.advisoryOutcomeConfirmationMethod(
                  context,
                  confirmationMethod,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
