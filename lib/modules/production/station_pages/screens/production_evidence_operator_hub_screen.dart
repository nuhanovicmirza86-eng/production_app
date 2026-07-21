import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../models/production_evidence_config.dart';
import '../models/production_station_profile_catalog_entry.dart';
import '../services/production_evidence_config_callable_service.dart';
import '../services/production_station_config_callable_service.dart';
import 'production_evidence_operator_launch_screen.dart';

/// M1-H3 — operator hub za aktivne kompanijske evidencije (production_evidence_configs).
class ProductionEvidenceOperatorHubScreen extends StatefulWidget {
  const ProductionEvidenceOperatorHubScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<ProductionEvidenceOperatorHubScreen> createState() =>
      _ProductionEvidenceOperatorHubScreenState();
}

class _ProductionEvidenceOperatorHubScreenState
    extends State<ProductionEvidenceOperatorHubScreen> {
  final _evidenceCallables = ProductionEvidenceConfigCallableService();
  final _profileCallables = ProductionStationConfigCallableService();

  bool _loading = true;
  Object? _error;
  List<
    ({
      ProductionEvidenceConfig config,
      ProductionStationProfileCatalogEntry profile,
    })
  > _entries = const [];
  final Map<String, String> _plantLabels = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final configsFuture = _evidenceCallables.listProductionEvidenceConfigs(
        companyId: _companyId,
        operatorRuntimeOnly: true,
      );
      final profilesFuture = _profileCallables.listProductionStationProfiles(
        companyId: _companyId,
      );
      final plantsFuture = CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      final configs = await configsFuture;
      final profiles = await profilesFuture;
      final plants = await plantsFuture;

      final entries =
          <
            ({
              ProductionEvidenceConfig config,
              ProductionStationProfileCatalogEntry profile,
            })
          >[];

      for (final config in configs) {
        if (!ProductionEvidenceConfig.isH3OperatorRuntimeProfile(
          config.profileKey,
        )) {
          continue;
        }
        if (!config.isRuntimeVisibleToRole(_userRole)) continue;

        final profile = profiles.byKey(config.profileKey);
        if (profile == null || !profile.isComplete) continue;

        entries.add((config: config, profile: profile));
      }

      entries.sort((a, b) {
        final oa = a.config.displayOrder ?? a.config.evidenceSlot;
        final ob = b.config.displayOrder ?? b.config.evidenceSlot;
        if (oa != ob) return oa.compareTo(ob);
        return a.config.displayName.compareTo(b.config.displayName);
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _plantLabels
          ..clear()
          ..addEntries(plants.map((p) => MapEntry(p.plantKey, p.label)));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _openEvidence(
    ProductionEvidenceConfig config,
    ProductionStationProfileCatalogEntry profile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductionEvidenceOperatorLaunchScreen(
          companyData: widget.companyData,
          evidenceConfig: config,
          profile: profile,
        ),
      ),
    );
  }

  String _plantLabel(String plantKey) {
    final key = plantKey.trim();
    if (key.isEmpty) return '—';
    return _plantLabels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operativne evidencije'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Osvježi',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(productionEvidenceConfigErrorMessage(_error!)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nema aktivnih evidencija za vašu ulogu i pogon.\n'
            'Administrator može aktivirati obrasce u Evidencije kompanije.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final config = entry.config;
        final profile = entry.profile;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(_iconForProfile(profile.profileKey)),
            ),
            title: Text(config.displayName),
            subtitle: Text(
              '${profile.displayName}\n'
              'Pogon: ${_plantLabel(config.plantKey)} · '
              'Proces: ${config.processKey} · Faza: ${config.phaseKey}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openEvidence(config, profile),
          ),
        );
      },
    );
  }

  IconData _iconForProfile(String profileKey) {
    switch (profileKey.trim()) {
      case 'chemical_dosing':
        return Icons.science_outlined;
      case 'wastewater_treatment':
        return Icons.water_outlined;
      case 'production_counting':
        return Icons.numbers_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }
}
