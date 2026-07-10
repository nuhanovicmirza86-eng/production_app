import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/models/production_station_profile_catalog_entry.dart';
import '../../station_pages/screens/production_profile_station_launch_screen.dart';
import '../../station_pages/services/production_station_config_callable_service.dart';

/// M1-B — lista aktivnih stanica s profilom spremnim za operator runtime.
class ProductionProfileStationsHubScreen extends StatefulWidget {
  const ProductionProfileStationsHubScreen({
    super.key,
    required this.companyData,
  });

  final Map<String, dynamic> companyData;

  @override
  State<ProductionProfileStationsHubScreen> createState() =>
      _ProductionProfileStationsHubScreenState();
}

class _ProductionProfileStationsHubScreenState
    extends State<ProductionProfileStationsHubScreen> {
  final _configCallables = ProductionStationConfigCallableService();

  bool _loading = true;
  Object? _error;
  List<({ProductionStationConfig config, ProductionStationProfileCatalogEntry profile})>
  _entries = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userPlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _userRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _shouldFilterByUserPlant =>
      !ProductionAccessHelper.isCompanyWideContextRole(_userRole);

  bool _configVisibleToUser(ProductionStationConfig config) {
    if (!_shouldFilterByUserPlant) return true;
    final assigned = config.assignedPlantKey.trim();
    if (assigned.isEmpty) return false;
    return assigned == _userPlantKey;
  }

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
      final configsFuture = _configCallables.listProductionStationConfigs(
        companyId: _companyId,
        operatorRuntimeOnly: true,
      );
      final profilesFuture = _configCallables.listProductionStationProfiles(
        companyId: _companyId,
      );
      final configsResult = await configsFuture;
      final profilesResult = await profilesFuture;

      final entries =
          <
            ({
              ProductionStationConfig config,
              ProductionStationProfileCatalogEntry profile,
            })
          >[];

      for (final config in configsResult.configs) {
        if (!config.active) continue;
        if (!_configVisibleToUser(config)) continue;
        if (!config.runtimeVisible) continue;
        if (!config.isRuntimeVisibleToRole(_userRole)) continue;
        if (config.legacyOperatorNavSlot != null) continue;
        if (config.processProfileType != 'chemical_dosing') continue;

        final profile = profilesResult.byKey(config.processProfileType);
        if (profile == null || !profile.isComplete) continue;

        entries.add((config: config, profile: profile));
      }

      entries.sort((a, b) {
        final oa = a.config.order;
        final ob = b.config.order;
        if (oa != ob) return oa.compareTo(ob);
        return a.config.stationSlot.compareTo(b.config.stationSlot);
      });

      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  void _openStation(
    ProductionStationConfig config,
    ProductionStationProfileCatalogEntry profile,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductionProfileStationLaunchScreen(
          companyData: widget.companyData,
          stationConfig: config,
          profile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operativne stanice (profil)'),
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
              Text('Greška učitavanja: $_error'),
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
            'Nema aktivnih stanica s profilom spremnim za operator unos.\n'
            'Administrator može dodati stanicu s profilom Doziranje hemikalija.',
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
            leading: const Icon(Icons.science_outlined),
            title: Text(config.title),
            subtitle: Text(
              '${profile.displayName} · Pogon: ${config.assignedPlantKey.isEmpty ? '—' : config.assignedPlantKey}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openStation(config, profile),
          ),
        );
      },
    );
  }
}
