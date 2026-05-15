import '../../../../core/company_operational_config_service.dart';
import '../config/platform_defect_codes.dart';

/// Snimanje `companies.defectDisplayNames` (samo DEF_001 … DEF_015) preko Callabla
/// [updateCompanyOperationalConfig] — bez direktnog Firestore SDK write-a na root `companies`.
class CompanyDefectDisplayNamesService {
  CompanyDefectDisplayNamesService({
    CompanyOperationalConfigService? operationalConfig,
  }) : _ops = operationalConfig ?? CompanyOperationalConfigService();

  final CompanyOperationalConfigService _ops;

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
    await _ops.updateOperationalConfig(<String, dynamic>{
      'companyId': cid,
      'defectDisplayNames': clean,
    });
  }
}
