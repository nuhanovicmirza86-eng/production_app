import 'package:shared_preferences/shared_preferences.dart';

import 'package:production_app/modules/production/tracking/models/production_operator_tracking_entry.dart';

/// Trajno na uređaju: nakon prijave otvori **cijelu aplikaciju** ili **određenu stanicu**.
///
/// U kombinaciji s [StationLaunchConfig] (compile-time): ako je postavljen `OPERONIX_STATION`,
/// on ima **prednost** pred ovim postavkama.
class StationLaunchPreference {
  StationLaunchPreference._();

  static const String _k = 'operonix_production_station_launch_v1';

  /// Cijeli dashboard (default).
  static const String modeFull = 'full';

  static const String modePreparation = 'preparation';
  static const String modeFirstControl = 'first_control';
  static const String modeFinalControl = 'final_control';

  /// Sirova vrijednost u prefs (za UI).
  static Future<String> getModeRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_k)?.trim() ?? '';
    if (v.isEmpty) return modeFull;
    return v;
  }

  /// Mapa u `phase` konstantu ili `null` = cijela aplikacija.
  static Future<String?> getPhaseOptional() async {
    final raw = await getModeRaw();
    switch (raw) {
      case modePreparation:
        return ProductionOperatorTrackingEntry.phasePreparation;
      case modeFirstControl:
        return ProductionOperatorTrackingEntry.phaseFirstControl;
      case modeFinalControl:
        return ProductionOperatorTrackingEntry.phaseFinalControl;
      case modeFull:
        return null;
      default:
        return null;
    }
  }

  static Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    final m = mode.trim();
    if (m.isEmpty || m == modeFull) {
      await prefs.remove(_k);
    } else {
      await prefs.setString(_k, m);
    }
  }
}
