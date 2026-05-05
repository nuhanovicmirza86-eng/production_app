import 'package:flutter/material.dart';

import '../data/development_portfolio_supplier_rollups.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';
import '../screens/development_portfolio_supplier_detail_screen.dart';
import '../screens/development_project_details_screen.dart';
import '../widgets/development_supplier_editor_dialog.dart';

enum _SupplierPortfolioFilter { all, fullyApproved, needsAttention }

/// Portfelj — vanjski dobavljači kroz sve projekte u opsegu (agregat + skok u detalj).
class DevelopmentPortfolioSuppliersTab extends StatefulWidget {
  const DevelopmentPortfolioSuppliersTab({
    super.key,
    required this.companyData,
    required this.projects,
    required this.onOpenProject,
  });

  final Map<String, dynamic> companyData;
  final List<DevelopmentProjectModel> projects;
  final void Function(DevelopmentProjectModel p) onOpenProject;

  @override
  State<DevelopmentPortfolioSuppliersTab> createState() =>
      _DevelopmentPortfolioSuppliersTabState();
}

class _DevelopmentPortfolioSuppliersTabState
    extends State<DevelopmentPortfolioSuppliersTab> {
  final DevelopmentProjectService _service = DevelopmentProjectService();
  Future<List<PortfolioSupplierRollup>>? _rollupFuture;
  _SupplierPortfolioFilter _filter = _SupplierPortfolioFilter.all;

  bool get _canMutate => DevelopmentPermissions.canMutateDevelopmentTasks(
        role: widget.companyData['role']?.toString(),
        companyData: widget.companyData,
      );

  static bool _sameProjectIds(
    List<DevelopmentProjectModel> a,
    List<DevelopmentProjectModel> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant DevelopmentPortfolioSuppliersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameProjectIds(oldWidget.projects, widget.projects)) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    if (widget.projects.isEmpty) {
      setState(() {
        _rollupFuture = Future.value([]);
      });
      return;
    }
    setState(() {
      _rollupFuture =
          PortfolioSupplierRollup.loadForProjects(widget.projects, _service);
    });
  }

  void _openSupplierFullDetail(PortfolioSupplierRollup r) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DevelopmentPortfolioSupplierDetailScreen(
          companyData: widget.companyData,
          rollup: r,
        ),
      ),
    );
  }

  List<PortfolioSupplierRollup> _applyFilter(List<PortfolioSupplierRollup> all) {
    switch (_filter) {
      case _SupplierPortfolioFilter.all:
        return all;
      case _SupplierPortfolioFilter.fullyApproved:
        return all.where((r) => r.allApprovedEverywhere).toList();
      case _SupplierPortfolioFilter.needsAttention:
        return all
            .where((r) => r.hasRejected || r.hasPendingOrDraft)
            .toList();
    }
  }

  Future<void> _openPickProjectForNewSupplier() async {
    DevelopmentProjectModel? chosen;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Na kojem projektu kreiraš dobavljača?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Zapis dobavljača spada u odabrani NPI projekt. '
                  'Kasnije ga vidiš i ovdje u agregatu po nazivu.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 12),
                for (final p in widget.projects)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(p.projectCode),
                    subtitle: Text(
                      p.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      chosen = p;
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
          ],
        );
      },
    );
    if (chosen == null || !mounted) return;
    final proj = chosen!;
    final ok = await showDevelopmentSupplierEditorDialog(
      context,
      companyData: widget.companyData,
      project: proj,
      supplier: null,
    );
    if (ok && mounted) _scheduleLoad();
  }

  Widget _buildSuppliersContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (widget.projects.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.local_shipping_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Nema projekata u opsegu',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Dobavljače dodaješ u detalju projekta (tab Dobavljači). '
            'Ovdje će se pojaviti agregat kad u portfelju postoje projekti.',
            style: tt.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      );
    }

    return FutureBuilder<List<PortfolioSupplierRollup>>(
      future: _rollupFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Dobavljači: ${snap.error}',
                style: TextStyle(color: scheme.error),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rollups = snap.data!;
        final filtered = _applyFilter(rollups);

        var totalLinks = 0;
        var appr = 0;
        var rej = 0;
        var pend = 0;
        for (final r in rollups) {
          for (final x in r.items) {
            totalLinks++;
            final a = x.supplier.approvalStatus;
            if (a == DevelopmentSupplierApprovalStatuses.approved) {
              appr++;
            } else if (a == DevelopmentSupplierApprovalStatuses.rejected) {
              rej++;
            } else {
              pend++;
            }
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            final f = PortfolioSupplierRollup.loadForProjects(
              widget.projects,
              _service,
            );
            setState(() {
              _rollupFuture = f;
            });
            await f;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sažetak portfelja',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _miniStat(
                            scheme,
                            tt,
                            'Jedinstvenih dobavljača',
                            '${rollups.length}',
                          ),
                          _miniStat(
                            scheme,
                            tt,
                            'Veza projekt–dobavljač',
                            '$totalLinks',
                          ),
                          _miniStat(
                            scheme,
                            tt,
                            'Odobreno',
                            '$appr',
                            fg: scheme.primary,
                          ),
                          _miniStat(
                            scheme,
                            tt,
                            'Odbijeno',
                            '$rej',
                            fg: scheme.error,
                          ),
                          _miniStat(
                            scheme,
                            tt,
                            'U tijeku / čeka',
                            '$pend',
                            fg: scheme.tertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Novi dobavljač: donji gumb — odaberi projekt, zatim forma (uloga, opseg rada, dijelovi, zadaci). '
                        'Lista je po dobavljaču; ispod svakog — pojedinačni projekti i što točno isporučuje na tom projektu. '
                        'Isto iz detalja projekta → tab Dobavljači.',
                        style: tt.bodySmall?.copyWith(
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Filter',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Svi'),
                    selected: _filter == _SupplierPortfolioFilter.all,
                    onSelected: (_) =>
                        setState(() => _filter = _SupplierPortfolioFilter.all),
                  ),
                  ChoiceChip(
                    label: const Text('Potpuno odobreno'),
                    selected: _filter == _SupplierPortfolioFilter.fullyApproved,
                    onSelected: (_) => setState(
                      () => _filter = _SupplierPortfolioFilter.fullyApproved,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Treba pažnje'),
                    selected: _filter == _SupplierPortfolioFilter.needsAttention,
                    onSelected: (_) => setState(
                      () => _filter = _SupplierPortfolioFilter.needsAttention,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nema stavki za ovaj filter.',
                    style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                ...filtered.map((r) {
                  final avg = r.averageRatings();
                  final qStr = avg.q == null ? '—' : avg.q!.toStringAsFixed(1);
                  final dStr = avg.d == null ? '—' : avg.d!.toStringAsFixed(1);
                  final pStr = avg.p == null ? '—' : avg.p!.toStringAsFixed(1);
                  final hint = r.problemHint();
                  final sampleDelivery = () {
                    for (final x in r.items) {
                      final t = DevelopmentDisplay.supplierDeliveryDescription(
                        x.supplier,
                        singleLine: true,
                        showPlaceholder: false,
                      );
                      if (t.isNotEmpty) return t;
                    }
                    return null;
                  }();
                  final subLines = <String>[
                    '${r.projectCount} proj(e)k(a) · '
                        'aktivnih: ${r.activeProjectCount}, završenih: ${r.doneProjectCount}',
                    'Ocjene (Q/R/C): $qStr / $dStr / $pStr',
                  ];
                  if (sampleDelivery != null) {
                    subLines.add('Isporuka (iz zapisa): $sampleDelivery');
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.38),
                      ),
                    ),
                    child: ExpansionTile(
                      leading: IconButton(
                        tooltip: 'Puni pregled kroz sve projekte',
                        icon: Icon(Icons.open_in_full_outlined, color: scheme.primary),
                        onPressed: () => _openSupplierFullDetail(r),
                      ),
                      title: Text(
                        r.displayName,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        subLines.join('\n'),
                        style: tt.bodySmall?.copyWith(height: 1.3),
                      ),
                      children: [
                        if (hint != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Napomena: $hint',
                                style: tt.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        for (final x in r.items)
                          ListTile(
                            leading: Icon(
                              Icons.chevron_right,
                              color: scheme.primary,
                            ),
                            title: Text(
                              x.project.projectCode,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                x.project.projectName,
                                '',
                                'Što dostavlja na ovom projektu:',
                                DevelopmentDisplay.supplierDeliveryDescription(
                                  x.supplier,
                                ),
                                '',
                                '${DevelopmentDisplay.projectStatusLabel(x.project.status)} · '
                                    '${DevelopmentDisplay.supplierApprovalLabel(x.supplier.approvalStatus)}',
                                'Gate: ${x.project.currentGate.trim().isEmpty ? '—' : x.project.currentGate} · '
                                    'Q:${x.supplier.qualityRating ?? '—'} '
                                    'R:${x.supplier.deliveryRating ?? '—'} '
                                    'C:${x.supplier.priceRating ?? '—'}',
                              ].join('\n'),
                              style: tt.bodySmall?.copyWith(height: 1.3),
                            ),
                            trailing: _canMutate
                                ? IconButton(
                                    tooltip: 'Uredi sve podatke dobavljača',
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: scheme.secondary,
                                    ),
                                    onPressed: () async {
                                      final ok =
                                          await showDevelopmentSupplierEditorDialog(
                                        context,
                                        companyData: widget.companyData,
                                        project: x.project,
                                        supplier: x.supplier,
                                      );
                                      if (ok && mounted) _scheduleLoad();
                                    },
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => DevelopmentProjectDetailsScreen(
                                    companyData: widget.companyData,
                                    projectId: x.project.id,
                                    initialTabIndex: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fab = widget.projects.isNotEmpty && _canMutate
        ? FloatingActionButton.extended(
            onPressed: _openPickProjectForNewSupplier,
            icon: const Icon(Icons.add),
            label: const Text('Novi dobavljač'),
          )
        : null;
    return Scaffold(
      body: _buildSuppliersContent(context),
      floatingActionButton: fab,
    );
  }

  static Widget _miniStat(
    ColorScheme scheme,
    TextTheme tt,
    String label,
    String value, {
    Color? fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
