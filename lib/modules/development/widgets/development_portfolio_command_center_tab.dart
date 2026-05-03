import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../utils/development_constants.dart';
import '../utils/development_intelligence_glossary.dart';
import '../utils/development_permissions.dart';
import 'development_project_card.dart';

/// Tab **Launch Intelligence** na nivou portfelja — Command Center bez novih Callable-a:
/// agregat iz `development_projects` (KPI na dokumentu) + pojmovnik + brzi skok u detalj.
class DevelopmentPortfolioCommandCenterTab extends StatelessWidget {
  const DevelopmentPortfolioCommandCenterTab({
    super.key,
    required this.companyData,
    required this.projects,
    required this.showPlantChip,
    required this.onOpenProject,
  });

  final Map<String, dynamic> companyData;
  final List<DevelopmentProjectModel> projects;
  final bool showPlantChip;
  final void Function(DevelopmentProjectModel p) onOpenProject;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final canKpi = DevelopmentPermissions.canViewDevelopmentPortfolioKpi(
      role: companyData['role']?.toString(),
      project: null,
      userId: uid,
    );

    if (!canKpi) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              'Pregled agregiranog Launch Intelligence / KPI portfelja za tvoju ulogu nije dostupan. '
              'Otvori projekat na kojem si u timu — u detalju su Launch Readiness Score, SOP blocker-i, '
              'heatmap i AI alati (prema pretplati).',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    if (projects.isEmpty) {
      return Center(
        child: Text(
          'Nema projekata u trenutnom opsegu — prilagodi poslovnu godinu ili pogon.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final healthVals = <double>[];
    for (final p in projects) {
      final h = p.kpi.overallHealthScore;
      if (h != null) healthVals.add(h);
    }
    final avgHealth = healthVals.isEmpty
        ? null
        : healthVals.reduce((a, b) => a + b) / healthVals.length;
    var below60 = 0;
    for (final h in healthVals) {
      if (h < 60) below60++;
    }
    int criticalRisk = 0;
    int released = 0;
    for (final p in projects) {
      final rl = p.riskLevel.toLowerCase();
      if (rl == 'critical' || rl == 'high') criticalRisk++;
      if (p.releasedToProductionAt != null) released++;
    }

    Widget glossTile(String title, String glossary, IconData icon) {
      return ListTile(
        dense: true,
        leading: Icon(icon, color: scheme.primary, size: 22),
        title: Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(glossary, style: tt.bodySmall?.copyWith(height: 1.35)),
        trailing: Tooltip(
          message: glossary,
          child: Icon(Icons.info_outline, color: scheme.outline, size: 20),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Card(
          elevation: 0,
          color: scheme.primaryContainer.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Launch Intelligence — Command Center (portfelj)',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Što je Launch Intelligence?',
                      onPressed: () => _showGlossaryDialog(context),
                      icon: const Icon(Icons.help_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Puni Operonix Launch Readiness Score (0–100) i SOP blocker-i računaju se u Callableu '
                  'po projektu (tab Detalj → Launch Intelligence). Ovdje je brzi agregat iz KPI polja na projektima.',
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w > 560 ? 2 : 1;
            final tileW = cols == 1 ? w : (w - 10) / 2;
            Widget metric(String label, String value, IconData icon, {String? tip}) {
              return SizedBox(
                width: tileW,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(icon, color: scheme.primary, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: tt.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                value,
                                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        if (tip != null)
                          Tooltip(
                            message: tip,
                            child: Icon(Icons.info_outline, size: 20, color: scheme.outline),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                metric(
                  'Prosječan „overall health”',
                  avgHealth == null ? '—' : avgHealth.toStringAsFixed(0),
                  Icons.health_and_safety_outlined,
                  tip:
                      'Agregat polja kpi.overallHealthScore na dokumentima projekata. '
                      'Puni Launch Readiness Score je u detalju projekta.',
                ),
                metric(
                  'Projekata ispod 60 (health)',
                  '$below60',
                  Icons.block,
                  tip: 'Broj projekata čija je procjena zdravlja ispod 60 (nije spremno za seriju prema politici score-a).',
                ),
                metric(
                  'Visok / kritičan rizik (brzi)',
                  '$criticalRisk',
                  Icons.warning_amber_rounded,
                  tip: 'Polje riskLevel na projektu — brzi filter, ne zamjena za puni PFMEA pregled.',
                ),
                metric(
                  'Već „release u proizvodnju”',
                  '$released / ${projects.length}',
                  Icons.factory_outlined,
                  tip: 'Projekti s postavljenim releasedToProductionAt.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Inteligencijski sloj (5 stubova)',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Card(
          child: Column(
            children: [
              glossTile(
                'Launch Readiness Score',
                DevelopmentIntelligenceGlossary.launchReadinessScore,
                Icons.analytics_outlined,
              ),
              const Divider(height: 1),
              glossTile(
                'SOP blocker-i',
                DevelopmentIntelligenceGlossary.sopBlockers,
                Icons.gpp_maybe_outlined,
              ),
              const Divider(height: 1),
              glossTile(
                'AI Change Impact',
                DevelopmentIntelligenceGlossary.changeImpact,
                Icons.alt_route_outlined,
              ),
              const Divider(height: 1),
              glossTile(
                'Lessons learned',
                DevelopmentIntelligenceGlossary.lessonsLearned,
                Icons.school_outlined,
              ),
              const Divider(height: 1),
              glossTile(
                'Dynamic Control Plan',
                DevelopmentIntelligenceGlossary.dynamicControlPlan,
                Icons.tune_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text('Još pojmova', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          children: [
            glossTile(
              'Digitalni trag',
              DevelopmentIntelligenceGlossary.digitalThread,
              Icons.timeline_outlined,
            ),
            glossTile(
              'Prediktivni rizik',
              DevelopmentIntelligenceGlossary.predictiveRisk,
              Icons.bolt_outlined,
            ),
            glossTile(
              'Red Team',
              DevelopmentIntelligenceGlossary.redTeam,
              Icons.shield_moon_outlined,
            ),
            glossTile(
              'Risk heatmap',
              DevelopmentIntelligenceGlossary.heatmap,
              Icons.grid_on_outlined,
            ),
            glossTile(
              'No silent change',
              DevelopmentIntelligenceGlossary.noSilentChange,
              Icons.lock_outline,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Projekti (prioritet: najniži health)',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Tooltip(
              message: DevelopmentIntelligenceGlossary.launchReadinessScore,
              child: Icon(Icons.info_outline, size: 20, color: scheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...() {
          final sorted = List<DevelopmentProjectModel>.from(projects);
          sorted.sort((a, b) {
            final ha = a.kpi.overallHealthScore;
            final hb = b.kpi.overallHealthScore;
            if (ha == null && hb == null) return 0;
            if (ha == null) return 1;
            if (hb == null) return -1;
            return ha.compareTo(hb);
          });
          return sorted.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DevelopmentProjectCard(
                project: p,
                showPlantChip: showPlantChip,
                onTap: () => onOpenProject(p),
              ),
            );
          }).toList();
        }(),
        if (projects.any((p) => p.status == DevelopmentProjectStatuses.completed))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Savjet: za projekte u statusu „completed” provjeri Gate G9 i formalno zatvaranje u detalju.',
              style: tt.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  void _showGlossaryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Launch Intelligence — pojmovnik'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DevelopmentIntelligenceGlossary.launchReadinessScore,
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              Text(
                DevelopmentIntelligenceGlossary.sopBlockers,
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              Text(
                DevelopmentIntelligenceGlossary.digitalThread,
                style: const TextStyle(height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori')),
        ],
      ),
    );
  }
}
