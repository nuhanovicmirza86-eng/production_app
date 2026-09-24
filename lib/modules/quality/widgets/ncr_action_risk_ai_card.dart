import 'package:flutter/material.dart';

import '../../../core/branding/operonix_ai_branding.dart';
import '../models/ncr_action_history_models.dart';

/// M1-I13-F — Operonix AI Asistent: kratko objašnjenje determinističkih signala.
class NcrActionRiskAiCard extends StatelessWidget {
  const NcrActionRiskAiCard({
    super.key,
    required this.explanation,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final NcrActionRiskAiExplanation? explanation;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  static const sectionTitle = 'AI procjena rizika';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kOperonixAiAssistantProductName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sectionTitle,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (error != null && error!.trim().isNotEmpty)
              _ErrorLine(message: error!, onRetry: onRetry)
            else if (explanation != null) ...[
              _field(context, 'Procjena', explanation!.procjena),
              const SizedBox(height: 6),
              _field(context, 'Zašto je važno', explanation!.zastoJeVazno),
              const SizedBox(height: 6),
              _field(
                context,
                'Preporučeni sljedeći korak',
                explanation!.preporuceniSljedeciKorak,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final v = value.trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 156,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Pokušaj ponovo'),
          ),
      ],
    );
  }
}
