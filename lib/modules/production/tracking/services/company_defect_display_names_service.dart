import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/platform_defect_codes.dart';

/// Snimanje `companies.defectDisplayNames` (samo DEF_001 … DEF_015).
class CompanyDefectDisplayNamesService {
  CompanyDefectDisplayNamesService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> save({
    required String companyId,
    required Map<String, String> displayNamesByCode,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return;
    final clean = <String, String>{};
    for (final code in PlatformDefectCodes.allCodes) {
      final v = displayNamesByCode[code]?.trim() ?? '';
      if (v.isNotEmpty) clean[code] = v;
    }
    await _db.collection('companies').doc(cid).update({
      defectDisplayNamesKey: clean,
    });
  }
}
