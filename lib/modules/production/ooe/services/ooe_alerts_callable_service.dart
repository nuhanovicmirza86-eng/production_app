import 'package:cloud_functions/cloud_functions.dart';

class OoeAlertsCallableService {
  OoeAlertsCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  Future<Map<String, dynamic>> evaluate({
    required String companyId,
    required String plantKey,
  }) async {
    final callable = _f.httpsCallable('evaluateOoeAlerts');
    final r = await callable.call({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
    });
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return <String, dynamic>{};
  }

  Future<void> setStatus({
    required String companyId,
    required String alertId,
    required String status,
  }) async {
    final callable = _f.httpsCallable('setOoeAlertStatus');
    await callable.call({
      'companyId': companyId.trim(),
      'alertId': alertId.trim(),
      'status': status.trim(),
    });
  }
}
