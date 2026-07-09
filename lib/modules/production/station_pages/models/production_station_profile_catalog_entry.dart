/// Katalog profila stanica — platformski JSON preko Callabla (M1-A).
class ProductionStationProfileCatalogEntry {
  final String profileKey;
  final String displayName;
  final String description;
  final String stationType;
  final String definitionStatus;
  final Map<String, dynamic> defaultFlags;
  final Map<String, dynamic> units;

  const ProductionStationProfileCatalogEntry({
    required this.profileKey,
    required this.displayName,
    required this.description,
    required this.stationType,
    required this.definitionStatus,
    this.defaultFlags = const {},
    this.units = const {},
  });

  bool get isComplete => definitionStatus == 'complete';

  bool get isSkeleton => definitionStatus == 'skeleton';

  static ProductionStationProfileCatalogEntry fromMap(Map<String, dynamic> data) {
    final flagsRaw = data['defaultFlags'];
    final unitsRaw = data['units'];
    return ProductionStationProfileCatalogEntry(
      profileKey: (data['profileKey'] ?? '').toString().trim(),
      displayName: (data['displayName'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
      stationType: (data['stationType'] ?? 'production_station').toString().trim(),
      definitionStatus: (data['definitionStatus'] ?? 'skeleton').toString().trim(),
      defaultFlags: flagsRaw is Map
          ? Map<String, dynamic>.from(flagsRaw)
          : const {},
      units: unitsRaw is Map ? Map<String, dynamic>.from(unitsRaw) : const {},
    );
  }

  static String definitionStatusLabel(String status) {
    switch (status) {
      case 'complete':
        return 'Spremno';
      case 'skeleton':
        return 'U pripremi';
      default:
        return status;
    }
  }

  String get definitionStatusLabelText =>
      definitionStatusLabel(definitionStatus);
}

class ProductionStationProfileCatalogResult {
  final int catalogVersion;
  final List<ProductionStationProfileCatalogEntry> profiles;

  const ProductionStationProfileCatalogResult({
    required this.catalogVersion,
    required this.profiles,
  });

  List<ProductionStationProfileCatalogEntry> profilesForStationType(
    String stationType,
  ) {
    return profiles
        .where((p) => p.stationType == stationType)
        .toList(growable: false);
  }

  ProductionStationProfileCatalogEntry? byKey(String profileKey) {
    final key = profileKey.trim();
    if (key.isEmpty) return null;
    for (final p in profiles) {
      if (p.profileKey == key) return p;
    }
    return null;
  }
}
