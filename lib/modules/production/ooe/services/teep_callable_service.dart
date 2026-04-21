import 'package:cloud_functions/cloud_functions.dart';

/// Callable [recomputeTeepPeriod] — upis `teep_summaries` + `utilization_summaries`.
///
/// **Ulaz (1:1 s backendom):**
/// - `companyId`, `plantKey` — obavezno
/// - `periodDate` — `YYYY-MM-DD` (sidro: dan, ili bilo koji dan u tjednu/mjesecu)
/// - `scopeType` — `plant` | `line` | `machine` (zadano `plant`; za line/machine treba `scopeId`)
/// - `scopeId` — prazan za plant; ID linije ili stroja inače
/// - `periodType` — `day` | `week` | `month` (zadano `day`)
/// - Ako za neki dan u periodu nema `capacity_calendars` (za isti scope), Callable traži
///   tri broja kao **zbir sekundi za cijeli period**: [calendarTimeSeconds],
///   [scheduledOperatingTimeSeconds], [plannedProductionTimeSeconds]
///
/// **Izlaz:** `success`, `teepSummaryId`, `utilizationSummaryId`, `periodKeyYmd`, itd.
class TeepCallableService {
  TeepCallableService({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  /// Isti format kao [OoeShiftSummaryCallableService.shiftDateYmd].
  static String periodDateYmd(DateTime localDate) {
    final d = localDate;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Preračun za odabrani opseg i period.
  Future<Map<String, dynamic>> recomputeTeepPeriod({
    required String companyId,
    required String plantKey,
    required DateTime periodDateLocal,
    String scopeType = 'plant',
    String scopeId = '',
    String periodType = 'day',
    int? calendarTimeSeconds,
    int? scheduledOperatingTimeSeconds,
    int? plannedProductionTimeSeconds,
  }) async {
    final callable = _f.httpsCallable('recomputeTeepPeriod');
    final ymd = periodDateYmd(periodDateLocal);
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'periodDate': ymd,
      'scopeType': scopeType.trim(),
      'scopeId': scopeId.trim(),
      'periodType': periodType.trim(),
    };
    if (calendarTimeSeconds != null) {
      payload['calendarTimeSeconds'] = calendarTimeSeconds;
    }
    if (scheduledOperatingTimeSeconds != null) {
      payload['scheduledOperatingTimeSeconds'] = scheduledOperatingTimeSeconds;
    }
    if (plannedProductionTimeSeconds != null) {
      payload['plannedProductionTimeSeconds'] = plannedProductionTimeSeconds;
    }
    final result = await callable.call(payload);
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
