import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/operational_business_year_context.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_permissions.dart';
import '../widgets/development_portfolio_command_center_tab.dart';
import '../widgets/development_portfolio_help_tab.dart';
import '../widgets/development_project_card.dart';
import 'development_project_create_screen.dart';
import 'development_project_details_screen.dart';
import 'development_roles_permissions_screen.dart';

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
  String? _plantLabel;

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

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canCreateProject => DevelopmentPermissions.canCreateDevelopmentProject(
        role: widget.companyData['role']?.toString(),
        companyData: widget.companyData,
      );

  bool get _isSuperAdmin => ProductionAccessHelper.isSuperAdminRole(
        widget.companyData['role']?.toString() ?? '',
      );

  /// Tenant admin i super_admin vide portfelj za **cijelu kompaniju**, ne samo jedan pogon.
  bool get _portfolioAllPlants =>
      ProductionAccessHelper.isAdminRole(
        widget.companyData['role']?.toString() ?? '',
      ) ||
      _isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _loadPlantLabel();
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

  Future<void> _loadPlantLabel() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    final label = await CompanyPlantDisplayName.resolve(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    if (!mounted) return;
    setState(() => _plantLabel = label);
  }

  void _openMatrix() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DevelopmentRolesPermissionsScreen(
          companyData: widget.companyData,
        ),
      ),
    );
  }

  String _compactScopeSubtitle() {
    final buf = StringBuffer();
    if (_portfolioAllPlants) {
      final pf = (_portfolioPlantKeyFilter ?? '').trim();
      if (pf.isEmpty) {
        buf.write('Svi pogoni');
      } else {
        var label = pf;
        for (final e in _selectablePlants) {
          if (e.plantKey == pf) {
            label = e.label;
            break;
          }
        }
        buf.write(label);
      }
    } else {
      if (_plantLabel != null && _plantLabel!.trim().isNotEmpty) {
        buf.write(_plantLabel!.trim());
      } else if (_plantKey.isNotEmpty) {
        buf.write(_plantKey);
      } else {
        buf.write('Pogon');
      }
    }
    buf.write(' · ');
    if (_selectedBusinessYearId == null) {
      buf.write('sve posl. godine');
    } else {
      final id = _selectedBusinessYearId!;
      var shown = id;
      for (final d in _fyDocs) {
        if (d.id == id) {
          final m = d.data();
          final code = (m['code'] ?? '').toString();
          final name = (m['name'] ?? '').toString();
          if (name.isNotEmpty) {
            shown = code.isNotEmpty ? '$code · $name' : name;
          } else if (code.isNotEmpty) {
            shown = code;
          }
          break;
        }
      }
      buf.write(shown);
    }
    return buf.toString();
  }

  Future<void> _openPortfolioFiltersSheet() async {
    if (_companyId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filtri portfelja',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pogon i poslovna godina ne zauzimaju glavni ekran — podešavaju se ovdje '
                    '(ikona filtera u traci).',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_portfolioAllPlants && _selectablePlants.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      value: _portfolioPlantKeyFilter,
                      decoration: const InputDecoration(
                        labelText: 'Pogon',
                        border: OutlineInputBorder(),
                      ),
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
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String?>(
                    value: _selectedBusinessYearId,
                    decoration: InputDecoration(
                      labelText: 'Poslovna godina',
                      border: const OutlineInputBorder(),
                      helperText: _fyDocs.isEmpty
                          ? 'Šifarnik godina se sinkronizira na backendu; do tada koristi „sve godine”.'
                          : '„Sve godine” uključuje arhiv u trenutnom opsegu pogona.',
                    ),
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Gotovo'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    final yearHint = _selectedBusinessYearId != null
        ? 'Za odabranu poslovnu godinu nema projekata — probaj „Sve poslovne godine“ ili drugu godinu.'
        : 'Još nema projekata za ovaj pogon u portfelju.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_tree,
                size: 72,
                color: scheme.primary.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 20),
              Text(
                'Portfelj je prazan',
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                yearHint,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Modul pokriva:',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              _bullet(tt, 'Stage-Gate (G0–G9) i operativni portfelj po poslovnoj godini'),
              _bullet(tt, 'Zadaci, rizici, dokumenti, odobrenja i izmjene (IATF-prijateljski trag)'),
              _bullet(tt, 'KPI, AI uvidi (pretplata), Launch Intelligence i spremnost za release'),
              if (_canCreateProject) ...[
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _openCreateProject,
                  icon: const Icon(Icons.add),
                  label: const Text('Kreiraj prvi projekat'),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Text(
                  'Kreiranje projekata: tenant admin, super admin ili voditelj projekata (project_manager). '
                  'Za pregled koristi kartice kad se projekti pojave.',
                  textAlign: TextAlign.center,
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
    );
  }

  Widget _bullet(TextTheme textTheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: textTheme.bodyMedium),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Razvoj / NPI / Projekti'),
            Text(
              _companyId.isEmpty ? '—' : _compactScopeSubtitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_companyId.isNotEmpty)
            IconButton(
              tooltip: 'Filtri (pogon, poslovna godina)',
              icon: const Icon(Icons.tune),
              onPressed: _openPortfolioFiltersSheet,
            ),
          if (_canCreateProject)
            IconButton(
              tooltip: 'Novi projekat',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _openCreateProject,
            ),
          if (_isSuperAdmin)
            IconButton(
              tooltip: 'Matrica uloga (super admin)',
              icon: const Icon(Icons.table_rows_outlined),
              onPressed: _openMatrix,
            ),
          IconButton(
            tooltip: 'Modul i opseg podataka',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Portfelj razvoja'),
                content: SingleChildScrollView(
                  child: Text(
                    'Za uloge vezane uz pojedini pogon portfelj je ograničen na taj pogon. '
                    'Za **Admin** i **Super admin** prikazuju se projekti po odabiru: '
                    'svi pogoni u kompaniji ili jedan pogon iz filtra — uvijek unutar odabrane poslovne godine.\n\n'
                    'Zadano je **aktivna poslovna godina** (kalendarska, sinkronizacija na backendu); '
                    '„Sve poslovne godine“ uključuje cijeli arhiv u tom opsegu.\n\n'
                    'Filtar pogona i godine: ikona šrafa u traci.\n'
                    'Matrica enterprise prava (super admin): ikona u traci.',
                    style: TextStyle(height: 1.35, color: scheme.onSurfaceVariant),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Zatvori'),
                  ),
                ],
              ),
            ),
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
          return StreamBuilder<List<DevelopmentProjectModel>>(
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
                    _portfolioSummaryStrip(list),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: list.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final p = list[i];
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
                if (snap.hasError || loading || list == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        snap.hasError
                            ? 'KPI portfelja nije učitan zbog greške na prvom tabu.'
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
                  projects: list,
                  showPlantChip: _portfolioAllPlants,
                  onOpenProject: openProject,
                );
              }

              return DefaultTabController(
                length: 3,
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
                            icon: Icon(Icons.analytics_outlined, size: 20),
                            text: 'KPI portfelja',
                          ),
                          Tab(
                            icon: Icon(Icons.help_outline, size: 20),
                            text: 'Pomoć i AI',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          projectsTab(),
                          kpiTab(),
                          const DevelopmentPortfolioHelpTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
