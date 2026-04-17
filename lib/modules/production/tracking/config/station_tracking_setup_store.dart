import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../production_orders/printing/bom_classification_catalog.dart';

/// Lokalno na uređaju: pogon, klasifikacija i postavke etikete za dedicated stanicu.
class StationTrackingSetup {
  const StationTrackingSetup({
    required this.plantKey,
    required this.classification,
    required this.labelPrintingEnabled,
    required this.labelLayoutKey,
  });

  final String plantKey;
  final String classification;
  final bool labelPrintingEnabled;
  final String labelLayoutKey;

  Map<String, dynamic> toJson() => {
    'plantKey': plantKey,
    'classification': classification,
    'labelPrintingEnabled': labelPrintingEnabled,
    'labelLayoutKey': labelLayoutKey,
  };

  factory StationTrackingSetup.fromJson(Map<String, dynamic> m) {
    return StationTrackingSetup(
      plantKey: (m['plantKey'] ?? '').toString().trim(),
      classification: (m['classification'] ?? 'PRIMARY').toString().trim(),
      labelPrintingEnabled: m['labelPrintingEnabled'] != false,
      labelLayoutKey: (m['labelLayoutKey'] ?? kStationLabelLayoutStandard)
          .toString()
          .trim(),
    );
  }
}

const String kStationLabelLayoutStandard = 'standard';
const String kStationLabelLayoutCompact = 'compact';
const String kStationLabelLayoutMinimal = 'minimal';

const List<String> kStationLabelLayoutKeys = [
  kStationLabelLayoutStandard,
  kStationLabelLayoutCompact,
  kStationLabelLayoutMinimal,
];

class StationTrackingSetupStore {
  StationTrackingSetupStore._();

  static String _jsonKey(String companyId) =>
      'tracking_station_setup_v1_${companyId.trim()}';

  static String _legacyPlantKey(String companyId) =>
      'tracking_station_plant_${companyId.trim()}';

  static StationTrackingSetup _normalize(StationTrackingSetup s) {
    final cls = s.classification.toUpperCase();
    final okCls = kBomClassificationCodes.contains(cls)
        ? cls
        : kBomClassificationCodes.first;
    var layout = s.labelLayoutKey;
    if (!kStationLabelLayoutKeys.contains(layout)) {
      layout = kStationLabelLayoutStandard;
    }
    return StationTrackingSetup(
      plantKey: s.plantKey.trim(),
      classification: okCls,
      labelPrintingEnabled: s.labelPrintingEnabled,
      labelLayoutKey: layout,
    );
  }

  /// Učitaj postavke; ako postoji samo stari ključ s pogonom, migriraj.
  static Future<StationTrackingSetup?> load(String companyId) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jsonKey(cid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final s = StationTrackingSetup.fromJson(decoded);
          if (s.plantKey.isEmpty) return null;
          return _normalize(s);
        }
      } catch (_) {}
    }
    final legacy = prefs.getString(_legacyPlantKey(cid))?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      final migrated = _normalize(
        StationTrackingSetup(
          plantKey: legacy,
          classification: 'PRIMARY',
          labelPrintingEnabled: true,
          labelLayoutKey: kStationLabelLayoutStandard,
        ),
      );
      await save(cid, migrated);
      return migrated;
    }
    return null;
  }

  static Future<void> save(String companyId, StationTrackingSetup setup) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return;
    final normalized = _normalize(setup);
    if (normalized.plantKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jsonKey(cid), jsonEncode(normalized.toJson()));
    await prefs.setString(_legacyPlantKey(cid), normalized.plantKey);
  }

  static Future<void> clear(String companyId) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jsonKey(cid));
    await prefs.remove(_legacyPlantKey(cid));
  }
}
