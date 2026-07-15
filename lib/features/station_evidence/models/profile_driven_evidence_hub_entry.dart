import '../../../modules/production/station_pages/models/production_station_config.dart';

/// Profili s M2 read Callable pregledom zatvorenih zapisa.
const profileDrivenEvidenceReadSupportedProfiles = {
  'chemical_dosing',
  'wastewater_treatment',
  'rework_and_painting',
};

/// Jedna kartica na hub ekranu — tip evidencije po pogonu (ne pojedinačni zapis).
class ProfileDrivenEvidenceHubEntry {
  const ProfileDrivenEvidenceHubEntry({
    required this.processProfileType,
    required this.profileDisplayName,
    required this.plantKey,
    required this.stationConfigs,
    this.lastEndedAt,
    this.recordCount = 0,
    required this.canCreateEntry,
  });

  final String processProfileType;
  final String profileDisplayName;
  final String plantKey;
  final List<ProductionStationConfig> stationConfigs;
  final DateTime? lastEndedAt;
  final int recordCount;
  final bool canCreateEntry;

  bool get supportsRecordsView =>
      profileDrivenEvidenceReadSupportedProfiles.contains(processProfileType);

  ProductionStationConfig get primaryStationConfig {
    final sorted = [...stationConfigs]
      ..sort((a, b) {
        if (a.order != b.order) return a.order.compareTo(b.order);
        return a.stationSlot.compareTo(b.stationSlot);
      });
    return sorted.first;
  }

  String get stationDisplayLabel => primaryStationConfig.title;
}

String profileDrivenEvidenceHubGroupKey(ProductionStationConfig config) {
  return '${config.processProfileType.trim()}|${config.assignedPlantKey.trim()}';
}
