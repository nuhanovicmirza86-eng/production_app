import '../../../core/access/production_access_helper.dart';

/// M1-I15-D-HOTFIX-28 — Čišćenje mašine / linije pokreće samo Operater proizvodnje.
const String lineClearanceProfileKey = 'line_clearance';

const String catalogEvidenceStartDeniedMessage =
    'Nemate pravo pokretanja ove evidencije.';

const String lineClearanceVerifierIdleTitle =
    'Nema evidencije koja čeka verifikaciju.';

const String lineClearanceVerifierIdleHint =
    'Novu evidenciju čišćenja pokreće Operater proizvodnje.';

bool isOperatorStartedLineClearanceProfile(String profileKey) {
  return profileKey.trim() == lineClearanceProfileKey;
}

bool _isTenantAdminRole(String role) {
  return ProductionAccessHelper.isAdminRole(role) ||
      role == ProductionAccessHelper.roleSuperAdmin;
}

bool isInEvidenceStartRuntimeRoles({
  required String userRole,
  required List<String> runtimeAllowedRoles,
}) {
  final role = ProductionAccessHelper.normalizeRole(userRole);
  if (_isTenantAdminRole(role)) return true;
  if (runtimeAllowedRoles.isEmpty) return false;
  return runtimeAllowedRoles.contains(role);
}

/// Pokretanje nove sesije — odvojeno od vidljivosti i verifikacije.
///
/// Čišćenje mašine / linije: samo Operater proizvodnje koji je u
/// start/runtime ulogama te evidencije. Verifikator (menadžer / kvaliteta)
/// ne pokreće, čak i ako je slučajno u runtimeAllowedRoles.
bool canStartCatalogEvidenceSession({
  required String profileKey,
  required String userRole,
  List<String> runtimeAllowedRoles = const [],
}) {
  final role = ProductionAccessHelper.normalizeRole(userRole);
  if (_isTenantAdminRole(role)) return true;
  if (isOperatorStartedLineClearanceProfile(profileKey)) {
    if (role != ProductionAccessHelper.roleProductionOperator) {
      return false;
    }
    return isInEvidenceStartRuntimeRoles(
      userRole: role,
      runtimeAllowedRoles: runtimeAllowedRoles,
    );
  }
  return true;
}
