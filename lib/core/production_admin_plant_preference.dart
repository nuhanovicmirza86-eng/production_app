import 'package:shared_preferences/shared_preferences.dart';

/// Lokalno na uređaju: admin / super_admin u kompaniji može fiksirati **pogon rada**
/// za cijelu Production sesiju (npr. kad u `users.plantKey` nema vrijednosti).
///
/// Ključ je po [companyId] — više tvrtki na istom uređaju ne međusobno utječu.
class ProductionAdminPlantPreference {
  ProductionAdminPlantPreference._();

  static String _key(String companyId) {
    final c = companyId.trim();
    return 'production_admin_context_plant_v1_$c';
  }

  static Future<String?> load(String companyId) async {
    final c = companyId.trim();
    if (c.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key(c));
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static Future<void> save(String companyId, String plantKey) async {
    final c = companyId.trim();
    final pk = plantKey.trim();
    if (c.isEmpty || pk.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(c), pk);
  }

  static Future<void> clear(String companyId) async {
    final c = companyId.trim();
    if (c.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(c));
  }
}
