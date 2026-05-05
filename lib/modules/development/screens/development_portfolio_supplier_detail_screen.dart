import 'package:flutter/material.dart';

import '../data/development_portfolio_supplier_rollups.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_display.dart';
import '../utils/development_permissions.dart';
import '../widgets/development_supplier_editor_dialog.dart';
import 'development_project_details_screen.dart';

/// Pregled jednog dobavljača kroz **sve** projekte u portfelju (bez odabira jednog projekta prvo).
class DevelopmentPortfolioSupplierDetailScreen extends StatefulWidget {
  const DevelopmentPortfolioSupplierDetailScreen({
    super.key,
    required this.companyData,
    required this.rollup,
  });

  final Map<String, dynamic> companyData;
  final PortfolioSupplierRollup rollup;

  @override
  State<DevelopmentPortfolioSupplierDetailScreen> createState() =>
      _DevelopmentPortfolioSupplierDetailScreenState();
}

class _DevelopmentPortfolioSupplierDetailScreenState
    extends State<DevelopmentPortfolioSupplierDetailScreen> {
  late PortfolioSupplierRollup _rollup;
  final DevelopmentProjectService _service = DevelopmentProjectService();

  @override
  void initState() {
    super.initState();
    _rollup = widget.rollup;
  }

  bool get _canMutate => DevelopmentPermissions.canMutateDevelopmentTasks(
        role: widget.companyData['role']?.toString(),
        companyData: widget.companyData,
      );

  Future<void> _reloadRollup() async {
    final projects = <String, DevelopmentProjectModel>{
      for (final x in _rollup.items) x.project.id: x.project,
    }.values.toList();
    if (projects.isEmpty) return;

    final list = await PortfolioSupplierRollup.loadForProjects(projects, _service);
    final key = _rollup.groupKey;
    PortfolioSupplierRollup? next;
    for (final r in list) {
      if (r.groupKey == key) next = r;
    }
    next ??= () {
      final name = _rollup.displayName.trim().toLowerCase();
      for (final r in list) {
        if (r.displayName.trim().toLowerCase() == name) return r;
      }
      return null;
    }();
    next ??= () {
      final pairs = <String>{
        for (final x in _rollup.items) '${x.project.id}::${x.supplier.id}',
      };
      for (final r in list) {
        for (final it in r.items) {
          if (pairs.contains('${it.project.id}::${it.supplier.id}')) return r;
        }
      }
      return null;
    }();

    if (next != null && mounted) {
      setState(() => _rollup = next!);
    }
  }

  static int _statusSort(String status) {
    final s = status.trim();
    if (s == DevelopmentProjectStatuses.completed ||
        s == DevelopmentProjectStatuses.closed ||
        s == DevelopmentProjectStatuses.cancelled) {
      return 2;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final avg = _rollup.averageRatings();
    final hint = _rollup.problemHint();
    final items = [..._rollup.items]..sort((a, b) {
        final c =
            _statusSort(a.project.status).compareTo(_statusSort(b.project.status));
        if (c != 0) return c;
        return a.project.projectCode.compareTo(b.project.projectCode);
      });

    final statusLine = _rollup.allApprovedEverywhere
        ? 'Svi zapisi odobreni'
        : _rollup.hasRejected
            ? 'Postoji odbijen ili visok vanjski rizik'
            : _rollup.hasPendingOrDraft
                ? 'Procjena / nacrt / uvjetno'
                : 'Pregledaj statuse po projektu';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _rollup.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portfelj — sažetak',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        scheme,
                        'Veza: ${_rollup.projectCount}',
                        Icons.hub_outlined,
                      ),
                      _chip(
                        scheme,
                        'Aktivnih proj.: ${_rollup.activeProjectCount}',
                        Icons.play_circle_outline,
                      ),
                      _chip(
                        scheme,
                        'Završenih: ${_rollup.doneProjectCount}',
                        Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusLine,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prosjek ocjena (Q · D · C): '
                    '${_fmt(avg.q)} · ${_fmt(avg.d)} · ${_fmt(avg.p)}',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (hint != null && hint.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Napomena / problem',
                      style: tt.labelMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_canMutate) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Podaci se uređuju po projektu (isti obavljač može imati različit zapis na svakom projektu). '
                      'Karticu projekta — gumb Uredi — sva polja.',
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Projekti (${items.length})',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap na karticu otvara projekat na tabu Dobavljači. '
            '${_canMutate ? 'Ikona olovke otvara puni uređivač.' : ''}',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 12),
          ...items.map((x) => _ProjectSupplierCard(
                companyData: widget.companyData,
                item: x,
                scheme: scheme,
                tt: tt,
                canEdit: _canMutate,
                onEditFull: !_canMutate
                    ? null
                    : () async {
                        final ok = await showDevelopmentSupplierEditorDialog(
                          context,
                          companyData: widget.companyData,
                          project: x.project,
                          supplier: x.supplier,
                        );
                        if (ok && mounted) await _reloadRollup();
                      },
              )),
        ],
      ),
    );
  }

  static String _fmt(double? x) => x == null ? '—' : x.toStringAsFixed(1);

  static Widget _chip(ColorScheme scheme, String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 18, color: scheme.primary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
    );
  }
}

class _ProjectSupplierCard extends StatelessWidget {
  const _ProjectSupplierCard({
    required this.companyData,
    required this.item,
    required this.scheme,
    required this.tt,
    required this.canEdit,
    required this.onEditFull,
  });

  final Map<String, dynamic> companyData;
  final SupplierOnProject item;
  final ColorScheme scheme;
  final TextTheme tt;
  final bool canEdit;
  final Future<void> Function()? onEditFull;

  @override
  Widget build(BuildContext context) {
    final p = item.project;
    final s = item.supplier;
    final note = (s.evaluationNote ?? '').trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.38)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => DevelopmentProjectDetailsScreen(
                companyData: companyData,
                projectId: p.id,
                initialTabIndex: 1,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.projectCode,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  if (canEdit && onEditFull != null)
                    IconButton(
                      tooltip: 'Uredi sve podatke dobavljača',
                      icon: Icon(Icons.edit_outlined, color: scheme.secondary),
                      onPressed: () async {
                        await onEditFull!();
                      },
                    ),
                  Icon(Icons.open_in_new, size: 20, color: scheme.primary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                p.projectName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                '${DevelopmentDisplay.projectStatusLabel(p.status)} · '
                'Gate ${p.currentGate.trim().isEmpty ? '—' : p.currentGate}',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Što dostavlja na ovom projektu',
                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                DevelopmentDisplay.supplierDeliveryDescription(s),
                style: tt.bodySmall?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                '${DevelopmentDisplay.supplierCategoryLabel(s.category)} · '
                '${DevelopmentDisplay.supplierApprovalLabel(s.approvalStatus)} · '
                'Rizik: ${DevelopmentDisplay.supplierExternalRiskLabel(s.externalRiskLevel)}',
                style: tt.bodySmall?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 6),
              Text(
                'Ocjene Q · D · C: '
                '${s.qualityRating ?? '—'} · ${s.deliveryRating ?? '—'} · ${s.priceRating ?? '—'}',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (s.dueDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Rok: ${s.dueDate!.toLocal().toString().split('.').first}',
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Evaluacija: $note',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
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
