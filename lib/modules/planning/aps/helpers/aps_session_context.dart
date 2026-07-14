import '../../../../core/access/production_access_helper.dart';

/// APS operativni kontekst iz [companyData] sesije — bez Firestore round-tripa.
class ApsSessionContext {
  const ApsSessionContext({
    required this.companyData,
    required this.companyId,
    required this.plantKey,
    required this.role,
  });

  final Map<String, dynamic> companyData;
  final String companyId;
  final String plantKey;
  final String role;

  bool get accessOk => ProductionAccessHelper.canAccessApsP1Callable(
    role: role,
    companyData: companyData,
  );

  bool get hasPlantKey => plantKey.isNotEmpty;

  /// Brzo iz sesije (auth_wrapper / dashboard) — preferirano za APS ekrane.
  factory ApsSessionContext.fromCompanyData(Map<String, dynamic> companyData) {
    return ApsSessionContext(
      companyData: companyData,
      companyId: _companyIdFrom(companyData),
      plantKey: plantKeyFromMap(companyData),
      role: ProductionAccessHelper.normalizeRole(companyData['role']),
    );
  }

  static String _companyIdFrom(Map<String, dynamic> data) {
    return (data['companyId'] ?? data['id'] ?? '').toString().trim();
  }

  /// Isti redoslijed kao auth_wrapper `_plantKeyFromUserDoc`.
  static String plantKeyFromMap(Map<String, dynamic> data) {
    String s(dynamic v) => (v ?? '').toString().trim();
    final pk = s(data['plantKey']);
    if (pk.isNotEmpty) return pk;
    final home = s(data['homePlantKey']);
    if (home.isNotEmpty) return home;
    final aa = data['appAccess'];
    if (aa is Map) {
      final apk = s(aa['plantKey']);
      if (apk.isNotEmpty) return apk;
      return s(aa['homePlantKey']);
    }
    return '';
  }
}
