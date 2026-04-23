import 'package:cloud_functions/cloud_functions.dart';

/// Spremanje polja na `companies` koje su u pravilima premještena na Callable
/// [updateCompanyOperationalConfig] (defekti, smjena, kolone operativnog praćenja).
class CompanyOperationalConfigService {
  CompanyOperationalConfigService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Payload mora sadržavati `companyId` i dopuštenu kombinaciju polja (vidi backend).
  Future<Map<String, dynamic>> updateOperationalConfig(
    Map<String, dynamic> payload,
  ) async {
    final res = await _functions
        .httpsCallable('updateCompanyOperationalConfig')
        .call<Map<String, dynamic>>(payload);
    final data = res.data;
    if (data['success'] != true) {
      throw StateError('Ažuriranje operativne konfiguracije kompanije nije uspjelo.');
    }
    return data;
  }
}
