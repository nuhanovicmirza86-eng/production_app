import 'package:flutter/material.dart';

import '../../../../core/visual/operonix_empty_state.dart';
import '../../../../core/visual/operonix_visual_tokens.dart';
import '../../../../core/visual/premium/premium_icon_accent.dart';
import '../../../../core/visual/premium/premium_widgets.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../features/catalog_evidence_runtime/utils/catalog_evidence_help_texts.dart';
import '../utils/production_operator_profile_resolver.dart';
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
  int _profileCatalogVersion = 0;
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
        if (ProductionAccessHelper.canAccessQualityControlEvidenceHub(
              _userRole,
            ) &&
            !ProductionAccessHelper.isQualityControlEvidenceProfile(
              config.profileKey,
            )) {
          continue;
        }
        if (!config.isRuntimeVisibleToRole(_userRole)) continue;

        final profile = ProductionOperatorProfileResolver.resolveForEvidenceConfig(
          config: config,
          catalog: profiles,
        );
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
        _profileCatalogVersion = profiles.catalogVersion;
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
          profileCatalogVersion: _profileCatalogVersion,
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
        title: Text(
          ProductionAccessHelper.canAccessQualityControlEvidenceHub(_userRole)
              ? 'Kontrolne evidencije'
              : 'Operativne evidencije',
        ),
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
      if (OperonixVisualTokens.of(context).isPremium) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: PremiumEmptyState(
            icon: Icons.fact_check_outlined,
            role: PremiumIconRole.quality,
            title: 'Nema aktivnih evidencija za vašu ulogu i pogon.',
            support:
                'Administrator može aktivirati obrasce u Evidencije kompanije.',
          ),
        );
      }
      return const OperonixEmptyState(
        padding: EdgeInsets.all(24),
        message:
            'Nema aktivnih evidencija za vašu ulogu i pogon.\n'
            'Administrator može aktivirati obrasce u Evidencije kompanije.',
      );
    }

    if (OperonixVisualTokens.of(context).isPremium) {
      final tokens = OperonixVisualTokens.of(context);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          PremiumSurfaceCard(
            level: 1,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < _entries.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: tokens.divider),
                  _evidenceCardAt(index),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _evidenceCardAt(index),
    );
  }

  Widget _evidenceCardAt(int index) {
    final entry = _entries[index];
    final config = entry.config;
    final profile = entry.profile;
    return ProductionEvidenceListCard(
      title: config.displayName,
      subtitle:
          '${profile.displayName}\n'
          'Pogon: ${_plantLabel(config.plantKey)} · '
          'Proces: ${config.processKey} · Faza: ${config.phaseKey}',
      icon: _iconForProfile(profile.profileKey),
      profileKey: profile.profileKey,
      infoAction: CatalogEvidenceHelpTexts.infoIconForProfile(
        profileKey: profile.profileKey,
        displayName: profile.displayName,
        description: profile.description,
      ),
      onTap: () => _openEvidence(config, profile),
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
      case 'packaging_control':
        return Icons.inventory_2_outlined;
      case 'first_piece_approval':
        return Icons.verified_outlined;
      case 'in_process_quality_check':
        return Icons.fact_check_outlined;
      case 'final_control':
        return Icons.verified_user_outlined;
      case 'line_clearance':
        return Icons.cleaning_services_outlined;
      case 'workspace_5s_cleaning':
        return Icons.grid_view_outlined;
      case 'material_preparation':
        return Icons.inventory_outlined;
      case 'operation_material_preparation':
        return Icons.precision_manufacturing_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }
}

/// Kartica evidencije u hubu. Isti podaci; Premium ima zaseban kompaktan raspored.
class ProductionEvidenceListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget infoAction;
  final VoidCallback? onTap;
  final String profileKey;

  const ProductionEvidenceListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.infoAction,
    this.onTap,
    this.profileKey = '',
  });

  String get _premiumMeta {
    final lines = subtitle
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length >= 2) return lines.sublist(1).join(' · ');
    return lines.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (OperonixVisualTokens.of(context).isPremium) {
      return PremiumListCard(
        flush: true,
        icon: icon,
        role: PremiumIconAccent.forProfile(profileKey),
        title: title,
        subtitle: _premiumMeta,
        trailing: infoAction,
        onTap: onTap,
      );
    }
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            infoAction,
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
