// Production → Maintenance fault bridge: company `enabledModules` plus
// optional per-user `userAppAccess` (from `users.appAccess` in session).

List<String> enabledModulesLowerFromCompanyData(
  Map<String, dynamic> companyData,
) {
  final raw = companyData['enabledModules'];
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

bool companyDataHasEnabledModule(
  Map<String, dynamic> companyData,
  String moduleKey,
) {
  final normalized = moduleKey.trim().toLowerCase();
  final enabled = enabledModulesLowerFromCompanyData(companyData);
  if (enabled.isEmpty) {
    return normalized == 'production';
  }
  return enabled.contains(normalized);
}

/// If `userAppAccess` is missing or not a map, or [key] is absent → [whenMissing].
/// If [key] is present, only `== true` allows access.
bool userAppAccessFlagIsTrue(
  Map<String, dynamic> companyData,
  String key, {
  bool whenMissing = true,
}) {
  final aa = companyData['userAppAccess'];
  if (aa is! Map) return whenMissing;
  if (!aa.containsKey(key)) return whenMissing;
  return aa[key] == true;
}

bool maintenanceFaultBridgeEnabled(Map<String, dynamic> companyData) {
  return companyDataHasEnabledModule(companyData, 'maintenance') &&
      userAppAccessFlagIsTrue(companyData, 'maintenance');
}
