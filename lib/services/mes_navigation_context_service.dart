import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/access/production_access_helper.dart';
import '../core/production_admin_session_plant.dart';

/// Minimalni [companyData] za MES push / dubinske veze (bez stanice / launch faze).
class MesNavigationContextService {
  MesNavigationContextService._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String _companyIdFromField(dynamic raw) {
    if (raw is DocumentReference) return raw.id.trim();
    return _s(raw);
  }

  /// Vraća isti oblik ključeva kao [AuthWrapper] za navigacijske ekrane.
  static Future<Map<String, dynamic>?> loadForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return null;

    final data = userDoc.data() ?? <String, dynamic>{};
    final status = _s(data['status']).toLowerCase();
    if (status != 'active') return null;

    final rawAppAccess = data['appAccess'];
    final appAccess = rawAppAccess is Map<String, dynamic>
        ? rawAppAccess
        : <String, dynamic>{};
    if (appAccess['production'] != true) return null;

    final role = _s(data['role']).toLowerCase();
    if (role.isEmpty) return null;

    final companyId = _companyIdFromField(data['companyId']);
    if (companyId.isEmpty) return null;

    final plantKey = _s(data['plantKey']);
    final normRole = ProductionAccessHelper.normalizeRole(role);
    final globalTenantAdmin =
        ProductionAccessHelper.isAdminRole(normRole) ||
            ProductionAccessHelper.isSuperAdminRole(normRole);
    if (plantKey.isEmpty && !globalTenantAdmin) return null;

    final companyDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();

    if (!companyDoc.exists) return null;

    final company = companyDoc.data() ?? <String, dynamic>{};
    if (company['active'] != true) return null;

    final session = {
      ...company,
      'companyId': companyId,
      'userId': user.uid,
      'role': role,
      'plantKey': plantKey,
      'userHomePlantKey': _s(data['homePlantKey']),
      'userHomePlantId': _s(data['homePlantId']),
      'userLegacyPlantId': _s(data['plantId']),
      'userAppAccess': appAccess,
      'userDisplayName': _s(data['displayName']),
      'nickname': _s(data['nickname']),
      'userEmail': _s(data['email'] ?? user.email ?? ''),
    };
    await ProductionAdminSessionPlant.applyPreferenceIfAdmin(session);
    return session;
  }
}
