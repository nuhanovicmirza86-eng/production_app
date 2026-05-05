import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../utils/development_constants.dart';
import '../utils/development_help_texts.dart';
import '../utils/development_intelligence_glossary.dart';
import '../utils/development_permissions.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';
import '../data/development_demo_sample_project.dart';
import '../data/development_portfolio_supplier_rollups.dart';
import '../services/development_project_service.dart';
import 'development_portfolio_analytics_dashboard.dart';

/// Tab **Pregled** — vizualna analitika portfelja (KPI + grafovi). Bez duplog popisa projekata.
class DevelopmentPortfolioCommandCenterTab extends StatelessWidget {
  const DevelopmentPortfolioCommandCenterTab({
    super.key,
    required this.companyData,
    required this.projects,
    required this.onOpenProject,
  });

  final Map<String, dynamic> companyData;
  final List<DevelopmentProjectModel> projects;
  final void Function(DevelopmentProjectModel p) onOpenProject;

  static bool _needsAttention(DevelopmentProjectModel p) {
    final s = p.status.trim();
    return s == DevelopmentProjectStatuses.atRisk ||
        s == DevelopmentProjectStatuses.delayed ||
        s == DevelopmentProjectStatuses.onHold;
  }

  /// Prioritet: status pažnje, zatim najniži health.
  static List<DevelopmentProjectModel> _attentionShortlist(
    List<DevelopmentProjectModel> projects,
  ) {
    final marked = projects.where(_needsAttention).toList();
    final rest = projects.where((p) => !_needsAttention(p)).toList();
    rest.sort((a, b) {
      final ha = a.kpi.overallHealthScore;
      final hb = b.kpi.overallHealthScore;
      if (ha == null && hb == null) return 0;
      if (ha == null) return 1;
      if (hb == null) return -1;
      return ha.compareTo(hb);
    });
    final out = <DevelopmentProjectModel>[...marked, ...rest];
    return out.take(5).toList();
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Skupni KPI portfelja nije dostupan za tvoju ulogu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              IconButton.filledTonal(
                tooltip: 'Više',
                onPressed: () => DevelopmentIntelligenceGlossary.showInfoSheet(
                  context,
                  title: 'Pregled portfelja',
                  body:
                      'Pregled agregiranog Launch Intelligence / KPI portfelja za tvoju ulogu nije uključen. '
                      'Na projektu na kojem si u timu u detalju su Launch Readiness Score, SOP blocker-i, '
                      'heatmap i AI alati (prema pretplati).',
                ),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ),
      );
    }

    if (projects.isEmpty) {
      final cid = (companyData['companyId'] ?? '').toString();
      final pk = (companyData['plantKey'] ?? '').toString();
      final scheme = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      final demoList = buildDevelopmentDemoPortfolioForAnalytics(
        companyId: cid,
        plantKey: pk,
      );
      final shortlist = _attentionShortlist(demoList);

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          DevelopmentPortfolioAnalyticsDashboard(
            projects: demoList,
            illustrationMode: true,
            onOpenProject: null,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: scheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Launch Intelligence — sažetak',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Što je Launch Intelligence?',
                        onPressed: () =>
                            DevelopmentIntelligenceGlossary.showPortfolioScopeExplainer(context),
                        icon: const Icon(Icons.info_outline),
                      ),
                    ],
                  ),
                  Text(
                    'Puni pragovi score-a i digitalni trag: tab Pomoć ili gumbi ispod.',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            DevelopmentIntelligenceGlossary.showScoreRulesDialog(context),
                        icon: const Icon(Icons.rule_folder_outlined, size: 18),
                        label: const Text('Pragovi score-a'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            DevelopmentIntelligenceGlossary.showSegmentWeightsDialog(context),
                        icon: const Icon(Icons.percent_outlined, size: 18),
                        label: const Text('Težine segmenata'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.crisis_alert, color: scheme.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fokus (primjer)',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kad u opsegu budu stvarni projekti, mini-kartice ispod pokazuju pažnju i najniži health. '
            'Lista i filteri ostaju na tabu Projekti.',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shortlist.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = shortlist[i];
                final attn = _needsAttention(p);
                final h = p.kpi.overallHealthScore;
                return _AttentionMiniCard(
                  project: p,
                  needsAttention: attn,
                  health: h,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ovo je sintetički projekat — otvori stvarni s taba Projekti.',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shortlist = _attentionShortlist(projects);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        FutureBuilder<PortfolioSupplierKpiSnapshot>(
          future: PortfolioSupplierKpiSnapshot.load(
            projects,
            DevelopmentProjectService(),
          ),
          builder: (context, snap) {
            return DevelopmentPortfolioAnalyticsDashboard(
              projects: projects,
              illustrationMode: false,
              onOpenProject: onOpenProject,
              supplierKpis: snap.data,
              companyData: companyData,
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: scheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Launch Intelligence — sažetak',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Što je Launch Intelligence?',
                      onPressed: () =>
                          DevelopmentIntelligenceGlossary.showPortfolioScopeExplainer(context),
                      icon: const Icon(Icons.info_outline),
                    ),
                  ],
                ),
                Text(
                  'Puni pragovi score-a, SOP i digitalni trag opisani su u tabu Pomoć '
                  '(karte se ne ponavljaju ovdje).',
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          DevelopmentIntelligenceGlossary.showScoreRulesDialog(context),
                      icon: const Icon(Icons.rule_folder_outlined, size: 18),
                      label: const Text('Pragovi score-a'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          DevelopmentIntelligenceGlossary.showSegmentWeightsDialog(context),
                      icon: const Icon(Icons.percent_outlined, size: 18),
                      label: const Text('Težine segmenata'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.crisis_alert, color: scheme.error, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fokus: pažnja i najniže zdravlje',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kompletna lista, filteri po Gate-u i kupcu — na tabu Projekti.',
          style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shortlist.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = shortlist[i];
              final attn = _needsAttention(p);
              final h = p.kpi.overallHealthScore;
              return _AttentionMiniCard(
                project: p,
                needsAttention: attn,
                health: h,
                onTap: () => onOpenProject(p),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _AttentionMiniCard extends StatelessWidget {
  const _AttentionMiniCard({
    required this.project,
    required this.needsAttention,
    required this.health,
    required this.onTap,
  });

  final DevelopmentProjectModel project;
  final bool needsAttention;
  final double? health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final border = needsAttention
        ? scheme.error.withValues(alpha: 0.65)
        : scheme.outlineVariant.withValues(alpha: 0.45);
    return Material(
      color: needsAttention
          ? scheme.errorContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 220,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: needsAttention ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.projectCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                project.projectName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.currentGate.trim().isEmpty ? '—' : project.currentGate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall,
                    ),
                  ),
                  OoeInfoIcon(
                    tooltip: DevelopmentHelpTexts.stageGateConceptTooltip,
                    dialogTitle: DevelopmentHelpTexts.stageGateConceptTitle,
                    dialogBody: DevelopmentHelpTexts.stageGateConceptBody,
                    iconSize: 16,
                  ),
                  if (health != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'H ${health!.toStringAsFixed(0)}',
                        style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  if (needsAttention)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
