import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:production_app/core/access/production_access_helper.dart';

import 'production_admin_plant_preference.dart';

/// U [session] mapi (isti oblik kao [AuthWrapper] / MES kontekst) postavlja
/// `plantKey` iz [ProductionAdminPlantPreference] za admin / super_admin.
class ProductionAdminSessionPlant {
  ProductionAdminSessionPlant._();

  static Future<void> applyPreferenceIfAdmin(
    Map<String, dynamic> session,
  ) async {
    final norm = ProductionAccessHelper.normalizeRole(session['role']);
    if (!ProductionAccessHelper.isAdminRole(norm) &&
        !ProductionAccessHelper.isSuperAdminRole(norm)) {
      return;
    }
    final cid = (session['companyId'] ?? '').toString().trim();
    if (cid.isEmpty) return;
    final pref = (await ProductionAdminPlantPreference.load(cid) ?? '').trim();
    if (pref.isEmpty) return;
    if (await _plantExists(cid, pref)) {
      session['plantKey'] = pref;
    }
  }

  static Future<bool> _plantExists(String companyId, String plantKey) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return false;
    try {
      final byId = await FirebaseFirestore.instance
          .collection('company_plants')
          .doc('${cid}_$pk')
          .get();
      if (byId.exists) return true;
      final q = await FirebaseFirestore.instance
          .collection('company_plants')
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: pk)
          .limit(1)
          .get();
      return q.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
