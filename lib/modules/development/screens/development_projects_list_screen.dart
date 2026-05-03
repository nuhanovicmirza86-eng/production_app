import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';
import '../utils/development_permissions.dart';
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

  /// `null` = sve poslovne godine (portfelj).
  String? _selectedBusinessYearId;

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

  @override
  void initState() {
    super.initState();
    _loadPlantLabel();
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
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DevelopmentProjectCreateScreen(
                          companyData: widget.companyData,
                        ),
                      ),
                    );
                  },
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
    final fyRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('financial_years');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Razvoj / NPI / Projekti'),
        actions: [
          if (_isSuperAdmin)
            IconButton(
              tooltip: 'Matrica uloga i dozvola (super admin)',
              icon: const Icon(Icons.table_rows_outlined),
              onPressed: _openMatrix,
            ),
          IconButton(
            tooltip: 'Opseg podataka i arhitektura modula',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Portfelj razvoja'),
                content: SingleChildScrollView(
                  child: Text(
                    'Prikazuju se samo projekti vaše organizacije i odabranog pogona. '
                    'Filtar poslovne godine sužava portfelj; „Sve poslovne godine“ prikazuje cjelokupan NPI portfelj na pogonu.\n\n'
                    'Matrica enterprise prava po ulozi (reference za super admin): '
                    'dostupna iz kartice ispod ili ikone u traci.',
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
      floatingActionButton: _canCreateProject
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DevelopmentProjectCreateScreen(
                      companyData: widget.companyData,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Novi projekat'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.35),
                  scheme.surface,
                ],
              ),
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portfolio — Stage-Gate i NPI',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upravljanje projektima, ključnim fazama, KPI i rizicima — po poslovnoj godini i pogonu.',
                  style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.factory_outlined, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _plantLabel != null && _plantLabel!.isNotEmpty
                            ? 'Pogon: $_plantLabel'
                            : 'Pogon: ${_plantKey.isEmpty ? '—' : _plantKey}',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuperAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                elevation: 0,
                color: scheme.secondaryContainer.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: Icon(Icons.grid_view, color: scheme.primary),
                  title: const Text('Matrica uloga i dozvola (enterprise)'),
                  subtitle: const Text(
                    'Pregled tko smije kreirati projekte, taskove, Gate, budžet, AI — po kanonskoj ulozi.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openMatrix,
                ),
              ),
            ),
          if (_companyId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: fyRef.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      'Poslovne godine nisu učitane.',
                      style: TextStyle(color: scheme.error),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  final usable = docs.where((d) {
                    final s = (d.data()['status'] ?? '').toString().toLowerCase();
                    return s == 'active' || s == 'draft';
                  }).toList()
                    ..sort((a, b) => b.id.compareTo(a.id));

                  final items = <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sve poslovne godine (cijeli portfelj)'),
                    ),
                    ...usable.map((d) {
                      final m = d.data();
                      final code = (m['code'] ?? '').toString();
                      final name = (m['name'] ?? '').toString();
                      final label = name.isNotEmpty
                          ? '$code — $name'
                          : (code.isNotEmpty ? code : d.id);
                      return DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(label),
                      );
                    }),
                  ];

                  return DropdownButtonFormField<String?>(
                    key: ValueKey<String?>(_selectedBusinessYearId),
                    initialValue: _selectedBusinessYearId,
                    decoration: InputDecoration(
                      labelText: 'Poslovna godina — glavni filter portfelja',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      helperText: usable.isEmpty
                          ? 'Nema unosa u šifrarniku godina — portfelj pokazuje sve godine; unos godina kod novog projekta ručno u Callable.'
                          : 'Odabir sužava listu; ostavi „Sve“ za potpun portfelj pogona.',
                    ),
                    items: items,
                    onChanged: (v) => setState(() => _selectedBusinessYearId = v),
                  );
                },
              ),
            ),
          Expanded(
            child: _companyId.isEmpty || _plantKey.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nedostaje podatak o organizaciji ili pogonu za ovu sesiju.',
                      ),
                    ),
                  )
                : StreamBuilder<List<DevelopmentProjectModel>>(
                    stream: _service.watchProjects(
                      companyId: _companyId,
                      plantKey: _plantKey,
                      businessYearId: _selectedBusinessYearId,
                    ),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Podaci trenutno nisu dostupni.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snap.data!;
                      if (list.isEmpty) {
                        return _buildEmptyState();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _portfolioSummaryStrip(list),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                              itemCount: list.length,
                              separatorBuilder: (context, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final p = list[i];
                                return DevelopmentProjectCard(
                                  project: p,
                                  onTap: () {
                                    Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            DevelopmentProjectDetailsScreen(
                                          companyData: widget.companyData,
                                          projectId: p.id,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
