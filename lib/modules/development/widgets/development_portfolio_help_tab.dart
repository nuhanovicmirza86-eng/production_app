import 'package:flutter/material.dart';

import '../utils/development_intelligence_glossary.dart';
import '../utils/development_launch_readiness_canonical.dart';

/// Tab **Pomoć** — referentni pragovi / težine + pojmovi s kratkim opisima.
class DevelopmentPortfolioHelpTab extends StatelessWidget {
  const DevelopmentPortfolioHelpTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget row({
      required IconData icon,
      required String label,
      required VoidCallback onInfo,
    }) {
      return ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(label, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        trailing: IconButton(
          tooltip: 'Opis',
          icon: const Icon(Icons.info_outline),
          onPressed: onInfo,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Analitika prikazuje grafove; ovdje su referentni pragovi i težine.',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        ExpansionTile(
          leading: Icon(Icons.rule_folder_outlined, color: scheme.primary),
          title: Text(
            'Pragovi Launch Readiness score-a',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          children: [
            for (final r in DevelopmentLaunchReadinessCanonical.scoreRules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        r.range,
                        style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.systemBehavior,
                        style: tt.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    DevelopmentIntelligenceGlossary.showScoreRulesDialog(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Puni dijalog'),
              ),
            ),
          ],
        ),
        ExpansionTile(
          leading: Icon(Icons.pie_chart_outline, color: scheme.primary),
          title: Text(
            'Težine segmenata (KPI na projektu)',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in DevelopmentLaunchReadinessCanonical.segmentWeights)
                  Chip(
                    label: Text(
                      '${s.weightPercent}% ${s.label}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    DevelopmentIntelligenceGlossary.showSegmentWeightsDialog(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Puni dijalog'),
              ),
            ),
          ],
        ),
        row(
          icon: Icons.analytics_outlined,
          label: 'Launch Readiness Score',
          onInfo: () => DevelopmentIntelligenceGlossary.showScoreRulesDialog(context),
        ),
        row(
          icon: Icons.shield_outlined,
          label: 'SOP blocker-i',
          onInfo: () => DevelopmentIntelligenceGlossary.showInfoSheet(
            context,
            title: 'SOP blocker-i',
            body: DevelopmentIntelligenceGlossary.sopBlockers,
          ),
        ),
        row(
          icon: Icons.lock_outline,
          label: 'No silent change',
          onInfo: () => DevelopmentIntelligenceGlossary.showInfoSheet(
            context,
            title: 'No silent change',
            body: DevelopmentIntelligenceGlossary.noSilentChange,
          ),
        ),
        row(
          icon: Icons.timeline_outlined,
          label: 'Digitalni trag',
          onInfo: () => DevelopmentIntelligenceGlossary.showInfoSheet(
            context,
            title: 'Digitalni trag',
            body: DevelopmentIntelligenceGlossary.digitalThread,
          ),
        ),
        row(
          icon: Icons.auto_awesome_outlined,
          label: 'AI asistent (tab)',
          onInfo: () => DevelopmentIntelligenceGlossary.showInfoSheet(
            context,
            title: 'AI asistent u portfelju',
            body:
                'Odaberi projekat i postavi pitanje ili predložak u tabu AI asistent. '
                'Isti backend kao u detalju projekta; model ne odobrava Gate niti release.',
          ),
        ),
        row(
          icon: Icons.hub_outlined,
          label: 'Launch Intelligence System',
          onInfo: () =>
              DevelopmentIntelligenceGlossary.showPortfolioScopeExplainer(context),
        ),
      ],
    );
  }
}
