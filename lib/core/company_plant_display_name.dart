import 'package:cloud_firestore/cloud_firestore.dart';

/// Naziv pogona iz `company_plants` (što kompanija definiše), ne samo `plantKey`.
class CompanyPlantDisplayName {
  CompanyPlantDisplayName._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String _labelFromPlantDoc(Map<String, dynamic> d, String fallbackKey) {
    final displayName = _s(d['displayName']);
    final defaultName = _s(d['defaultName']);
    final primaryName = _s(d['primaryName']);
    final plantCode = _s(d['plantCode']);
    final plantKey = _s(d['plantKey']);

    final baseName = displayName.isNotEmpty
        ? displayName
        : defaultName.isNotEmpty
            ? defaultName
            : primaryName.isNotEmpty
                ? primaryName
                : plantKey.isNotEmpty
                    ? plantKey
                    : fallbackKey;

    if (plantCode.isNotEmpty && baseName.isNotEmpty) {
      return '$baseName ($plantCode)';
    }
    return baseName.isNotEmpty ? baseName : fallbackKey;
  }

  static Future<String> resolve({
    required String companyId,
    required String plantKey,
    FirebaseFirestore? db,
  }) async {
    final fs = db ?? FirebaseFirestore.instance;
    final cId = _s(companyId);
    final pKey = _s(plantKey);
    if (cId.isEmpty) return pKey.isEmpty ? '-' : pKey;
    if (pKey.isEmpty) return '-';

    try {
      final byDocId =
          await fs.collection('company_plants').doc('${cId}_$pKey').get();
      if (byDocId.exists) {
        return _labelFromPlantDoc(byDocId.data() ?? {}, pKey);
      }

      final q = await fs
          .collection('company_plants')
          .where('companyId', isEqualTo: cId)
          .where('plantKey', isEqualTo: pKey)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        return _labelFromPlantDoc(q.docs.first.data(), pKey);
      }
    } catch (_) {}

    return pKey;
  }
}
