import '../models/production_evidence_config.dart';
import '../models/production_station_profile_catalog_entry.dart';

/// M1-H3-F1G-R4 — najnoviji operator profil za evidenciju (live katalog vs config snapshot).
class ProductionOperatorProfileResolver {
  /// Preferira profil s višim [catalogVersion]; kod jednakosti — live katalog.
  static ProductionStationProfileCatalogEntry? resolveForEvidenceConfig({
    required ProductionEvidenceConfig config,
    required ProductionStationProfileCatalogResult catalog,
  }) {
    final live = catalog.byKey(config.profileKey);
    final fromConfig = entryFromSnapshot(config.profileSnapshot);

    if (live == null && fromConfig == null) return null;
    if (live == null) return fromConfig;
    if (fromConfig == null) return live;

    final liveVersion = catalog.catalogVersion;
    final configVersion = catalogVersionFromSnapshot(config.profileSnapshot);
    if (configVersion > liveVersion) return fromConfig;
    return live;
  }

  static int catalogVersionFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return 0;
    final raw = snapshot['catalogVersion'];
    if (raw is int && raw >= 0) return raw;
    if (raw is num && raw >= 0) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  static ProductionStationProfileCatalogEntry? entryFromSnapshot(
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null || snapshot.isEmpty) return null;
    final profileKey = (snapshot['profileKey'] ?? '').toString().trim();
    if (profileKey.isEmpty) return null;
    return ProductionStationProfileCatalogEntry.fromMap(snapshot);
  }

  /// Biraj najnoviji profil među kandidatima (operator runtime forma).
  static ProductionStationProfileCatalogEntry resolveNewest({
    required ProductionStationProfileCatalogEntry baseline,
    int baselineCatalogVersion = 0,
    Map<String, dynamic>? configSnapshot,
    Map<String, dynamic>? sessionSnapshot,
  }) {
    var best = baseline;
    var bestVersion = baselineCatalogVersion;

    void consider(ProductionStationProfileCatalogEntry? entry, int version) {
      if (entry == null || !entry.isComplete) return;
      if (version > bestVersion) {
        best = entry;
        bestVersion = version;
      }
    }

    consider(baseline, baselineCatalogVersion);
    consider(
      entryFromSnapshot(configSnapshot),
      catalogVersionFromSnapshot(configSnapshot),
    );
    consider(
      entryFromSnapshot(sessionSnapshot),
      catalogVersionFromSnapshot(sessionSnapshot),
    );
    return best;
  }
}
