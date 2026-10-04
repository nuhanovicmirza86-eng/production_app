import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokalno na uređaju: brzi vs ručni unos i naglasak boje za glavne gumbe.
class PreparationStationUiPrefs {
  PreparationStationUiPrefs._();

  static const _kQuick = 'prep_station_quick_mode_v1';
  static const _kAccent = 'prep_station_accent_v1';

  static const int accentCount = 4;

  static const List<Color> accentColors = [
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
  ];

  static const List<String> accentLabels = [
    'Zelena',
    'Plava',
    'Narančasta',
    'Ljubičasta',
  ];

  /// Obavijest da je spremljen akcent, da otvoreni ekran osvježi gumbe.
  static final ValueNotifier<int> accentTick = ValueNotifier<int>(0);

  static Future<bool> loadQuickMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kQuick) ?? true;
  }

  static Future<void> saveQuickMode(bool quick) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kQuick, quick);
  }

  static Future<int> loadAccentIndex() async {
    final p = await SharedPreferences.getInstance();
    return (p.getInt(_kAccent) ?? 0).clamp(0, accentCount - 1);
  }

  static Future<void> saveAccentIndex(int index) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kAccent, index.clamp(0, accentCount - 1));
    accentTick.value++;
  }
}
