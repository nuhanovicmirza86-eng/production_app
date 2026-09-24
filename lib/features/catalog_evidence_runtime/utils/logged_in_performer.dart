import '../../../core/access/production_access_helper.dart';

/// M1-I15-D-HOTFIX-24 — Izvršio iz prijavljenog Operatera proizvodnje.
const String performedByEmployeeFieldKey = 'performedByEmployeeId';
const String performedByNameSnapshotFieldKey = 'performedByNameSnapshot';

const String loggedInPerformerAutofillHelper =
    'Popunjeno iz prijavljenog operatera. Nije potrebna pretraga.';

/// M1-I15-D-HOTFIX-30 — Finalna kontrola: Operater kvaliteta = prijavljeni korisnik.
const String loggedInFinalControlQualityOperatorHelper =
    'Automatski iz prijave — samo uloga Operater kvaliteta. '
    'Nije slobodan unos imena.';

const String finalControlQualityOperatorFinishDeniedMessage =
    'Finalnu kontrolu može završiti samo Operater kvaliteta.';

bool profileSupportsLoggedInPerformerAutofill(String profileKey) {
  final key = profileKey.trim();
  return key == 'line_clearance' || key == 'workspace_5s_cleaning';
}

bool shouldAutofillPerformedByFromLoggedInOperator({
  required String profileKey,
  required String userRole,
}) {
  if (!profileSupportsLoggedInPerformerAutofill(profileKey)) return false;
  return ProductionAccessHelper.normalizeRole(userRole) ==
      ProductionAccessHelper.roleProductionOperator;
}

bool shouldLockPerformedByField({
  required bool autofillFromLoggedInOperator,
  required bool verifierHandoff,
}) {
  return autofillFromLoggedInOperator || verifierHandoff;
}

bool shouldAutofillFinalControlQualityOperator({
  required String profileKey,
  required String userRole,
}) {
  if (profileKey.trim() != 'final_control') return false;
  return ProductionAccessHelper.normalizeRole(userRole) ==
      ProductionAccessHelper.roleQualityOperator;
}

/// Ime za Izvršio — bez e-maila, UID-a i crtice.
String loggedInPerformerDisplayName(Map<String, dynamic> companyData) {
  for (final key in [
    'userDisplayName',
    'nickname',
    'displayName',
    'fullName',
  ]) {
    final value = (companyData[key] ?? '').toString().trim();
    if (_isPresentablePersonName(value)) return value;
  }
  final first = (companyData['firstName'] ?? '').toString().trim();
  final last = (companyData['lastName'] ?? '').toString().trim();
  final combined = '$first $last'.trim();
  if (_isPresentablePersonName(combined)) return combined;
  return '';
}

bool _isPresentablePersonName(String value) {
  final t = value.trim();
  if (t.isEmpty || t == '—' || t == '-') return false;
  if (t.contains('@')) return false;
  if (RegExp(r'^PLANT_\d+$', caseSensitive: false).hasMatch(t)) return false;
  if (t.length >= 16 &&
      t.length <= 32 &&
      !t.contains(' ') &&
      !t.contains('-') &&
      !t.contains('_') &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(t)) {
    return false;
  }
  return true;
}
