import 'package:flutter/material.dart';

import '../helpers/aps_execution_watch_explain_copy.dart';
import '../models/aps_execution_watch_ai_explanation_view.dart';

/// P6.2 — sekcija objašnjenja (savjet, ne automatska odluka).
class ApsExecutionWatchExplanationSection extends StatelessWidget {
  const ApsExecutionWatchExplanationSection({
    super.key,
    required this.explanation,
    required this.loading,
    required this.onRequestExplanation,
    this.enabled = true,
  });

  final ApsExecutionWatchAiExplanationView? explanation;
  final bool loading;
  final VoidCallback? onRequestExplanation;
  final bool enabled;

  static const _defaultDisclaimer = ApsExecutionWatchExplainCopy.disclaimer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exp = explanation;
    final hasExplanation = exp != null && exp.hasContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.psychology_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ApsExecutionWatchExplainCopy.sectionTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: cs.tertiaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: cs.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exp?.disclaimerText.isNotEmpty == true
                        ? exp!.disclaimerText
                        : _defaultDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!hasExplanation && !loading) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: enabled && !loading ? onRequestExplanation : null,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text(ApsExecutionWatchExplainCopy.requestButton),
          ),
        ],
        if (loading) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text(ApsExecutionWatchExplainCopy.loading)),
            ],
          ),
        ],
        if (hasExplanation && !loading) ...[
          const SizedBox(height: 12),
          if (exp.systemFacts.isNotEmpty) ...[
            Text(
              ApsExecutionWatchExplainCopy.factsHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            ...exp.systemFacts.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (exp.delayCause != null && exp.delayCause!.isNotEmpty) ...[
            Text(
              ApsExecutionWatchExplainCopy.delayCauseHeading,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(exp.delayCause!),
            const SizedBox(height: 8),
          ],
          if (exp.aiAssessment != null) ...[
            Text(
              ApsExecutionWatchExplainCopy.assessmentHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(exp.aiAssessment!),
            const SizedBox(height: 8),
          ],
          if (exp.whyItMatters != null) ...[
            Text(ApsExecutionWatchExplainCopy.whyHeading, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(exp.whyItMatters!),
            const SizedBox(height: 8),
          ],
          if (exp.solutionProposal != null && exp.solutionProposal!.isNotEmpty) ...[
            Text(
              ApsExecutionWatchExplainCopy.solutionHeading,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Material(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(exp.solutionProposal!),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (exp.proposedActions.isNotEmpty) ...[
            Text(
              ApsExecutionWatchExplainCopy.actionsHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            ...exp.proposedActions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a.rank}. ${a.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.meaning.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.meaning,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (exp.recommendedNextStep != null &&
              exp.proposedActions.isEmpty) ...[
            Text(
              ApsExecutionWatchExplainCopy.nextStepHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(exp.recommendedNextStep!),
            const SizedBox(height: 8),
          ],
          if (exp.limitations != null)
            Text(
              exp.limitations!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled && !loading ? onRequestExplanation : null,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(ApsExecutionWatchExplainCopy.refreshButton),
          ),
        ],
      ],
    );
  }
}
