import 'production_station_profile_field.dart';

/// Katalog profila stanica — platformski JSON preko Callabla (M1-A).
class ProductionStationProfileCatalogEntry {
  final String profileKey;
  final String displayName;
  final String description;
  final String stationType;
  final String definitionStatus;
  final Map<String, dynamic> defaultFlags;
  final Map<String, dynamic> units;
  final List<ProductionStationProfileField> fields;
  final List<Map<String, dynamic>> validations;
  final Map<String, dynamic> sessionBehavior;
  final List<Map<String, dynamic>> repeatableTables;

  const ProductionStationProfileCatalogEntry({
    required this.profileKey,
    required this.displayName,
    required this.description,
    required this.stationType,
    required this.definitionStatus,
    this.defaultFlags = const {},
    this.units = const {},
    this.fields = const [],
    this.validations = const [],
    this.sessionBehavior = const {},
    this.repeatableTables = const [],
  });

  bool get isComplete => definitionStatus == 'complete';

  bool get isSkeleton => definitionStatus == 'skeleton';

  static ProductionStationProfileCatalogEntry fromMap(Map<String, dynamic> data) {
    final flagsRaw = data['defaultFlags'];
    final unitsRaw = data['units'];
    final fieldsRaw = data['fields'];
    final validationsRaw = data['validations'];
    final fields = <ProductionStationProfileField>[];
    if (fieldsRaw is List) {
      for (final item in fieldsRaw) {
        if (item is Map) {
          fields.add(
            ProductionStationProfileField.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    final validations = <Map<String, dynamic>>[];
    if (validationsRaw is List) {
      for (final item in validationsRaw) {
        if (item is Map) {
          validations.add(Map<String, dynamic>.from(item));
        }
      }
    }
    final sessionBehaviorRaw = data['sessionBehavior'];
    final repeatableTablesRaw = data['repeatableTables'];
    final repeatableTables = <Map<String, dynamic>>[];
    if (repeatableTablesRaw is List) {
      for (final item in repeatableTablesRaw) {
        if (item is Map) {
          repeatableTables.add(Map<String, dynamic>.from(item));
        }
      }
    }
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
      fields: ProductionStationProfileField.sortedList(fields),
      validations: validations,
      sessionBehavior: sessionBehaviorRaw is Map
          ? Map<String, dynamic>.from(sessionBehaviorRaw)
          : const {},
      repeatableTables: repeatableTables,
    );
  }

  List<String> get allowedUnits {
    final raw = units['allowedUnits'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String get defaultUnit =>
      (units['defaultUnit'] ?? '').toString().trim();

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
