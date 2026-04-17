import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'station_screen_theme.dart';

/// Lokalno na uređaju: izgled ekrana stanica (preset ili prilagođene boje).
class StationScreenThemeStore {
  StationScreenThemeStore._();

  static const _kLegacy = 'station_screen_theme_v1';
  static const _kAppearance = 'station_screen_appearance_v1';

  static Future<StationScreenAppearance> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kAppearance);
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) {
          return StationScreenAppearance.fromJson(m);
        }
      } catch (_) {}
    }
    final legacy = p.getInt(_kLegacy);
    if (legacy != null) {
      final idx = legacy.clamp(0, StationScreenThemeId.values.length - 1);
      return StationScreenAppearance(
        preset: StationScreenThemeId.values[idx],
      );
    }
    return const StationScreenAppearance();
  }

  static Future<void> save(StationScreenAppearance appearance) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAppearance, jsonEncode(appearance.toJson()));
    await p.setInt(_kLegacy, appearance.preset.index);
  }
}
