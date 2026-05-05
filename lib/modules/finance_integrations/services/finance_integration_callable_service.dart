import 'package:cloud_functions/cloud_functions.dart';

/// Callablei integracijskog sloja (test veze, poslovi, veze dokumenata).
class FinanceIntegrationCallableService {
  FinanceIntegrationCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<FinanceConnectionTestResult> testFinanceConnection({
    required String companyId,
    required String connectionId,
  }) async {
    final res = await _functions
        .httpsCallable('testFinanceConnection')
        .call(<String, dynamic>{
          'companyId': companyId.trim(),
          'connectionId': connectionId.trim(),
        });
    final raw = res.data;
    if (raw is! Map) {
      throw StateError('Neočekivani odgovor testa veze.');
    }
    return FinanceConnectionTestResult(
      success: raw['success'] == true,
      reachable: raw['reachable'] == true,
      httpStatus: (raw['httpStatus'] is num)
          ? (raw['httpStatus'] as num).toInt()
          : null,
      detail: (raw['detail'] ?? '').toString(),
    );
  }

  Future<void> retryFinanceSyncJob({
    required String companyId,
    required String jobId,
  }) async {
    final res = await _functions
        .httpsCallable('retryFinanceSyncJob')
        .call(<String, dynamic>{
          'companyId': companyId.trim(),
          'jobId': jobId.trim(),
        });
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Ponovno pokretanje posla nije uspjelo.');
    }
  }

  Future<void> cancelFinanceSyncJob({
    required String companyId,
    required String jobId,
  }) async {
    final res = await _functions
        .httpsCallable('cancelFinanceSyncJob')
        .call(<String, dynamic>{
          'companyId': companyId.trim(),
          'jobId': jobId.trim(),
        });
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Otkazivanje posla nije uspjelo.');
    }
  }

  Future<String> upsertFinanceDocumentLink({
    required String companyId,
    required String connectionId,
    required String provider,
    required String operonixEntityType,
    required String operonixEntityId,
    String operonixModule = '',
    String erpEntityType = '',
    String erpEntityId = '',
    String erpDocumentNumber = '',
    String plantKey = '',
    String businessYearId = '',
    String? linkId,
    String currency = '',
    double? amountNet,
    double? amountGross,
    String syncStatus = 'linked',
  }) async {
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'connectionId': connectionId.trim(),
      'provider': provider.trim().toLowerCase(),
      'operonixEntityType': operonixEntityType.trim(),
      'operonixEntityId': operonixEntityId.trim(),
      'operonixModule': operonixModule.trim(),
      'erpEntityType': erpEntityType.trim(),
      'erpEntityId': erpEntityId.trim(),
      'erpDocumentNumber': erpDocumentNumber.trim(),
      'plantKey': plantKey.trim(),
      'businessYearId': businessYearId.trim(),
      'currency': currency.trim(),
      'syncStatus': syncStatus.trim(),
    };
    if (linkId != null && linkId.trim().isNotEmpty) {
      payload['linkId'] = linkId.trim();
    }
    if (amountNet != null) payload['amountNet'] = amountNet;
    if (amountGross != null) payload['amountGross'] = amountGross;

    final res = await _functions
        .httpsCallable('upsertFinanceDocumentLink')
        .call(payload);
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Spremanje veze dokumenta nije uspjelo.');
    }
    return (raw['linkId'] ?? '').toString();
  }

  Future<Map<String, dynamic>> getAdapterManifest() async {
    final res = await _functions
        .httpsCallable('getFinanceIntegrationAdapterManifest')
        .call(<String, dynamic>{});
    final raw = res.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {};
  }
}

class FinanceConnectionTestResult {
  const FinanceConnectionTestResult({
    required this.success,
    required this.reachable,
    this.httpStatus,
    required this.detail,
  });

  final bool success;
  final bool reachable;
  final int? httpStatus;
  final String detail;
}
