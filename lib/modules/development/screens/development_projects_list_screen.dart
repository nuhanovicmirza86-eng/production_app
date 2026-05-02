import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../models/development_project_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_permissions.dart';
import '../widgets/development_project_card.dart';
import 'development_project_create_screen.dart';
import 'development_project_details_screen.dart';
import 'development_roles_permissions_screen.dart';

/// Lista projekata razvoja / NPI — filtrirano po tenantu, pogonu i opcijski poslovnoj godini.
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
  String? _businessYearFilter;

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

  @override
  Widget build(BuildContext context) {
    final title = 'Razvoj / NPI / Projekti';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isSuperAdmin)
            IconButton(
              tooltip: 'Matrica uloga i dozvola (super admin)',
              icon: const Icon(Icons.table_rows_outlined),
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DevelopmentRolesPermissionsScreen(
                      companyData: widget.companyData,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Prikazuju se samo projekti vaše organizacije i odabranog pogona.',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Opseg podataka'),
                content: const Text(
                  'Prikazuju se samo projekti vaše organizacije i odabranog pogona (i poslovne godine ako je filtrirano). Podaci drugih organizacija nisu dostupni.',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _plantLabel != null && _plantLabel!.isNotEmpty
                      ? 'Pogon: $_plantLabel'
                      : 'Pogon: ${_plantKey.isEmpty ? '—' : _plantKey}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filtar: poslovna godina (opcionalno)',
                    hintText: 'npr. 2026 — ostavi prazno za sve',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final t = v.trim();
                    setState(() {
                      _businessYearFilter = t.isEmpty ? null : t;
                    });
                  },
                ),
              ],
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
                      businessYearId: _businessYearFilter,
                    ),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Podaci trenutno nisu dostupni.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snap.data!;
                      if (list.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _businessYearFilter == null
                                  ? 'Još nema projekata za ovaj pogon.'
                                  : 'Nema projekata za odabranu poslovnu godinu.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
