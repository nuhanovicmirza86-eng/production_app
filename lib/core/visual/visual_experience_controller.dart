import 'package:flutter/foundation.dart';

import 'visual_experience_store.dart';
import 'visual_style.dart';

/// Lokalni izgled aplikacije. Promjena se primjenjuje odmah i snima na uređaj.
class VisualExperienceController extends ChangeNotifier {
  VisualExperienceController({VisualExperienceStore? store})
    : _store = store ?? SharedPreferencesVisualExperienceStore();

  final VisualExperienceStore _store;
  VisualStyle _style = VisualStyle.classic;

  VisualStyle get style => _style;

  bool get isPremium => _style == VisualStyle.premium;

  Future<void> load() async {
    final next = await _store.read();
    if (next == _style) return;
    _style = next;
    notifyListeners();
  }

  /// Odmah mijenja temu, zatim snima. Nema restarta aplikacije.
  Future<void> setStyle(VisualStyle style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    await _store.write(style);
  }
}
