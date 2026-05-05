import 'package:flutter/material.dart';

import '../data/development_demo_sample_project.dart';
import 'development_project_card.dart';
import '../screens/development_project_demo_fullscreen_screen.dart';

/// Uvijek isti ilustrativni projekt u portfelju — izgleda kao stvarna kartica, otvara puni demo ekran.
class DevelopmentDemoPortfolioProjectCard extends StatelessWidget {
  const DevelopmentDemoPortfolioProjectCard({
    super.key,
    required this.companyData,
    required this.showPlantChip,
  });

  final Map<String, dynamic> companyData;
  final bool showPlantChip;

  void _openDemo(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DevelopmentProjectDemoFullscreenScreen(
          companyData: companyData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cid = (companyData['companyId'] ?? '').toString().trim();
    final pk = (companyData['plantKey'] ?? '').toString().trim();
    final demo = buildDevelopmentDemoSampleProject(
      companyId: cid,
      plantKey: pk,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_outline, size: 20, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Primjer: ${demo.projectName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Kratko o primjeru',
              icon: Icon(Icons.info_outline, color: scheme.outline),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Primjer u portfelju'),
                    content: Text(
                      'Ovo nije zapis u bazi. Kartica koristi isti izgled kao pravi projekti; '
                      'dodir otvara puni demo ekran (KPI, dokumentacija projekta — crtež, spec, zahtjevi — Stage-Gate, tim, Launch readiness) da vidiš tok bez pravih podataka.',
                      style: TextStyle(
                        height: 1.35,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Zatvori'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: scheme.tertiaryContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _openDemo(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DevelopmentProjectCard(
                project: demo,
                showPlantChip: showPlantChip,
                onTap: () => _openDemo(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
