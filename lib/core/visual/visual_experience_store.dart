import 'package:shared_preferences/shared_preferences.dart';

import 'visual_style.dart';

/// Lokalna preferenca izgleda. Nema Firestore zapisa.
abstract class VisualExperienceStore {
  Future<VisualStyle> read();

  Future<void> write(VisualStyle style);
}

class SharedPreferencesVisualExperienceStore implements VisualExperienceStore {
  SharedPreferencesVisualExperienceStore({this.preferences});

  static const String storageKey = 'operonix_production_visual_style_v1';

  /// Testovi mogu ubaciti već otvorene prefs. Produkcija koristi [SharedPreferences.getInstance].
  final SharedPreferences? preferences;

  Future<SharedPreferences> _prefs() async {
    return preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<VisualStyle> read() async {
    final prefs = await _prefs();
    return VisualStyle.fromStorage(prefs.getString(storageKey));
  }

  @override
  Future<void> write(VisualStyle style) async {
    final prefs = await _prefs();
    await prefs.setString(storageKey, style.storageValue);
  }
}

/// Memorijski store za testove i za trenutak prije prvog čitanja.
class MemoryVisualExperienceStore implements VisualExperienceStore {
  MemoryVisualExperienceStore({VisualStyle initial = VisualStyle.classic})
    : _style = initial;

  VisualStyle _style;

  VisualStyle get current => _style;

  @override
  Future<VisualStyle> read() async => _style;

  @override
  Future<void> write(VisualStyle style) async {
    _style = style;
  }
}
