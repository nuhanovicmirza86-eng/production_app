import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../commercial/partners/screens/partner_customer_requirements_profile_screen.dart';
import '../models/development_launch_intelligence_result.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_intelligence_glossary.dart';
import '../utils/development_permissions.dart';

/// Command Center tab: Launch Readiness, blockeri, change impact, lekcije, CP, heatmap.
class DevelopmentLaunchIntelligenceTab extends StatefulWidget {
  const DevelopmentLaunchIntelligenceTab({
    super.key,
    required this.companyData,
    required this.project,
  });

  final Map<String, dynamic> companyData;
  final DevelopmentProjectModel project;

  @override
  State<DevelopmentLaunchIntelligenceTab> createState() =>
      _DevelopmentLaunchIntelligenceTabState();
}

class _DevelopmentLaunchIntelligenceTabState
    extends State<DevelopmentLaunchIntelligenceTab> {
  late Future<DevelopmentLaunchIntelligenceResult> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    final pk = (widget.companyData['plantKey'] ?? '').toString().trim();
    _future = DevelopmentProjectService().getLaunchIntelligenceViaCallable(
      companyId: cid,
      plantKey: pk,
      projectId: widget.project.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAi = DevelopmentPermissions.canRunDevelopmentProjectAi(
      role: widget.companyData['role']?.toString(),
      companyData: widget.companyData,
    );
    if (!DevelopmentPermissions.canCheckDevelopmentReleaseReadiness(
          role: widget.companyData['role']?.toString(),
          companyData: widget.companyData,
        )) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nemaš pravo na Launch Intelligence (isti skup kao provjera spremnosti za release).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return FutureBuilder<DevelopmentLaunchIntelligenceResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Učitavanje: ${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(_reload),
                    child: const Text('Pokušaj ponovo'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snap.data!;
        return RefreshIndicator(
          onRefresh: () async {
            final cid = (widget.companyData['companyId'] ?? '').toString().trim();
            final pk = (widget.companyData['plantKey'] ?? '').toString().trim();
            final next = DevelopmentProjectService().getLaunchIntelligenceViaCallable(
              companyId: cid,
              plantKey: pk,
              projectId: widget.project.id,
            );
            setState(() => _future = next);
            await next;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _scoreHeader(context, data),
              const SizedBox(height: 12),
              _line(
                context,
                DevelopmentIntelligenceGlossary.launchReadinessScore,
                'Launch Readiness Score koristi podatke iz projekta (heuristika MVP).',
              ),
              if (canAi) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _runAi(context, redTeam: false),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('AI sažetak'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _runAi(context, redTeam: true),
                      icon: const Icon(Icons.shield_moon_outlined),
                      label: const Text('AI Red Team'),
                    ),
                  ],
                ),
              ],
              if (data.customerRequirementsProfile != null) ...[
                const SizedBox(height: 16),
                _csrSummaryCard(context, data.customerRequirementsProfile!, project: widget.project),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'Nema učitanog CSR profila (provjeri customerId na projektu i Profil zahtjeva kupca kod kupca).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (widget.project.customerId != null &&
                    widget.project.customerId!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final p = widget.project;
                        final cid = p.customerId!.trim();
                        final name = (p.customerName ?? '').trim();
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => PartnerCustomerRequirementsProfileScreen(
                              companyData: widget.companyData,
                              customerId: cid,
                              customerDisplayName: name.isNotEmpty ? name : cid,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Otvori / uredi CSR profil'),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Parametri score-a (KPI kartice)',
                DevelopmentIntelligenceGlossary.launchReadinessScore,
              ),
              const SizedBox(height: 8),
              _segmentGrid(context, data),
              const SizedBox(height: 20),
              _sectionTitle(
                context,
                'SOP blocker-i',
                DevelopmentIntelligenceGlossary.sopBlockers,
              ),
              if (data.sopBlockers.isEmpty)
                Text(
                  'Nema aktivnih SOP blocker-a za ovaj referentni Gate.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...data.sopBlockers.map((b) => _blockTile(context, b)),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Change impact (otvorene izmjene)',
                DevelopmentIntelligenceGlossary.changeImpact,
              ),
              if (data.changeImpactSummaries.isEmpty)
                Text(
                  'Nema otvorenih izmjena u evidenciji.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...data.changeImpactSummaries.map(_changeImpactCard),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Lekcije iz sličnih projekata',
                DevelopmentIntelligenceGlossary.lessonsLearned,
              ),
              if (data.lessonsLearnedHints.isEmpty)
                Text(
                  'Nema dovoljno sličnih projekata za automatski trag (MVP heuristika).',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...data.lessonsLearnedHints.map(_lessonCard),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Dynamic Control Plan — prijedlozi',
                DevelopmentIntelligenceGlossary.dynamicControlPlan,
              ),
              if (data.dynamicControlPlan.isEmpty)
                Text(
                  'Nema automatskih prijedloga (niski rizik u ovom trenutku).',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...data.dynamicControlPlan.map(_cpSuggestion),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Prediktivni launch rizik',
                DevelopmentIntelligenceGlossary.predictiveRisk,
              ),
              if (data.predictiveRisks.isEmpty)
                Text(
                  'Nema dodatnih prediktivnih upozorenja iz trenutnih podataka.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...data.predictiveRisks.map(_predictiveLine),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Red Team (checklist)',
                DevelopmentIntelligenceGlossary.redTeam,
              ),
              Text(
                data.redTeamSummaryLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...data.redTeamQuestions.map(_redTeamQ),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Risk heatmap',
                DevelopmentIntelligenceGlossary.heatmap,
              ),
              _heatmap(context, data),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Digitalni trag',
                DevelopmentIntelligenceGlossary.digitalThread,
              ),
              Text(
                data.digitalThreadNarrative,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...data.digitalThreadSteps.map(_threadStep),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'No silent change',
                DevelopmentIntelligenceGlossary.noSilentChange,
              ),
              Text(data.noSilentChangeRule, style: Theme.of(context).textTheme.bodySmall),
              if (data.openBlockingChanges > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Otvorenih blokirajućih izmjena: ${data.openBlockingChanges}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (data.mesIntegrationNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  data.mesIntegrationNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _runAi(BuildContext context, {required bool redTeam}) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    final pk = (widget.companyData['plantKey'] ?? '').toString().trim();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(redTeam ? 'AI Red Team analiza…' : 'AI generiše sažetak…'),
            ),
          ],
        ),
      ),
    );
    try {
      final md = await DevelopmentProjectService().runDevelopmentProjectAiAnalysis(
        companyId: cid,
        plantKey: pk,
        projectId: widget.project.id,
        analysisFocus: redTeam ? 'red_team_pre_sop' : 'launch_intelligence_summary',
      );
      nav.pop();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(redTeam ? 'AI Red Team' : 'AI sažetak'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: MarkdownBody(data: md, selectable: true),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori')),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      nav.pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.toString())),
        );
      }
    } catch (e) {
      nav.pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _scoreHeader(BuildContext context, DevelopmentLaunchIntelligenceResult d) {
    final c = Theme.of(context).colorScheme;
    Color bg;
    if (d.launchReadinessScore >= 90) {
      bg = Colors.green.shade50;
    } else if (d.launchReadinessScore >= 75) {
      bg = Colors.amber.shade50;
    } else if (d.launchReadinessScore >= 60) {
      bg = Colors.orange.shade50;
    } else {
      bg = Colors.red.shade50;
    }
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operonix Launch Readiness',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Tooltip(
                  message: DevelopmentIntelligenceGlossary.launchReadinessScore,
                  child: Icon(Icons.info_outline, size: 22, color: c.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${d.launchReadinessScore} / 100',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              d.launchReadinessStatusLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (d.launchSummaryLine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  d.launchSummaryLine,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Text(
              'Referentni Gate: ${d.targetGate}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentGrid(BuildContext context, DevelopmentLaunchIntelligenceResult d) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w > 600 ? 3 : 2;
        final tileW = (w - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: d.segments.map((s) {
            final gloss = DevelopmentIntelligenceGlossary.forSegmentId(s.id);
            return SizedBox(
              width: tileW,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.label,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (gloss != null)
                            Tooltip(
                              message: gloss,
                              child: Icon(
                                Icons.help_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${s.points.toStringAsFixed(1)} / ${s.weightPercent}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        s.detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String tooltip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Tooltip(
          message: tooltip,
          child: Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, String tooltip, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: tooltip,
          child: Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }

  Widget _csrSummaryCard(
    BuildContext context,
    Map<String, dynamic> c, {
    required DevelopmentProjectModel project,
  }) {
    String s(dynamic k) => (c[k] ?? '').toString();
    final lines = <String>[
      if (s('ppapLevel').isNotEmpty && s('ppapLevel') != 'null') 'PPAP: ${s('ppapLevel')}',
      if (c['changeNotificationWeeks'] != null) 'Obavještenje promjene: ${c['changeNotificationWeeks']} sedm.',
      if (s('customerNameSnapshot').isNotEmpty) 'Snimak naziva: ${s('customerNameSnapshot')}',
      if (s('specialRequirementsPreview').isNotEmpty) 'Posebni zahtjevi: ${s('specialRequirementsPreview')}',
      if (s('documentationRequirementsPreview').isNotEmpty)
        'Dokumentacija: ${s('documentationRequirementsPreview')}',
      if (s('reactionPlanPolicy').isNotEmpty) 'Reakcioni plan: ${s('reactionPlanPolicy')}',
      if (s('tolerancePolicyPreview').isNotEmpty) 'Tolerancije: ${s('tolerancePolicyPreview')}',
      if (s('csrDocumentReference').isNotEmpty) 'CSR ref.: ${s('csrDocumentReference')}',
      if (c['communicationContactCount'] != null) 'Kontakata: ${c['communicationContactCount']}',
    ];
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer requirement profile (CSR)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lines.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(t, style: Theme.of(context).textTheme.bodySmall),
                )),
            if (project.customerId != null && project.customerId!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final cid = project.customerId!.trim();
                    final name = (project.customerName ?? '').trim();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => PartnerCustomerRequirementsProfileScreen(
                          companyData: widget.companyData,
                          customerId: cid,
                          customerDisplayName: name.isNotEmpty ? name : cid,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Puni CSR profil (partner)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _blockTile(BuildContext context, Map<String, dynamic> b) {
    final tier = (b['tier'] ?? '').toString();
    final hard = tier == 'hard';
    return ListTile(
      dense: true,
      leading: Icon(
        hard ? Icons.block : Icons.warning_amber_outlined,
        color: hard ? Theme.of(context).colorScheme.error : Colors.orange,
      ),
      title: Text((b['message'] ?? '').toString()),
      subtitle: Text('${b['code'] ?? ''} · ${b['source'] ?? ''}'),
    );
  }

  Widget _changeImpactCard(Map<String, dynamic> c) {
    final areas = c['impactedAreas'];
    final list = areas is List ? areas.map((e) => e.toString()).join(', ') : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (c['title'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Vrsta: ${c['changeKind'] ?? ''} · Status: ${c['status'] ?? ''}'),
            if (list.isNotEmpty) Text('Pogođeno: $list'),
            Text((c['systemNote'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _lessonCard(Map<String, dynamic> h) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text((h['peerName'] ?? '').toString()),
        subtitle: Text(
          '${h['similarityNote'] ?? ''}\n'
          'Status: ${h['peerStatus'] ?? ''} · Rizik: ${h['peerRiskLevel'] ?? ''}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _cpSuggestion(Map<String, dynamic> x) {
    return ListTile(
      leading: const Icon(Icons.tune),
      title: Text((x['trigger'] ?? '').toString()),
      subtitle: Text((x['suggestion'] ?? '').toString()),
    );
  }

  Widget _predictiveLine(Map<String, dynamic> x) {
    return ListTile(
      leading: const Icon(Icons.insights_outlined),
      title: Text((x['message'] ?? '').toString()),
    );
  }

  Widget _redTeamQ(Map<String, dynamic> q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((q['q'] ?? '').toString()),
                Text(
                  (q['aim'] ?? '').toString(),
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatmap(BuildContext context, DevelopmentLaunchIntelligenceResult d) {
    Color cell(int level) {
      switch (level.clamp(0, 3)) {
        case 0:
          return Colors.green.shade100;
        case 1:
          return Colors.lime.shade100;
        case 2:
          return Colors.orange.shade100;
        default:
          return Colors.red.shade100;
      }
    }

    final keys = d.heatmapLevels.keys.toList()..sort();
    if (keys.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.heatmapLegend.isNotEmpty)
          Text(
            d.heatmapLegend.join(' → '),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: keys.map((k) {
            final lv = d.heatmapLevels[k] ?? 0;
            return Chip(
              label: Text('$k: $lv'),
              backgroundColor: cell(lv),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _threadStep(Map<String, dynamic> s) {
    final ok = s['ok'] == true;
    return ListTile(
      dense: true,
      leading: Icon(ok ? Icons.check_circle_outline : Icons.radio_button_unchecked),
      title: Text((s['label'] ?? '').toString()),
      subtitle: (s['note'] != null && (s['note'] as String).isNotEmpty)
          ? Text(s['note'] as String)
          : null,
    );
  }
}
