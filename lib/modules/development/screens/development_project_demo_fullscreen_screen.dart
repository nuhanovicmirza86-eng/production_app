import 'package:flutter/material.dart';

import '../data/development_demo_sample_project.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_intelligence_glossary.dart';
import '../widgets/development_project_kpi_dashboard.dart';

/// Punoekranski **demo** NPI projekta (ilustrativni podaci, bez Firestorea / Callabla).
class DevelopmentProjectDemoFullscreenScreen extends StatelessWidget {
  const DevelopmentProjectDemoFullscreenScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  String get _companyId => (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (companyData['plantKey'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final p = buildDevelopmentDemoSampleProject(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    final demoDocs = buildDevelopmentDemoDocumentRows();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            pinned: true,
            stretch: true,
            leading: IconButton(
              tooltip: 'Zatvori',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Što je ovaj demo',
                icon: const Icon(Icons.info_outline),
                onPressed: () => DevelopmentIntelligenceGlossary.showInfoSheet(
                  context,
                  title: 'Demo NPI projekta',
                  body:
                      'Raspored blokova odgovara stvarnom detalju projekta iz portfelja: KPI i napredak, '
                      'Stage-Gate, status, kupac, dokumentacija (crteži, specifikacije, zahtjevi), tim, '
                      'Launch readiness i AI uvidi. '
                      'Sve je ilustrativno — nema zapisa u Firestoreu. '
                      'Na pravom projektu dokumenti su u Pregledu kao evidencija uz podkolekciju documents; '
                      'otvori projekt s liste da vidiš žive podatke i uređivanje.',
                ),
              ),
            ],
            title: const Text('Demo NPI projekta'),
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.9),
                      scheme.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(72, 28, 20, 24),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.projectName,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${p.projectCode} · ${p.businessYearLabel}',
                            style: tt.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                DevelopmentProjectKpiDashboard(
                  kpi: p.kpi,
                  progressPercent: p.progressPercent,
                ),
                const SizedBox(height: 20),
                _DemoSection(
                  title: 'Dokumenti (evidencija)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Na pravom projektu: metadata u aplikaciji (naslov, tip, status, Gate); '
                        'datoteke često na PDM, SharePointu ili drugoj poveznici. Ovdje je ilustrativna lista.',
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...demoDocs.map((d) {
                        final gate = (d.linkedGate ?? '').trim();
                        final sub = [
                          DevelopmentDisplay.documentTypeLabel(d.docType),
                          DevelopmentDisplay.documentStatusLabel(d.status),
                          if (gate.isNotEmpty) gate,
                        ].join(' · ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _demoDocIcon(d.docType),
                            color: scheme.primary,
                          ),
                          title: Text(d.title, style: tt.bodyMedium),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub, style: tt.bodySmall),
                              if ((d.externalRef ?? '').trim().isNotEmpty)
                                Text(
                                  d.externalRef!.trim(),
                                  style: tt.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: (d.externalRef ?? '').trim().isNotEmpty,
                        );
                      }),
                    ],
                  ),
                ),
                _DemoSection(
                  title: 'Stage-Gate (ilustracija)',
                  child: _GateTimeline(current: p.currentGate),
                ),
                const SizedBox(height: 12),
                _DemoSection(
                  title: 'Status i tijek',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _demoKv(context, 'Status', DevelopmentDisplay.projectStatusLabel(p.status)),
                      _demoKv(context, 'Tip', DevelopmentDisplay.projectTypeLabel(p.projectType)),
                      _demoKv(context, 'Gate', p.currentGate),
                      _demoKv(context, 'Prioritet', DevelopmentDisplay.projectPriorityLabel(p.priority)),
                      _demoKv(context, 'Rizik', DevelopmentDisplay.riskSeverityLabel(p.riskLevel)),
                    ],
                  ),
                ),
                _DemoSection(
                  title: 'Kupac / proizvod',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _demoKv(context, 'Kupac', p.customerName ?? '—'),
                      _demoKv(context, 'Proizvod', p.productName ?? '—'),
                      _demoKv(context, 'Šifra', p.productCode ?? '—'),
                    ],
                  ),
                ),
                _DemoSection(
                  title: 'Tim',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _demoKv(context, 'Voditelj', p.projectManagerName),
                      ...p.team.map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '• ${DevelopmentDisplay.teamProjectRoleLabel(m.projectRole)} — ${m.displayName}',
                            style: tt.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _DemoSection(
                  title: 'Launch readiness (mock)',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Operonix Launch Readiness Score',
                                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Odakle score u pravom projektu',
                              icon: const Icon(Icons.info_outline, size: 22),
                              onPressed: () => DevelopmentIntelligenceGlossary.showInfoSheet(
                                context,
                                title: 'Launch Readiness u demo-u',
                                body:
                                    'U pravom projektu score i poveznica na MES dolaze iz Launch Intelligence (Callable) '
                                    'uz podatke projekta i proizvodne naloge. Ovdje je samo brojka za izgled ekrana.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '78 / 100',
                          style: tt.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _DemoSection(
                  title: 'AI uvidi (mock)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.ai.riskPrediction.isNotEmpty)
                        Text(p.ai.riskPrediction, style: tt.bodyMedium),
                      if (p.ai.delayProbability != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Procjena kašnjenja (vj.): ${p.ai.delayProbability}',
                            style: tt.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _demoDocIcon(String docType) {
    switch (docType) {
      case DevelopmentDocumentTypes.drawing:
        return Icons.architecture_outlined;
      case DevelopmentDocumentTypes.spec:
        return Icons.article_outlined;
      case DevelopmentDocumentTypes.protocol:
        return Icons.science_outlined;
      case DevelopmentDocumentTypes.checklist:
        return Icons.fact_check_outlined;
      case DevelopmentDocumentTypes.certificate:
        return Icons.verified_outlined;
      case DevelopmentDocumentTypes.report:
        return Icons.assignment_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  static Widget _demoKv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _DemoSection extends StatelessWidget {
  const _DemoSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GateTimeline extends StatelessWidget {
  const _GateTimeline({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idxCurrent = DevelopmentGateCodes.ordered.indexOf(current);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < DevelopmentGateCodes.ordered.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: scheme.outline,
                ),
              ),
            _GateChip(
              label: DevelopmentGateCodes.ordered[i],
              state: i < idxCurrent
                  ? _GateVisualState.done
                  : i == idxCurrent
                      ? _GateVisualState.current
                      : _GateVisualState.upcoming,
            ),
          ],
        ],
      ),
    );
  }
}

enum _GateVisualState { done, current, upcoming }

class _GateChip extends StatelessWidget {
  const _GateChip({required this.label, required this.state});

  final String label;
  final _GateVisualState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    IconData? icon;
    switch (state) {
      case _GateVisualState.done:
        bg = scheme.primary.withValues(alpha: 0.2);
        fg = scheme.primary;
        icon = Icons.check_circle_outline;
      case _GateVisualState.current:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
        icon = Icons.trip_origin;
      case _GateVisualState.upcoming:
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.8);
        fg = scheme.onSurfaceVariant;
        icon = null;
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: icon != null
          ? Icon(icon, size: 18, color: fg)
          : null,
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      backgroundColor: bg,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
    );
  }
}
