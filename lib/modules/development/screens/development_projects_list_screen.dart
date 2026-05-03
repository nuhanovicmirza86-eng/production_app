import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/operational_business_year_context.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_intelligence_glossary.dart';
import '../utils/development_permissions.dart';
import '../utils/development_portfolio_stats.dart';
import '../widgets/development_demo_portfolio_project_card.dart';
import '../widgets/development_portfolio_ai_assistant_tab.dart';
import '../widgets/development_portfolio_command_center_tab.dart';
import '../widgets/development_portfolio_help_tab.dart';
import '../widgets/development_portfolio_suppliers_tab.dart';
import '../widgets/development_project_card.dart';
import 'development_project_create_screen.dart';
import 'development_project_demo_fullscreen_screen.dart';
import 'development_project_details_screen.dart';

enum _PortfolioLifecycle { all, pipeline, attention, done }

/// Portfelj NPI / Stage-Gate — enterprise prikaz prema arhitekturi modula Razvoj.
class DevelopmentProjectsListScreen extends StatefulWidget {
  const DevelopmentProjectsListScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<DevelopmentProjectsListScreen> createState() =>
      _DevelopmentProjectsListScreenState();
}

class _DevelopmentProjectsListScreenState
    extends State<DevelopmentProjectsListScreen> {
  final DevelopmentProjectService _service = DevelopmentProjectService();

  /// `null` = sve poslovne godine (portfelj). Inicijalno se postavlja na aktivnu godinu kad stigne stream.
  String? _selectedBusinessYearId;
  bool _fyHydrated = false;
  bool _fyUserTouched = false;

  /// Za admin/super_admin portfelj: `null` = svi pogoni; inače filtriraj [plantKey].
  String? _portfolioPlantKeyFilter;

  List<({String plantKey, String label})> _selectablePlants = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _fySub;

  /// Kesh za padajući izbor godine (iz streama `financial_years`).
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _fyDocs = [];

  bool _onlyMyProjects = false;
  _PortfolioLifecycle _lifecycle = _PortfolioLifecycle.all;
  /// `null` = svi Gate-ovi; inače `currentGate` (točno poklapanje).
  String? _filterGate;
  /// `null` = svi kupci; `''` = bez imenovanog kupca; inače puni naziv.
  String? _customerFilterName;

  /// Kad je `false`, dropdowni su sakriveni (tabovi odmah ispod kratkog sažetka).
  /// Po želji vlasnika: **[true] = prošireno (filter vidljiv) pri otvaranju ekrana.**
  bool _portfolioScopeExpanded = true;

  bool get _hasLocalFilters =>
      _onlyMyProjects ||
      _lifecycle != _PortfolioLifecycle.all ||
      (_filterGate != null && _filterGate!.trim().isNotEmpty) ||
      _customerFilterName != null;

  void _clearLocalFilters() {
    setState(() {
      _onlyMyProjects = false;
      _lifecycle = _PortfolioLifecycle.all;
      _filterGate = null;
      _customerFilterName = null;
    });
  }

  bool _matchesLifecycle(DevelopmentProjectModel p) {
    final s = p.status.trim();
    switch (_lifecycle) {
      case _PortfolioLifecycle.all:
        return true;
      case _PortfolioLifecycle.pipeline:
        return s == DevelopmentProjectStatuses.active ||
            s == DevelopmentProjectStatuses.approved ||
            s == DevelopmentProjectStatuses.proposed ||
            s == DevelopmentProjectStatuses.draft;
      case _PortfolioLifecycle.attention:
        return s == DevelopmentProjectStatuses.atRisk ||
            s == DevelopmentProjectStatuses.delayed ||
            s == DevelopmentProjectStatuses.onHold;
      case _PortfolioLifecycle.done:
        return s == DevelopmentProjectStatuses.completed ||
            s == DevelopmentProjectStatuses.closed ||
            s == DevelopmentProjectStatuses.cancelled;
    }
  }

  List<DevelopmentProjectModel> _applyPortfolioFilters(
    List<DevelopmentProjectModel> source,
  ) {
    var out = List<DevelopmentProjectModel>.from(source);
    final uid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (_onlyMyProjects && uid.isNotEmpty) {
      out = out
          .where((p) => DevelopmentPermissions.isUserOnProjectTeam(p, uid))
          .toList();
    }
    if (_lifecycle != _PortfolioLifecycle.all) {
      out = out.where(_matchesLifecycle).toList();
    }
    final g = (_filterGate ?? '').trim();
    if (g.isNotEmpty) {
      out = out.where((p) => p.currentGate.trim() == g).toList();
    }
    if (_customerFilterName != null) {
      final want = _customerFilterName!;
      if (want.isEmpty) {
        out = out.where((p) => (p.customerName ?? '').trim().isEmpty).toList();
      } else {
        out =
            out.where((p) => (p.customerName ?? '').trim() == want).toList();
      }
    }
    return out;
  }

  Widget _buildQuickFilterBar(List<DevelopmentProjectModel> scopeList) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final byGate = DevelopmentPortfolioStats.countsByGate(scopeList);
    final gates = DevelopmentPortfolioStats.gatesSorted(byGate);
    final custRows = DevelopmentPortfolioStats.rowsByCustomer(scopeList);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Brzi pregled i filteri',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_hasLocalFilters)
                  TextButton(
                    onPressed: _clearLocalFilters,
                    child: const Text('Poništi'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Samo moji projekti'),
                  selected: _onlyMyProjects,
                  onSelected: (v) => setState(() => _onlyMyProjects = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Svi statusi'),
                    selected: _lifecycle == _PortfolioLifecycle.all,
                    onSelected: (v) {
                      if (v) setState(() => _lifecycle = _PortfolioLifecycle.all);
                    },
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Aktivni tok'),
                    selected: _lifecycle == _PortfolioLifecycle.pipeline,
                    onSelected: (v) => setState(() {
                      _lifecycle =
                          v ? _PortfolioLifecycle.pipeline : _PortfolioLifecycle.all;
                    }),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Treba pažnje'),
                    selected: _lifecycle == _PortfolioLifecycle.attention,
                    onSelected: (v) => setState(() {
                      _lifecycle =
                          v ? _PortfolioLifecycle.attention : _PortfolioLifecycle.all;
                    }),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Završeno'),
                    selected: _lifecycle == _PortfolioLifecycle.done,
                    onSelected: (v) => setState(() {
                      _lifecycle = v ? _PortfolioLifecycle.done : _PortfolioLifecycle.all;
                    }),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    'Gate:',
                    style: tt.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilterChip(
                  label: Text('Svi (${scopeList.length})'),
                  selected: (_filterGate == null || _filterGate!.isEmpty),
                  onSelected: (_) => setState(() => _filterGate = null),
                ),
                const SizedBox(width: 6),
                ...gates.map((g) {
                  final label = g == '—' ? 'Bez' : g;
                  final n = byGate[g] ?? 0;
                  final selected = _filterGate == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('$label · $n'),
                      selected: selected,
                      onSelected: (v) => setState(() => _filterGate = v ? g : null),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (custRows.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      'Kupac:',
                      style: tt.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Svi'),
                    selected: _customerFilterName == null,
                    onSelected: (_) => setState(() => _customerFilterName = null),
                  ),
                  const SizedBox(width: 6),
                  if (custRows.any((r) => r.customerLabel.isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: () {
                        final noCust =
                            custRows.where((r) => r.customerLabel.isEmpty).toList();
                        final n = noCust.isEmpty ? 0 : noCust.first.count;
                        return FilterChip(
                          label: Text('Bez kupca · $n'),
                          selected: (_customerFilterName != null &&
                              _customerFilterName!.isEmpty),
                          onSelected: (v) => setState(
                            () => _customerFilterName = v ? '' : null,
                          ),
                        );
                      }(),
                    ),
                  ...custRows
                      .where((r) => r.customerLabel.isNotEmpty)
                      .take(10)
                      .map((r) {
                    final selected =
                        _customerFilterName == r.customerLabel;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('${r.customerLabel} · ${r.count}'),
                        selected: selected,
                        onSelected: (v) => setState(
                          () => _customerFilterName =
                              v ? r.customerLabel : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canCreateProject => DevelopmentPermissions.canCreateDevelopmentProject(
        role: widget.companyData['role']?.toString(),
        companyData: widget.companyData,
      );

  /// Tenant admin i super_admin vide portfelj za **cijelu kompaniju**, ne samo jedan pogon.
  bool get _portfolioAllPlants {
    final r = ProductionAccessHelper.rawRoleFromCompanySession(
      widget.companyData,
    );
    final n = ProductionAccessHelper.normalizeRole(r);
    return ProductionAccessHelper.isAdminRole(n) ||
        ProductionAccessHelper.isSuperAdminRole(n);
  }

  @override
  void initState() {
    super.initState();
    _loadSelectablePlants();
    _primeBusinessYearFromCompanyMirror();
    _attachFinancialYearsStream();
  }

  @override
  void dispose() {
    _fySub?.cancel();
    super.dispose();
  }

  void _attachFinancialYearsStream() {
    if (_companyId.isEmpty) return;
    _fySub?.cancel();
    final fyRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('financial_years');
    _fySub = fyRef.snapshots().listen((snap) {
      if (!mounted) return;
      final usable =
          List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snap.docs)
            ..sort((a, b) {
              final da = a.data()['startDate'];
              final db_ = b.data()['startDate'];
              if (da is Timestamp && db_ is Timestamp) {
                return db_.compareTo(da);
              }
              return b.id.compareTo(a.id);
            });

      String? activeId;
      for (final d in snap.docs) {
        final s = (d.data()['status'] ?? '').toString().toLowerCase();
        if (s == 'active') {
          activeId = d.id;
          break;
        }
      }

      setState(() {
        _fyDocs = usable;
        if (!_fyUserTouched && !_fyHydrated && activeId != null) {
          _selectedBusinessYearId = activeId;
          _fyHydrated = true;
        }
      });
    });
  }

  Future<void> _primeBusinessYearFromCompanyMirror() async {
    if (_companyId.isEmpty) return;
    final id = await OperationalBusinessYearContext.resolveFinancialYearIdForCompany(
      companyId: _companyId,
    );
    if (!mounted || _fyUserTouched) return;
    if (id.isEmpty) return;
    setState(() {
      _selectedBusinessYearId = id;
      _fyHydrated = true;
    });
  }

  Future<void> _loadSelectablePlants() async {
    if (!_portfolioAllPlants || _companyId.isEmpty) return;
    final list = await CompanyPlantDisplayName.listSelectablePlants(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() => _selectablePlants = list);
  }

  /// Pogon korišten za Callable mutacije (kreiranje): za admina prvo filtar portfelja, zatim sesijski pogon.
  String get _plantKeyForMutations {
    if (_portfolioAllPlants) {
      final f = (_portfolioPlantKeyFilter ?? '').trim();
      if (f.isNotEmpty) return f;
      return _plantKey.trim();
    }
    return _plantKey.trim();
  }

  bool get _needsPlantChoiceForMutations => _plantKeyForMutations.isEmpty;

  void _openCreateProject() {
    final pk = _plantKeyForMutations;
    if (_companyId.isEmpty || pk.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _needsPlantChoiceForMutations
                ? 'Nedostaje pogon u sesiji — odaberite pogon u profilu ili u filtru portfelja.'
                : 'Nedostaje organizacija ili pogon u sesiji.',
          ),
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DevelopmentProjectCreateScreen(
          companyData: widget.companyData,
          plantKeyOverride: pk,
        ),
      ),
    );
  }

  String _portfolioScopeCollapsedSummary() {
    final plantPart = () {
      if (!_portfolioAllPlants) {
        final pk = _plantKey.trim();
        return pk.isEmpty ? 'Pogon sesije' : 'Pogon: $pk';
      }
      final f = (_portfolioPlantKeyFilter ?? '').trim();
      if (f.isEmpty) return 'Svi pogoni u kompaniji';
      for (final e in _selectablePlants) {
        if (e.plantKey == f) return e.label;
      }
      return f;
    }();
    final yearPart = () {
      if (_selectedBusinessYearId == null) {
        return 'Sve poslovne godine (arhiva)';
      }
      for (final d in _fyDocs) {
        if (d.id == _selectedBusinessYearId) {
          final m = d.data();
          final name = (m['name'] ?? '').toString().trim();
          final code = (m['code'] ?? '').toString().trim();
          if (name.isNotEmpty) return name;
          if (code.isNotEmpty) return code;
          return d.id;
        }
      }
      return _fyDocs.isEmpty ? 'Godina (učitavanje…)' : 'Poslovna godina';
    }();
    return '$plantPart · $yearPart';
  }

  Widget _buildPersistentScopeBar() {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!_portfolioScopeExpanded) {
      return Material(
        elevation: 0.5,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.filter_alt_outlined, color: scheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Opseg portfelja',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _portfolioScopeCollapsedSummary(),
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Prikaži filtre (pogon, godina)',
                icon: const Icon(Icons.expand_more),
                onPressed: () =>
                    setState(() => _portfolioScopeExpanded = true),
              ),
              IconButton(
                tooltip: 'Pragovi Launch Readiness',
                onPressed: () =>
                    DevelopmentIntelligenceGlossary.showScoreRulesDialog(context),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 0.5,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_outlined, color: scheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Opseg portfelja',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Sakrij (više prostora za tabove i sadržaj)',
                  icon: const Icon(Icons.expand_less),
                  onPressed: () =>
                      setState(() => _portfolioScopeExpanded = false),
                ),
                IconButton(
                  tooltip: 'Pragovi Launch Readiness',
                  onPressed: () =>
                      DevelopmentIntelligenceGlossary.showScoreRulesDialog(context),
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_portfolioAllPlants && _selectablePlants.isNotEmpty) ...[
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Pogon',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _portfolioPlantKeyFilter,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Svi pogoni u kompaniji'),
                      ),
                      ..._selectablePlants.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.plantKey,
                          child: Text(e.label),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _portfolioPlantKeyFilter = v),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Poslovna godina',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                helperText:
                    _fyDocs.isEmpty ? 'Šifarnik godina se učitava…' : null,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedBusinessYearId,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sve poslovne godine (arhiva)'),
                    ),
                    ..._fyDocs.map((d) {
                      final m = d.data();
                      final code = (m['code'] ?? '').toString();
                      final name = (m['name'] ?? '').toString();
                      final st =
                          (m['status'] ?? '').toString().toLowerCase();
                      final stLabel = st == 'closed'
                          ? ' (zatvoreno)'
                          : st == 'draft'
                              ? ' (nacrt)'
                              : st == 'archived'
                                  ? ' (arhiva)'
                                  : '';
                      final label = name.isNotEmpty
                          ? '$code — $name$stLabel'
                          : '${code.isNotEmpty ? code : d.id}$stLabel';
                      return DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(label),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() {
                    _fyUserTouched = true;
                    _selectedBusinessYearId = v;
                    _fyHydrated = true;
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDemoProjectFullscreen() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DevelopmentProjectDemoFullscreenScreen(
          companyData: widget.companyData,
        ),
      ),
    );
  }

  void _showPortfolioInfoDialog() {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pomoć — portfelj'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Traka „Opseg portfelja“ određuje učitavanje: poslovna godina (obavezno), zatim po potrebi jedan pogon. '
                'Strelica gore (sakrij) skuplja tu traku da tabovi i lista dobiju više mjesta; strelica dolje ili „Prikaži filtre“ vraća dropdowne.\n\n'
                '„Sve poslovne godine (arhiva)“ širi filtar.\n\n'
                'Ispod: tabovi Projekti (lista i brzi filteri), Analitika (KPI i grafovi), AI asistent i Pomoć.\n\n'
                '${DevelopmentIntelligenceGlossary.launchIntelligenceSystemPitch}',
                style: TextStyle(
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              DevelopmentIntelligenceGlossary.showScoreRulesDialog(context);
            },
            child: const Text('Pragovi score-a'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Widget _portfolioSummaryStrip(List<DevelopmentProjectModel> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    int active = 0;
    int risk = 0;
    var progSum = 0;
    for (final p in list) {
      final s = p.status.trim();
      if (s == DevelopmentProjectStatuses.active ||
          s == DevelopmentProjectStatuses.approved ||
          s == DevelopmentProjectStatuses.proposed ||
          s == DevelopmentProjectStatuses.draft) {
        active++;
      }
      if (s == DevelopmentProjectStatuses.atRisk ||
          s == DevelopmentProjectStatuses.delayed ||
          s == DevelopmentProjectStatuses.onHold) {
        risk++;
      }
      progSum += p.progressPercent;
    }
    final avgProg = list.isEmpty ? 0 : (progSum / list.length).round();

    Widget chip(String label, String value, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          chip('Projekata u portfelju', '${list.length}', Icons.folder_open),
          chip('Aktivnih / u toku', '$active', Icons.play_circle_outline),
          chip('Rizik / pauza / kašnjenje', '$risk', Icons.warning_amber_outlined),
          chip('Prosječan napredak', '$avgProg %', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DevelopmentDemoPortfolioProjectCard(
                companyData: widget.companyData,
                showPlantChip: _portfolioAllPlants,
              ),
              const SizedBox(height: 28),
              Icon(
                Icons.account_tree,
                size: 56,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Još nema stvarnih projekata u ovom opsegu',
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              IconButton.filledTonal(
                tooltip: 'Pomoć za portfelj',
                onPressed: _showPortfolioInfoDialog,
                icon: const Icon(Icons.info_outline),
              ),
              if (_canCreateProject) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _openCreateProject,
                  icon: const Icon(Icons.add),
                  label: const Text('Kreiraj prvi projekat'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Razvoj / NPI / Projekti'),
        actions: [
          IconButton(
            tooltip: 'Primjer NPI projekta (pun zaslon)',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _openDemoProjectFullscreen,
          ),
          if (_canCreateProject)
            IconButton(
              tooltip: 'Novi projekat',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _openCreateProject,
            ),
          IconButton(
            tooltip: 'Pomoć — portfelj',
            icon: const Icon(Icons.info_outline),
            onPressed: _showPortfolioInfoDialog,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final trimmedPortfolioPlant =
              (_portfolioPlantKeyFilter ?? '').trim();
          final allPlantsInCompany = _portfolioAllPlants &&
              trimmedPortfolioPlant.isEmpty;
          final plantForQuery = allPlantsInCompany
              ? ''
              : (_portfolioAllPlants
                  ? trimmedPortfolioPlant
                  : _plantKey.trim());
          final missingOrg = _companyId.isEmpty ||
              (!_portfolioAllPlants && _plantKey.isEmpty);
          final missingPlantForQuery = _portfolioAllPlants &&
              !allPlantsInCompany &&
              plantForQuery.isEmpty;
          if (missingOrg || missingPlantForQuery) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nedostaje podatak o organizaciji ili pogonu za ovu sesiju.',
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPersistentScopeBar(),
              Expanded(
                child: StreamBuilder<List<DevelopmentProjectModel>>(
            stream: _service.watchProjects(
              companyId: _companyId,
              plantKey: plantForQuery,
              allPlantsInCompany: allPlantsInCompany,
              businessYearId: _selectedBusinessYearId,
            ),
            builder: (context, snap) {
              final list = snap.data;
              final loading = snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData &&
                  !snap.hasError;

              List<DevelopmentProjectModel>? filtered;
              if (list != null) {
                filtered = _applyPortfolioFilters(list);
              }

              Widget projectsTab() {
                if (snap.hasError) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 48,
                              color: scheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Podaci trenutno nisu dostupni.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tehnički detalj (indeks, pravila ili mreža):',
                              style: tt.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              snap.error.toString(),
                              style: tt.bodySmall?.copyWith(
                                color: scheme.onSurface,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (loading || list == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return _buildEmptyState();
                }
                final use = filtered ?? list;
                void openProject(DevelopmentProjectModel p) {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DevelopmentProjectDetailsScreen(
                        companyData: widget.companyData,
                        projectId: p.id,
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickFilterBar(list),
                    _portfolioSummaryStrip(use),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: DevelopmentDemoPortfolioProjectCard(
                        companyData: widget.companyData,
                        showPlantChip: _portfolioAllPlants,
                      ),
                    ),
                    Expanded(
                      child: use.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 440),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.filter_alt_off_outlined,
                                        size: 48,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Nema projekata koji odgovaraju filterima.',
                                        textAlign: TextAlign.center,
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      IconButton.filledTonal(
                                        tooltip: 'Kako koristiti filtere',
                                        onPressed: _showPortfolioInfoDialog,
                                        icon: const Icon(Icons.info_outline),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.tonal(
                                        onPressed: _clearLocalFilters,
                                        child: const Text('Poništi filtere'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: use.length,
                              separatorBuilder: (context, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final p = use[i];
                                return DevelopmentProjectCard(
                                  project: p,
                                  showPlantChip: _portfolioAllPlants,
                                  onTap: () => openProject(p),
                                );
                              },
                            ),
                    ),
                  ],
                );
              }

              Widget kpiTab() {
                if (snap.hasError || loading || list == null || filtered == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snap.hasError
                            ? 'Analitika portfelja nije učitana zbog greške. Otvori tab Projekti za detalje.'
                            : 'Učitavanje portfelja…',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                }
                void openProject(DevelopmentProjectModel p) {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DevelopmentProjectDetailsScreen(
                        companyData: widget.companyData,
                        projectId: p.id,
                      ),
                    ),
                  );
                }
                return DevelopmentPortfolioCommandCenterTab(
                  companyData: widget.companyData,
                  projects: filtered,
                  onOpenProject: openProject,
                );
              }

              Widget suppliersTab() {
                if (snap.hasError || loading || list == null || filtered == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snap.hasError
                            ? 'Dobavljači zahtijevaju učitan portfelj.'
                            : 'Učitavanje portfelja…',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                }
                void openProject(DevelopmentProjectModel p) {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DevelopmentProjectDetailsScreen(
                        companyData: widget.companyData,
                        projectId: p.id,
                      ),
                    ),
                  );
                }
                return DevelopmentPortfolioSuppliersTab(
                  companyData: widget.companyData,
                  projects: filtered,
                  onOpenProject: openProject,
                );
              }

              Widget aiTab() {
                if (snap.hasError || loading || list == null || filtered == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snap.hasError
                            ? 'AI asistent zahtijeva učitan portfelj.'
                            : 'Učitavanje portfelja…',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                }
                void openProject(DevelopmentProjectModel p) {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DevelopmentProjectDetailsScreen(
                        companyData: widget.companyData,
                        projectId: p.id,
                      ),
                    ),
                  );
                }
                return DevelopmentPortfolioAiAssistantTab(
                  companyData: widget.companyData,
                  projects: filtered,
                  showPlantChip: _portfolioAllPlants,
                  onOpenProject: openProject,
                );
              }

              return DefaultTabController(
                length: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: TabBar(
                        indicatorColor: scheme.primary,
                        labelColor: scheme.primary,
                        unselectedLabelColor: scheme.onSurfaceVariant,
                        isScrollable: true,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.view_list_outlined, size: 20),
                            text: 'Projekti',
                          ),
                          Tab(
                            icon: Icon(Icons.insights_outlined, size: 20),
                            text: 'Analitika',
                          ),
                          Tab(
                            icon: Icon(Icons.local_shipping_outlined, size: 20),
                            text: 'Dobavljači',
                          ),
                          Tab(
                            icon: Icon(Icons.auto_awesome_outlined, size: 20),
                            text: 'AI asistent',
                          ),
                          Tab(
                            icon: Icon(Icons.help_outline, size: 20),
                            text: 'Pomoć',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          projectsTab(),
                          kpiTab(),
                          suppliersTab(),
                          aiTab(),
                          const DevelopmentPortfolioHelpTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
