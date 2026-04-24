import 'package:shared_preferences/shared_preferences.dart';

/// Opcionalni referentni budžet OEE gubitka (minute) po pogonu — za „cilj vs ostvareno“ u UI.
class DowntimeAnalyticsBudgetStore {
  static String _key(String companyId, String plantKey) =>
      'downtime_oee_loss_budget_min_${companyId.trim()}_${plantKey.trim()}';

  static Future<int?> load({
    required String companyId,
    required String plantKey,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_key(cid, pk));
    if (v == null || v <= 0) return null;
    return v;
  }

  static Future<void> save({
    required String companyId,
    required String plantKey,
    int? budgetMinutes,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    if (budgetMinutes == null || budgetMinutes <= 0) {
      await p.remove(_key(cid, pk));
    } else {
      await p.setInt(_key(cid, pk), budgetMinutes);
    }
  }
}
