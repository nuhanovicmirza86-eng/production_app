import 'package:cloud_functions/cloud_functions.dart';

/// Callable [recomputeDowntimeAnalyticsDaily] — preračun jednog dana u [analytics_downtime_daily].
class AnalyticsDowntimeDailyCallableService {
  AnalyticsDowntimeDailyCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  static String dateYmd(DateTime localDate) {
    final d = localDate;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<Map<String, dynamic>> recomputeDaily({
    required String companyId,
    required String plantKey,
    required String summaryDateYmd,
    bool includeRejected = false,
    String timeZone = 'Europe/Sarajevo',
  }) async {
    final callable = _f.httpsCallable('recomputeDowntimeAnalyticsDaily');
    final result = await callable.call({
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'summaryDateYmd': summaryDateYmd.trim(),
      'includeRejected': includeRejected,
      'timeZone': timeZone.trim().isEmpty ? 'Europe/Sarajevo' : timeZone.trim(),
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
