import 'package:flutter/material.dart';

import '../utils/development_intelligence_glossary.dart';

/// Treći tab: kratki vodič — puni AI / Launch Intelligence ostaje u **detalju projekta**.
class DevelopmentPortfolioHelpTab extends StatelessWidget {
  const DevelopmentPortfolioHelpTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget p(String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(body, style: tt.bodyMedium?.copyWith(height: 1.4)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Pomoć i AI u modulu Razvoj',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Na ovom ekranu vidiš portfelj; duboka analiza (score, SOP blokade, Red Team) je '
          'vezana uz pojedinačan projekat.',
          style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 20),
        p(
          'AI asistent na projektu',
          'Otvori projekat → tab Pregled → „Generiraj AI sažetak”. '
          'Tab „Launch Intelligence” poziva isti backend kontekst uz score, blocker-e i (uz pretplatu) Red Team fokus.',
        ),
        p(
          'Launch Readiness Score',
          DevelopmentIntelligenceGlossary.launchReadinessScore,
        ),
        p(
          'No silent change',
          DevelopmentIntelligenceGlossary.noSilentChange,
        ),
        p(
          'Digitalni trag',
          DevelopmentIntelligenceGlossary.digitalThread,
        ),
        const SizedBox(height: 8),
        Text(
          'OperonixAI u izborniku je zaseban hub; razvojni kontekst u NPI-u uvijek ide kroz odabrani projekat.',
          style: tt.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}
