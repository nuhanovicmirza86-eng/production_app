import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/development_portfolio_supplier_rollups.dart';
import '../models/development_project_model.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_help_texts.dart';
import '../utils/development_portfolio_stats.dart';
import '../screens/development_portfolio_supplier_detail_screen.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';

/// Vizualni pregled portfelja: KPI kartice, raspodjela po Gate-u, životni ciklus, zdravlje.
class DevelopmentPortfolioAnalyticsDashboard extends StatelessWidget {
  const DevelopmentPortfolioAnalyticsDashboard({
    super.key,
    required this.projects,
    this.illustrationMode = false,
    this.onOpenProject,
    this.supplierKpis,
    this.companyData,
  });

  final List<DevelopmentProjectModel> projects;
  /// Kad nema zapisa u Firestoreu — prikaz synthetic podataka + traka upozorenja.
  final bool illustrationMode;
  /// Za brzi skok u detalj projekta → tab Dobavljači (samo stvarni projekti).
  final void Function(DevelopmentProjectModel p)? onOpenProject;
  /// Agregat dobavljača kroz portfelj (null dok se učitava ili nije tražen).
  final PortfolioSupplierKpiSnapshot? supplierKpis;
  /// Za puni pregled dobavljača; ako je null, kartica dobavljača pada na [onOpenProject].
  final Map<String, dynamic>? companyData;

  @override
  Widget build(BuildContext context) {
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

    final activeNpi = DevelopmentPortfolioStats.countActiveNpi(projects);
    final byGate = DevelopmentPortfolioStats.countsByGate(projects);
    final life = DevelopmentPortfolioStats.lifecycleBuckets(projects);
    final avgProg = DevelopmentPortfolioStats.averageProgressPercent(projects);
    final healthBands = DevelopmentPortfolioStats.healthScoreBands(projects);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (illustrationMode) ...[
          Card(
            elevation: 0,
            color: scheme.tertiaryContainer.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.tertiary.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.layers_outlined, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ilustracija: u ovom opsegu (godina / pogon) nema stvarnih projekata u bazi. '
                      'KPI i grafovi ispod računaju se na sintetičkom skupu od ${projects.length} primjera — '
                      'da vidiš izgled portfelja. Promijeni filtar ili dodaj projekat; tab Projekti pokazuje listu.',
                      style: tt.bodySmall?.copyWith(
                        height: 1.35,
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.14),
                scheme.tertiaryContainer.withValues(alpha: 0.35),
                scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ],
            ),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_outlined, color: scheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          illustrationMode
                              ? 'Analitika (primjer podataka)'
                              : 'Analitika portfelja',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          illustrationMode
                              ? '${projects.length} sintetičkih projekata za prikaz grafova'
                              : '${projects.length} projekata u trenutnom opsegu',
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cross = w > 520 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: cross,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: cross == 2 ? 2.15 : 2.4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _KpiTile(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Prosj. zdravlje',
                        value: avgHealth == null ? '—' : avgHealth.toStringAsFixed(0),
                        unit: '/100',
                        tint: scheme.primary,
                        scheme: scheme,
                      ),
                      _KpiTile(
                        icon: Icons.play_circle_outline,
                        label: 'U NPI toku',
                        value: '$activeNpi',
                        unit: 'aktivno',
                        tint: const Color(0xFF2E7D32),
                        scheme: scheme,
                      ),
                      _KpiTile(
                        icon: Icons.trending_up,
                        label: 'Prosj. napredak',
                        value: avgProg == null ? '—' : avgProg.toStringAsFixed(0),
                        unit: '%',
                        tint: scheme.tertiary,
                        scheme: scheme,
                      ),
                      _KpiTile(
                        icon: Icons.warning_amber_rounded,
                        label: 'Rizik / health <60',
                        value: '$criticalRisk / $below60',
                        unit: 'visok rizik / nisko zdr.',
                        tint: scheme.error,
                        scheme: scheme,
                      ),
                      _KpiTile(
                        icon: Icons.factory_outlined,
                        label: 'Release u proizvodnju',
                        value: '$released',
                        unit: 'od ${projects.length}',
                        tint: scheme.secondary,
                        scheme: scheme,
                      ),
                      _KpiTile(
                        icon: Icons.flag_outlined,
                        label: 'Dominantni Gate',
                        value: _dominantGateLabel(byGate),
                        unit: 'najčešći',
                        tint: scheme.primary,
                        scheme: scheme,
                        trailing: OoeInfoIcon(
                          tooltip: DevelopmentHelpTexts.dominantGateTooltip,
                          dialogTitle: DevelopmentHelpTexts.dominantGateTitle,
                          dialogBody: DevelopmentHelpTexts.dominantGateBody,
                          iconSize: 16,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (supplierKpis != null &&
            !illustrationMode &&
            (supplierKpis!.totalLinks > 0 || supplierKpis!.rollups.isNotEmpty)) ...[
          const SizedBox(height: 16),
          _SupplierPortfolioKpiSection(
            snapshot: supplierKpis!,
            scheme: scheme,
            tt: tt,
          ),
        ],
        const SizedBox(height: 16),
        _Panel(
          title: 'Raspodjela po Stage-Gate fazi',
          subtitle: 'Broj projekata na svakom trenutnom Gate-u',
          icon: Icons.equalizer,
          scheme: scheme,
          tt: tt,
          trailing: OoeInfoIcon(
            tooltip: DevelopmentHelpTexts.stageGateChartTooltip,
            dialogTitle: DevelopmentHelpTexts.stageGateChartTitle,
            dialogBody: DevelopmentHelpTexts.stageGateChartBody,
            iconSize: 20,
          ),
          child: SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: _GateBarChart(
                byGate: byGate,
                color: scheme.primary,
                muted: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Životni ciklus u portfelju',
          subtitle: 'Tok · pažnja · zatvoreno',
          icon: Icons.pie_chart_outline,
          scheme: scheme,
          tt: tt,
          trailing: OoeInfoIcon(
            tooltip: DevelopmentHelpTexts.lifecyclePortfolioTooltip,
            dialogTitle: DevelopmentHelpTexts.lifecyclePortfolioTitle,
            dialogBody: DevelopmentHelpTexts.lifecyclePortfolioBody,
            iconSize: 20,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: _LifecycleFlowBar(
              pipeline: life.pipeline,
              attention: life.attention,
              done: life.done,
              other: life.other,
              scheme: scheme,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Distribucija „overall health”',
          subtitle: 'Pojasevi po projektu (KPI na dokumentu)',
          icon: Icons.stacked_bar_chart,
          scheme: scheme,
          tt: tt,
          trailing: OoeInfoIcon(
            tooltip: DevelopmentHelpTexts.overallHealthTooltip,
            dialogTitle: DevelopmentHelpTexts.overallHealthTitle,
            dialogBody: DevelopmentHelpTexts.overallHealthBody,
            iconSize: 20,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: _HealthBandChart(
              low: healthBands['low'] ?? 0,
              medium: healthBands['medium'] ?? 0,
              high: healthBands['high'] ?? 0,
              na: healthBands['na'] ?? 0,
              scheme: scheme,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SuppliersPortfolioPanel(
          illustrationMode: illustrationMode,
          projects: projects,
          onOpenProject: onOpenProject,
          supplierKpis: supplierKpis,
          companyData: companyData,
          scheme: scheme,
          tt: tt,
        ),
      ],
    );
  }

  static String _dominantGateLabel(Map<String, int> byGate) {
    final d = DevelopmentPortfolioStats.dominantGate(byGate);
    if (d == null || d.isEmpty) return '—';
    return d;
  }
}

class _SupplierPortfolioKpiSection extends StatelessWidget {
  const _SupplierPortfolioKpiSection({
    required this.snapshot,
    required this.scheme,
    required this.tt,
  });

  final PortfolioSupplierKpiSnapshot snapshot;
  final ColorScheme scheme;
  final TextTheme tt;

  static String _fmtAvg(double? x) =>
      x == null ? '—' : x.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.secondary.withValues(alpha: 0.12),
            scheme.primary.withValues(alpha: 0.1),
            scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: scheme.secondary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dobavljači u portfelju',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Agregat kroz sve projekte u trenutnom filtru',
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              OoeInfoIcon(
                tooltip: DevelopmentHelpTexts.portfolioSuppliersAggregateTooltip,
                dialogTitle: DevelopmentHelpTexts.portfolioSuppliersAggregateTitle,
                dialogBody: DevelopmentHelpTexts.portfolioSuppliersAggregateBody,
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cross = w > 520 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cross,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cross == 2 ? 2.15 : 2.35,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _KpiTile(
                    icon: Icons.groups_outlined,
                    label: 'Jedinstveni dobavljači',
                    value: '${snapshot.uniqueSupplierNames}',
                    unit: 'grupa po nazivu',
                    tint: scheme.secondary,
                    scheme: scheme,
                  ),
                  _KpiTile(
                    icon: Icons.hub_outlined,
                    label: 'Veze projekt–dobavljač',
                    value: '${snapshot.totalLinks}',
                    unit: 'zapisi u portfelju',
                    tint: scheme.primary,
                    scheme: scheme,
                  ),
                  _KpiTile(
                    icon: Icons.verified_outlined,
                    label: 'Odobreno / odbijeno / ostalo',
                    value: '${snapshot.approvedLinks} · ${snapshot.rejectedLinks} · ${snapshot.pendingLinks}',
                    unit: 'po zapisu',
                    tint: const Color(0xFF2E7D32),
                    scheme: scheme,
                  ),
                  _KpiTile(
                    icon: Icons.star_outline,
                    label: 'Prosjek Q · D · C',
                    value:
                        '${_fmtAvg(snapshot.avgQuality)} · ${_fmtAvg(snapshot.avgDelivery)} · ${_fmtAvg(snapshot.avgPrice)}',
                    unit: '1–5 gdje je ocijenjeno',
                    tint: scheme.tertiary,
                    scheme: scheme,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuppliersPortfolioPanel extends StatelessWidget {
  const _SuppliersPortfolioPanel({
    required this.illustrationMode,
    required this.projects,
    required this.onOpenProject,
    required this.supplierKpis,
    required this.companyData,
    required this.scheme,
    required this.tt,
  });

  final bool illustrationMode;
  final List<DevelopmentProjectModel> projects;
  final void Function(DevelopmentProjectModel p)? onOpenProject;
  final PortfolioSupplierKpiSnapshot? supplierKpis;
  final Map<String, dynamic>? companyData;
  final ColorScheme scheme;
  final TextTheme tt;

  DevelopmentProjectModel? _pickProjectForRollup(PortfolioSupplierRollup r) {
    DevelopmentProjectModel? completedPick;
    for (final x in r.items) {
      final s = x.project.status.trim();
      if (s == DevelopmentProjectStatuses.completed ||
          s == DevelopmentProjectStatuses.closed ||
          s == DevelopmentProjectStatuses.cancelled) {
        completedPick ??= x.project;
        continue;
      }
      return x.project;
    }
    return completedPick ?? (r.items.isEmpty ? null : r.items.first.project);
  }

  @override
  Widget build(BuildContext context) {
    final showRealLinks =
        !illustrationMode && onOpenProject != null && projects.isNotEmpty;
    final rollups = supplierKpis?.rollups ?? const <PortfolioSupplierRollup>[];
    final showRollupList = !illustrationMode &&
        rollups.isNotEmpty &&
        (companyData != null || onOpenProject != null);

    return _Panel(
      title: 'Vanjski dobavljači (IATF 8.4)',
      subtitle: showRollupList
          ? (companyData != null
              ? 'Tap — puni pregled dobavljača na svim projektima; u projektu otvara tab Dobavljači.'
              : 'Ocjene i status po dobavljaču; tap otvara projekt (detalj → tab Dobavljači).')
          : showRealLinks
              ? 'Brzi skok na projekt — puni podaci u tabu Dobavljači u detalju.'
              : 'U aplikaciji: detalj projekta → tab Dobavljači (status, rokovi, ocjene).',
      icon: Icons.local_shipping_outlined,
      scheme: scheme,
      tt: tt,
      trailing: OoeInfoIcon(
        tooltip: DevelopmentHelpTexts.iatf84Tooltip,
        dialogTitle: DevelopmentHelpTexts.iatf84Title,
        dialogBody: DevelopmentHelpTexts.iatf84Body,
        iconSize: 20,
      ),
      child: showRollupList
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rollups.take(14)) ...[
                  _SupplierRollupTile(
                    rollup: r,
                    scheme: scheme,
                    tt: tt,
                    companyData: companyData,
                    onOpenFallback: onOpenProject == null
                        ? null
                        : () {
                            final p = _pickProjectForRollup(r);
                            if (p != null) onOpenProject!(p);
                          },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            )
          : showRealLinks
              ? Column(
                  children: [
                    for (final p in projects.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.chevron_right, color: scheme.primary),
                        title: Text(
                          p.projectCode,
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p.projectName}\nOtvori detalj → tab „Dobavljači”',
                          style: tt.bodySmall?.copyWith(height: 1.3),
                        ),
                        isThreeLine: true,
                        onTap: () => onOpenProject!(p),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primjer evidencije (samo uz ilustraciju — nisu zapis u bazi):',
                      style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    _demoSupplierTile(
                      scheme,
                      tt,
                      'Werkzeugbau Müller — alatnica',
                      'Odobren • rok kalibracije: 14 dana',
                      Icons.precision_manufacturing_outlined,
                    ),
                    _demoSupplierTile(
                      scheme,
                      tt,
                      'ChemPoly d.o.o. — granulat',
                      'U procjeni • IATF 8.4 trag aktivan',
                      Icons.inventory_2_outlined,
                    ),
                    _demoSupplierTile(
                      scheme,
                      tt,
                      'MetroLog transport',
                      'Ugovoreno • dostava uzoraka G5',
                      Icons.local_shipping_outlined,
                    ),
                  ],
                ),
    );
  }

  static Widget _demoSupplierTile(
    ColorScheme scheme,
    TextTheme tt,
    String title,
    String sub,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: ListTile(
          leading: Icon(icon, color: scheme.primary),
          title: Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: tt.bodySmall),
        ),
      ),
    );
  }
}

class _SupplierRollupTile extends StatelessWidget {
  const _SupplierRollupTile({
    required this.rollup,
    required this.scheme,
    required this.tt,
    required this.companyData,
    required this.onOpenFallback,
  });

  final PortfolioSupplierRollup rollup;
  final ColorScheme scheme;
  final TextTheme tt;
  final Map<String, dynamic>? companyData;
  final VoidCallback? onOpenFallback;

  @override
  Widget build(BuildContext context) {
    final av = rollup.averageRatings();
    final hint = rollup.problemHint();
    String fmt(double? x) => x == null ? '—' : x.toStringAsFixed(1);
    final statusLine = rollup.allApprovedEverywhere
        ? 'Svi zapisi odobreni'
        : rollup.hasRejected
            ? 'Ima odbijenih ili visokog vanjskog rizika'
            : rollup.hasPendingOrDraft
                ? 'U procjeni / nacrt / uvjetno'
                : 'Status u detalju projekta';

    final firstDelivery = rollup.items.isEmpty
        ? null
        : DevelopmentDisplay.supplierDeliveryDescription(
            rollup.items.first.supplier,
            singleLine: true,
            showPlaceholder: false,
          );
    final projectBits = <String>[];
    for (final x in rollup.items.take(4)) {
      final code = x.project.projectCode.trim();
      final appr = DevelopmentDisplay.supplierApprovalLabel(x.supplier.approvalStatus);
      final bit = code.isEmpty
          ? '${x.project.projectName}: $appr'
          : '$code: $appr';
      projectBits.add(bit);
    }
    if (rollup.items.length > 4) {
      projectBits.add('+${rollup.items.length - 4} …');
    }

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (companyData != null) {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => DevelopmentPortfolioSupplierDetailScreen(
                  companyData: companyData!,
                  rollup: rollup,
                ),
              ),
            );
          } else {
            onOpenFallback?.call();
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rollup.displayName,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    companyData != null
                        ? Icons.open_in_full_outlined
                        : Icons.chevron_right,
                    size: 22,
                    color: scheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Projekti: ${rollup.activeProjectCount} u tijeku · ${rollup.doneProjectCount} završeno (${rollup.projectCount} veza)',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Prosjek Q·D·C: ${fmt(av.q)} · ${fmt(av.d)} · ${fmt(av.p)} · $statusLine',
                style: tt.bodySmall?.copyWith(height: 1.3),
              ),
              if (projectBits.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  projectBits.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (firstDelivery != null && firstDelivery.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Isporuka (jedan zapis): $firstDelivery',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (hint != null && hint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: scheme.error.withValues(alpha: 0.92),
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.tint,
    required this.scheme,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color tint;
  final ColorScheme scheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.scheme,
    required this.tt,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ColorScheme scheme;
  final TextTheme tt;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GateBarChart extends StatelessWidget {
  const _GateBarChart({
    required this.byGate,
    required this.color,
    required this.muted,
  });

  final Map<String, int> byGate;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    if (byGate.isEmpty) {
      return Center(
        child: Text(
          'Nema podataka o Gate-u.',
          style: TextStyle(color: muted),
        ),
      );
    }
    final keys = DevelopmentPortfolioStats.gatesSorted(byGate);
    return CustomPaint(
      painter: _GateBarChartPainter(
        entries: [for (final k in keys) (k, byGate[k] ?? 0)],
        barColor: color,
        labelColor: muted,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _GateBarChartPainter extends CustomPainter {
  _GateBarChartPainter({
    required this.entries,
    required this.barColor,
    required this.labelColor,
  });

  final List<(String, int)> entries;
  final Color barColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final maxV = entries.map((e) => e.$2).reduce(math.max).toDouble();
    final maxH = math.max(maxV, 1.0);
    final n = entries.length;
    final gap = 6.0;
    final labelH = 22.0;
    final chartH = size.height - labelH - 8;
    final barW = (size.width - gap * (n - 1)) / n;

    for (var i = 0; i < n; i++) {
      final label = entries[i].$1;
      final v = entries[i].$2;
      final x = i * (barW + gap);
      final h = (v / maxH) * chartH * 0.92;
      final top = chartH - h + 4;

      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barW, h),
        const Radius.circular(6),
      );
      final base = HSLColor.fromColor(barColor);
      final t = n <= 1 ? 0.0 : i / (n - 1);
      final blended = base
          .withHue((base.hue + t * 28) % 360)
          .withSaturation(math.min(0.85, base.saturation + 0.1))
          .withLightness(math.min(0.62, base.lightness + 0.04 * t))
          .toColor();

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            blended.withValues(alpha: 0.45),
            blended,
          ],
        ).createShader(Rect.fromLTWH(x, top, barW, h))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(r, paint);

      final border = Paint()
        ..color = blended.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(r, border);

      final tp = TextPainter(
        text: TextSpan(
          text: label == '—' ? '?' : label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barW + 8);
      tp.paint(
        canvas,
        Offset(x + (barW - tp.width) / 2, chartH + 6),
      );

      if (v > 0) {
        final valPainter = TextPainter(
          text: TextSpan(
            text: '$v',
            style: TextStyle(
              color: labelColor.withValues(alpha: 0.95),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        valPainter.paint(
          canvas,
          Offset(
            x + (barW - valPainter.width) / 2,
            math.max(top - 16, 2),
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GateBarChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.barColor != barColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _LifecycleFlowBar extends StatelessWidget {
  const _LifecycleFlowBar({
    required this.pipeline,
    required this.attention,
    required this.done,
    required this.other,
    required this.scheme,
  });

  final int pipeline;
  final int attention;
  final int done;
  final int other;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final total = pipeline + attention + done + other;
    if (total == 0) {
      return Text('Nema projekata.', style: tt.bodySmall);
    }
    Widget segment(String label, int n, Color c, IconData icon) {
      final flex = math.max(n, 0);
      if (flex == 0) return const SizedBox.shrink();
      return Expanded(
        flex: flex,
        child: Tooltip(
          message: '$label: $n',
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  c.withValues(alpha: 0.65),
                  c,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                  const SizedBox(width: 4),
                  Text(
                    '$n',
                    style: tt.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            segment(
              'U toku (NPI)',
              pipeline,
              const Color(0xFF1565C0),
              Icons.play_circle_outline,
            ),
            segment(
              'Treba pažnje',
              attention,
              scheme.error,
              Icons.priority_high,
            ),
            segment(
              'Završeno',
              done,
              const Color(0xFF2E7D32),
              Icons.check_circle_outline,
            ),
            segment(
              'Ostalo',
              other,
              scheme.outline,
              Icons.more_horiz,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(color: const Color(0xFF1565C0), label: 'NPI tok ($pipeline)'),
            _LegendDot(color: scheme.error, label: 'Pažnja ($attention)'),
            _LegendDot(color: const Color(0xFF2E7D32), label: 'Završeno ($done)'),
            if (other > 0)
              _LegendDot(color: scheme.outline, label: 'Ostalo ($other)'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HealthBandChart extends StatelessWidget {
  const _HealthBandChart({
    required this.low,
    required this.medium,
    required this.high,
    required this.na,
    required this.scheme,
  });

  final int low;
  final int medium;
  final int high;
  final int na;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final total = low + medium + high + na;
    if (total == 0) {
      return Text('Nema projekata.', style: tt.bodySmall);
    }

    Widget bar(String label, int n, Color c, String range) {
      if (n <= 0) return const SizedBox.shrink();
      final frac = n / total;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$label ($range)',
                    style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$n',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: frac.clamp(0.02, 1.0),
                minHeight: 12,
                backgroundColor: scheme.surfaceContainerHighest,
                color: c,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar('Kritično / nisko zdravlje', low, scheme.error, '< 60'),
        bar('Srednje', medium, scheme.tertiary, '60 – 79'),
        bar('Dobro', high, const Color(0xFF2E7D32), '≥ 80'),
        if (na > 0)
          bar('Bez KPI', na, scheme.outline, 'n/a'),
      ],
    );
  }
}
