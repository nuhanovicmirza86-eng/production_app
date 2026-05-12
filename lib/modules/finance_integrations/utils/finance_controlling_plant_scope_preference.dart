import 'package:shared_preferences/shared_preferences.dart';

/// Lokalni odabir pogona u hubu **Finance & Controlling** (admin / uloge bez pogona u profilu).
/// Prazan string = svi pogoni.
class FinanceControllingPlantScopePreference {
  FinanceControllingPlantScopePreference._();

  static String _key(String companyId) {
    final c = companyId.trim();
    return 'finance_controlling_plant_scope_v1_$c';
  }

  static Future<String> load(String companyId) async {
    final c = companyId.trim();
    if (c.isEmpty) return '';
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key(c));
    return (v ?? '').trim();
  }

  /// [plantKey] prazan briše pohranu (doseg „svi pogoni”).
  static Future<void> save(String companyId, String plantKey) async {
    final c = companyId.trim();
    if (c.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final k = _key(c);
    final t = plantKey.trim();
    if (t.isEmpty) {
      await p.remove(k);
    } else {
      await p.setString(k, t);
    }
  }
}
