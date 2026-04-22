import 'package:shared_preferences/shared_preferences.dart';

import '../planning_order_pool_view_mode.dart';

/// Pohrana zadnjeg načina prikaza order poola po **companyId** + **plantKey** (korisnik / uređaj).
class PlanningPoolViewPrefs {
  PlanningPoolViewPrefs._();

  static String _key(String companyId, String plantKey) {
    final a = _seg(companyId);
    final b = _seg(plantKey);
    return 'planning_order_pool_view_v1_${a}_$b';
  }

  static String _seg(String s) {
    if (s.isEmpty) return 'x';
    return s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<PlanningOrderPoolViewMode?> read(
    String companyId,
    String plantKey,
  ) async {
    if (companyId.isEmpty && plantKey.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key(companyId, plantKey));
    return PlanningOrderPoolViewMode.fromPreferenceValue(v);
  }

  static Future<void> write(
    String companyId,
    String plantKey,
    PlanningOrderPoolViewMode mode,
  ) async {
    if (companyId.isEmpty && plantKey.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(companyId, plantKey), mode.preferenceValue);
  }
}
