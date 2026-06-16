import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_ai_outcome.dart';
import 'finance_ai_outcome_evidence_card.dart';

/// Ishod preporuke — read-only Callable model, bez lokalnog računanja.
class FinanceAiOutcomeSection extends StatelessWidget {
  const FinanceAiOutcomeSection({
    super.key,
    required this.detail,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final FinanceAiOutcomeDetail detail;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = detail.outcome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FinanceStrings.t(context, 'advisory_section_outcome'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null && error!.trim().isNotEmpty)
          _errorBanner(context, error!)
        else if (outcome == null)
          Text(
            FinanceStrings.t(context, 'advisory_outcome_empty'),
            style: theme.textTheme.bodyMedium,
          )
        else
          _buildOutcome(context, outcome),
      ],
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(FinanceStrings.t(context, 'retry')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcome(BuildContext context, FinanceAiOutcome outcome) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();
    final confirmed = outcome.confirmedImpact;
    final confirmationMethod = confirmed?.confirmationMethod ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FinanceDisplayLabels.advisoryOutcomeStatusMessage(
            context,
            outcome.outcomeStatus,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _row(
          context,
          FinanceStrings.t(context, 'advisory_outcome_status'),
          FinanceDisplayLabels.advisoryOutcomeStatus(context, outcome.outcomeStatus),
        ),
        if (outcome.observationStartedAt != null || outcome.observationEndsAt != null)
          _row(
            context,
            FinanceStrings.t(context, 'advisory_outcome_observation_window'),
            _windowText(context, outcome, df),
          ),
        if (outcome.nextEvaluationAt != null)
          _row(
            context,
            FinanceStrings.t(context, 'advisory_outcome_next_evaluation'),
            df.format(outcome.nextEvaluationAt!.toLocal()),
          ),
        if (outcome.attributionLevel.trim().isNotEmpty)
          _row(
            context,
            FinanceStrings.t(context, 'advisory_outcome_attribution'),
            FinanceDisplayLabels.advisoryOutcomeAttribution(
              context,
              outcome.attributionLevel,
            ),
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
        if (confirmed?.confirmedImpactAmount != null) ...[
          _row(
            context,
            FinanceStrings.t(context, 'advisory_outcome_confirmed_impact'),
            _formatImpact(context, confirmed!),
          ),
        ],
        if (detail.evidence.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            FinanceStrings.t(context, 'advisory_outcome_evidence_title'),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          ...detail.evidence.map(
            (e) => FinanceAiOutcomeEvidenceCard(
              evidence: e,
              confirmationMethod: confirmationMethod,
            ),
          ),
        ],
      ],
    );
  }

  String _windowText(
    BuildContext context,
    FinanceAiOutcome outcome,
    DateFormat df,
  ) {
    final start = outcome.observationStartedAt;
    final end = outcome.observationEndsAt;
    if (start != null && end != null) {
      return '${df.format(start.toLocal())} – ${df.format(end.toLocal())}';
    }
    if (start != null) return df.format(start.toLocal());
    if (end != null) return df.format(end.toLocal());
    return FinanceStrings.t(context, 'advisory_outcome_value_unavailable');
  }

  String _formatImpact(BuildContext context, FinanceAiConfirmedImpact impact) {
    final amount = impact.confirmedImpactAmount;
    if (amount == null) return '';
    final currency = impact.impactCurrency.trim();
    if (currency.isNotEmpty) {
      return NumberFormat.currency(name: currency).format(amount);
    }
    return NumberFormat.decimalPattern().format(amount);
  }

  Widget _row(BuildContext context, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
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
