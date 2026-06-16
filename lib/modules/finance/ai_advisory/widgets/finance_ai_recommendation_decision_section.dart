import 'package:flutter/material.dart';

import '../../shared/finance_strings.dart';
import '../models/finance_ai_recommendation_interaction.dart';
import 'finance_ai_reject_recommendation_sheet.dart';

/// Eksplicitne odluke prihvati/odbij preporuku — ne mijenja alert lifecycle.
class FinanceAiRecommendationDecisionSection extends StatelessWidget {
  const FinanceAiRecommendationDecisionSection({
    super.key,
    required this.canInteract,
    required this.actionInProgress,
    required this.interactionSummary,
    required this.onAccept,
    required this.onReject,
    this.telemetryError,
    this.onRetryTelemetry,
  });

  final bool canInteract;
  final bool actionInProgress;
  final FinanceAiInteractionSummary? interactionSummary;
  final VoidCallback onAccept;
  final Future<void> Function(String reasonCode, String? otherText) onReject;
  final String? telemetryError;
  final VoidCallback? onRetryTelemetry;

  bool get _accepted => interactionSummary?.accepted == true;
  bool get _rejected => interactionSummary?.rejected == true;

  @override
  Widget build(BuildContext context) {
    if (!canInteract) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FinanceStrings.t(context, 'advisory_section_decision'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_accepted)
          Text(
            FinanceStrings.t(context, 'advisory_decision_accepted'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          )
        else if (_rejected)
          Text(
            FinanceStrings.t(context, 'advisory_decision_rejected'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          FilledButton.tonal(
            onPressed: actionInProgress ? null : onAccept,
            child: Text(FinanceStrings.t(context, 'advisory_accept_recommendation')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: actionInProgress
                ? null
                : () => FinanceAiRejectRecommendationSheet.show(
                      context,
                      onSubmit: onReject,
                    ),
            child: Text(FinanceStrings.t(context, 'advisory_reject_recommendation')),
          ),
        ],
        if (telemetryError != null && telemetryError!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      telemetryError!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (onRetryTelemetry != null)
                    TextButton(
                      onPressed: actionInProgress ? null : onRetryTelemetry,
                      child: Text(FinanceStrings.t(context, 'retry')),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
