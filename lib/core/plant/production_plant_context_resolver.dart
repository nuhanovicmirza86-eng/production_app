import 'package:cloud_firestore/cloud_firestore.dart';

/// Aligns Production maintenance-bridge screens with Maintenance
/// `report_fault_screen` plant resolution so `assets` queries use the same
/// [plantKey] as the operator sees there (e.g. [homePlantKey] vs [plantKey]).
class ProductionPlantContextResolver {
  ProductionPlantContextResolver._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Returns the plant key used for `assets` / faults when `company_plants`
  /// can be resolved; otherwise `null` (caller should fall back to session
  /// `plantKey`).
  static Future<String?> resolvePlantKeyForAssets({
    required String companyId,
    required Map<String, dynamic> userData,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return null;

    final directPlantKey = _s(userData['homePlantKey']).isNotEmpty
        ? _s(userData['homePlantKey'])
        : _s(userData['plantKey']);

    final legacyPlantId = _s(userData['homePlantId']).isNotEmpty
        ? _s(userData['homePlantId'])
        : _s(userData['plantId']);

    if (directPlantKey.isNotEmpty) {
      final byDocId = await FirebaseFirestore.instance
          .collection('company_plants')
          .doc('${cid}_$directPlantKey')
          .get();

      if (byDocId.exists) {
        return directPlantKey;
      }

      final q = await FirebaseFirestore.instance
          .collection('company_plants')
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: directPlantKey)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        return directPlantKey;
      }
    }

    if (legacyPlantId.isNotEmpty) {
      final q = await FirebaseFirestore.instance
          .collection('company_plants')
          .where('companyId', isEqualTo: cid)
          .where('legacyPlantId', isEqualTo: legacyPlantId)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        final plantKey = _s(d['plantKey']);
        if (plantKey.isNotEmpty) return plantKey;
      }
    }

    return null;
  }

  /// Resolver result, or [userData.plantKey] if resolution yields nothing.
  static Future<String> resolvePlantKeyOrFallback({
    required String companyId,
    required Map<String, dynamic> userData,
  }) async {
    final resolved = await resolvePlantKeyForAssets(
      companyId: companyId,
      userData: userData,
    );
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return _s(userData['plantKey']);
  }
}
