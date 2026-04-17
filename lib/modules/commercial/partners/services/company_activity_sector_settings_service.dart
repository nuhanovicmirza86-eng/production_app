import 'package:cloud_functions/cloud_functions.dart';

import '../data/activity_sector_catalog.dart';

class CompanyActivitySectorSettingsService {
  CompanyActivitySectorSettingsService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Briše whitelist — u aplikaciji se ponovo prikazuje cijeli šifarnik.
  Future<void> saveUseAllCatalog({required String companyId}) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw Exception('Missing companyId');

    final res = await _functions
        .httpsCallable('updateCompanyActivitySectorSettings')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'useAllCatalog': true,
        });
    if (res.data['success'] != true) {
      throw Exception('Spremanje postavki djelatnosti nije uspjelo.');
    }
  }

  /// Whitelist: samo ove šifre u filterima i padajućim listama.
  Future<void> saveEnabledSubset({
    required String companyId,
    required List<String> enabledCodes,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) throw Exception('Missing companyId');

    final res = await _functions
        .httpsCallable('updateCompanyActivitySectorSettings')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'enabledCodes': enabledCodes,
        });
    if (res.data['success'] != true) {
      throw Exception('Spremanje postavki djelatnosti nije uspjelo.');
    }
  }

  /// Ako su uključene sve stavke iz kataloga, šalje [saveUseAllCatalog].
  Future<void> saveEnabledCodesSmart({
    required String companyId,
    required Set<String> enabledCodes,
  }) async {
    if (enabledCodes.length >= kActivitySectorCatalog.length) {
      await saveUseAllCatalog(companyId: companyId);
      return;
    }
    if (enabledCodes.isEmpty) {
      throw Exception('Barem jedna djelatnost mora biti uključena.');
    }
    final sorted = enabledCodes.toList()..sort();
    await saveEnabledSubset(companyId: companyId, enabledCodes: sorted);
  }
}
