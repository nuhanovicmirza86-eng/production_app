import 'package:flutter/material.dart';

import 'package:production_app/core/branding/operonix_ai_branding.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../models/ai_insight_model.dart';

class AiInsightCard extends StatelessWidget {
  const AiInsightCard({super.key, required this.insight});

  final OperonixAiInsight insight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      shape: operonixProductionCardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 22,
                  color: kOperonixScadaAccentBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  kOperonixAiShortLabel,
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              insight.summary,
              style: t.textTheme.bodyMedium,
            ),
            if (insight.comparisonNote != null) ...[
              const SizedBox(height: 10),
              Text(
                insight.comparisonNote!,
                style: t.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (insight.riskNote != null) ...[
              const SizedBox(height: 10),
              Text(
                'Rizik: ${insight.riskNote!}',
                style: t.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Glavni signali',
              style: t.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final c in insight.mainCauses) ...[
              _bullet(context, c),
            ],
            const SizedBox(height: 12),
            Text(
              'Preporučene akcije',
              style: t.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final r in insight.recommendations) ...[
              _bullet(context, r),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ', style: TextStyle(fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
