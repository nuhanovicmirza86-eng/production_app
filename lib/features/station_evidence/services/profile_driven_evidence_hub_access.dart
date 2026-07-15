import '../../../core/access/production_access_helper.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../models/profile_driven_evidence_hub_entry.dart';

/// Vidljivost tipa evidencije na hub ekranu (pogon + uloga + runtime gate).
class ProfileDrivenEvidenceHubAccess {
  ProfileDrivenEvidenceHubAccess._();

  static bool canViewEvidenceHub(String role) {
    return ProductionAccessHelper.canViewProfileDrivenEvidence(role);
  }

  static bool isHubEntryVisibleToUser({
    required ProductionStationConfig config,
    required String role,
    required String userPlantKey,
    String? selectedPlantKey,
  }) {
    if (!config.active) return false;
    if (!config.supportsRuntimeEvidenceProfile) return false;
    if (config.processProfileType.trim() == 'standard_production') return false;
    if (!config.runtimeVisible) return false;

    final plant = config.assignedPlantKey.trim();
    if (plant.isEmpty) return false;

    final r = ProductionAccessHelper.normalizeRole(role);
    if (!_isRoleAllowedOnStation(config, r)) return false;

    if (ProductionAccessHelper.canPickPlantFilterForProfileDrivenEvidence(r)) {
      final filter = (selectedPlantKey ?? '').trim();
      if (filter.isNotEmpty && filter != plant) return false;
      return true;
    }

    final userPk = userPlantKey.trim();
    return userPk.isNotEmpty && userPk == plant;
  }

  static bool canCreateEntryOnStation({
    required ProductionStationConfig config,
    required String role,
    required String userPlantKey,
    required String entryPlantKey,
  }) {
    if (!config.active || !config.runtimeVisible) return false;
    if (config.assignedPlantKey.trim() != entryPlantKey.trim()) return false;

    final r = ProductionAccessHelper.normalizeRole(role);
    if (ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleSuperAdmin) {
      return config.runtimeAllowedRoles.isNotEmpty;
    }

    if (userPlantKey.trim() != entryPlantKey.trim()) return false;
    if (config.runtimeAllowedRoles.isEmpty) return false;
    return config.runtimeAllowedRoles.contains(r);
  }

  static bool _isRoleAllowedOnStation(
    ProductionStationConfig config,
    String role,
  ) {
    if (ProductionAccessHelper.isAdminRole(role) ||
        role == ProductionAccessHelper.roleSuperAdmin) {
      return true;
    }
    if (config.runtimeAllowedRoles.isEmpty) return false;
    return config.runtimeAllowedRoles.contains(role);
  }

  static String profileDisplayName({
    required String processProfileType,
    required ProductionStationProfileCatalogEntry? catalogEntry,
    required ProductionStationConfig primaryConfig,
  }) {
    final fromCatalog = (catalogEntry?.displayName ?? '').trim();
    if (fromCatalog.isNotEmpty) return fromCatalog;
    final fromConfig = (primaryConfig.displayName ?? '').trim();
    if (fromConfig.isNotEmpty) return fromConfig;
    switch (processProfileType) {
      case 'chemical_dosing':
        return 'Doziranje hemikalija';
      case 'wastewater_treatment':
        return 'Obrada otpadnih voda';
      case 'rework_and_painting':
        return 'Dorada i površinska obrada';
      default:
        return processProfileType;
    }
  }

  static List<ProfileDrivenEvidenceHubEntry> buildHubEntries({
    required List<ProductionStationConfig> configs,
    required Map<String, ProductionStationProfileCatalogEntry> profilesByKey,
    required String role,
    required String userPlantKey,
    String? selectedPlantKey,
    required Map<String, DateTime?> lastEndedAtByGroupKey,
    required Map<String, int> recordCountByGroupKey,
  }) {
    final grouped = <String, List<ProductionStationConfig>>{};
    for (final config in configs) {
      if (!isHubEntryVisibleToUser(
        config: config,
        role: role,
        userPlantKey: userPlantKey,
        selectedPlantKey: selectedPlantKey,
      )) {
        continue;
      }
      final key = profileDrivenEvidenceHubGroupKey(config);
      grouped.putIfAbsent(key, () => []).add(config);
    }

    final entries = <ProfileDrivenEvidenceHubEntry>[];
    for (final group in grouped.values) {
      if (group.isEmpty) continue;
      final primary = group.reduce((a, b) {
        if (a.order != b.order) return a.order < b.order ? a : b;
        return a.stationSlot <= b.stationSlot ? a : b;
      });
      final profileType = primary.processProfileType.trim();
      final plantKey = primary.assignedPlantKey.trim();
      final catalog = profilesByKey[profileType];
      final canCreate = group.any(
        (c) => canCreateEntryOnStation(
          config: c,
          role: role,
          userPlantKey: userPlantKey,
          entryPlantKey: plantKey,
        ),
      );
      entries.add(
        ProfileDrivenEvidenceHubEntry(
          processProfileType: profileType,
          profileDisplayName: profileDisplayName(
            processProfileType: profileType,
            catalogEntry: catalog,
            primaryConfig: primary,
          ),
          plantKey: plantKey,
          stationConfigs: group,
          lastEndedAt: lastEndedAtByGroupKey[
              profileDrivenEvidenceHubGroupKey(primary)],
          recordCount:
              recordCountByGroupKey[profileDrivenEvidenceHubGroupKey(primary)] ??
              0,
          canCreateEntry: canCreate,
        ),
      );
    }

    entries.sort((a, b) {
      final plantCmp = a.plantKey.compareTo(b.plantKey);
      if (plantCmp != 0) return plantCmp;
      return a.profileDisplayName.compareTo(b.profileDisplayName);
    });
    return entries;
  }
}
