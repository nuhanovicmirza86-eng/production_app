import 'package:flutter/material.dart';
import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/core/company_plant_display_name.dart';

import '../models/production_evidence_config.dart';
import '../models/production_station_config.dart';
import '../models/production_station_profile_catalog_entry.dart';
import '../services/production_evidence_config_callable_service.dart';
import '../services/production_station_config_callable_service.dart';
import 'production_evidence_catalog_screen.dart';
import 'production_evidence_config_form_screen.dart';

/// M1-H2 — Admin: aktivirane evidencije kompanije (production_evidence_configs).
class ProductionCompanyEvidenceAdminScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionCompanyEvidenceAdminScreen({
    super.key,
    required this.companyData,
  });

  @override
  State<ProductionCompanyEvidenceAdminScreen> createState() =>
      _ProductionCompanyEvidenceAdminScreenState();
}

class _ProductionCompanyEvidenceAdminScreenState
    extends State<ProductionCompanyEvidenceAdminScreen> {
  final _evidenceCallable = ProductionEvidenceConfigCallableService();
  final _stationCallable = ProductionStationConfigCallableService();

  bool _loading = true;
  String? _error;
  List<ProductionEvidenceConfig> _configs = const [];
  ProductionStationProfileCatalogResult? _profileCatalog;
  final Map<String, String> _plantLabels = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.stationPages,
      );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji u profilu.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final configsFuture = _evidenceCallable.listProductionEvidenceConfigs(
        companyId: _companyId,
      );
      final profilesFuture = _stationCallable.listProductionStationProfiles(
        companyId: _companyId,
      );
      final plantsFuture = CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      final configs = await configsFuture;
      final profiles = await profilesFuture;
      final plants = await plantsFuture;
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _profileCatalog = profiles;
        _plantLabels
          ..clear()
          ..addEntries(
            plants.map((p) => MapEntry(p.plantKey, p.label)),
          );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = productionEvidenceConfigErrorMessage(e);
      });
    }
  }

  void _openCatalog() {
    final catalog = _profileCatalog;
    if (catalog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Katalog obrazaca nije učitan. Osvježite listu i pokušajte ponovo.',
          ),
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionEvidenceCatalogScreen(catalog: catalog),
      ),
    );
  }

  Future<void> _openForm({ProductionEvidenceConfig? existing}) async {
    if (!_canManage) return;
    final catalog = _profileCatalog;
    if (catalog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Katalog obrazaca nije učitan. Osvježite listu i pokušajte ponovo.',
          ),
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductionEvidenceConfigFormScreen(
          companyData: widget.companyData,
          profileCatalog: catalog,
          canManage: _canManage,
          existing: existing,
          onSaved: _reload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidencije kompanije'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _openCatalog,
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Katalog evidencija',
          ),
          IconButton(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Osvježi',
          ),
          if (_canManage)
            IconButton(
              onPressed: _loading ? null : () => _openForm(),
              icon: const Icon(Icons.add),
              tooltip: 'Dodaj evidenciju',
            ),
        ],
      ),
      body: _companyId.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nedostaje podatak o kompaniji — evidencije nisu dostupne.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Evidencije kompanije',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Evidencije ne ulaze u limit proizvodnih ni mašinskih stanica. '
                                    'Ista evidencija iz kataloga može biti aktivirana više puta — '
                                    'nezavisno po pogonu i procesu.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aktivnih evidencija: ${_configs.where((c) => !c.isArchived && c.active).length}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_configs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Nema aktiviranih evidencija. Dodajte prvu evidenciju iz kataloga.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ..._configs.map(
                              (c) => _EvidenceConfigCard(
                                config: c,
                                plantLabel: _plantLabels[c.plantKey] ?? c.plantKey,
                                canManage: _canManage,
                                onTap: () => _openForm(existing: c),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _EvidenceConfigCard extends StatelessWidget {
  const _EvidenceConfigCard({
    required this.config,
    required this.plantLabel,
    required this.canManage,
    required this.onTap,
  });

  final ProductionEvidenceConfig config;
  final String plantLabel;
  final bool canManage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileLabel = config.profileNameSnapshot.isNotEmpty
        ? config.profileNameSnapshot
        : ProductionStationConfig.processProfileLabel(config.profileKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canManage ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      config.displayName.isNotEmpty
                          ? config.displayName
                          : profileLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (config.isArchived)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('Arhivirano'),
                    )
                  else if (config.active)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('Aktivna'),
                    )
                  else
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('Neaktivna'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Obrazac: $profileLabel'),
              Text('Pogon: $plantLabel'),
              Text(
                'Proces: ${config.processKey} · Faza: '
                '${ProductionStationConfig.productionPhaseLabel(config.phaseKey)}',
              ),
              if (config.runtimeVisible) ...[
                const SizedBox(height: 4),
                Text(
                  'Runtime: uključen · Uloge: '
                  '${config.runtimeAllowedRoles.map(ProductionStationConfig.runtimeRoleLabel).join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
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
