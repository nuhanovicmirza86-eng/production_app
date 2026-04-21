import 'package:cloud_functions/cloud_functions.dart';

import 'teep_callable_service.dart';

/// Callable [upsertCapacityCalendar] — upis jednog dana u `capacity_calendars`.
///
/// Obavezno: [companyId], [plantKey], [calendarDateLocal], tri vremena u sekundama.
/// Za [scopeType] `plant` ostavi prazan [scopeId]; za `line` / `machine` unesi ID.
class CapacityCalendarCallableService {
  CapacityCalendarCallableService({FirebaseFunctions? functions})
      : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  Future<Map<String, dynamic>> upsertCapacityCalendar({
    required String companyId,
    required String plantKey,
    required DateTime calendarDateLocal,
    required int calendarTimeSeconds,
    required int scheduledOperatingTimeSeconds,
    required int plannedProductionTimeSeconds,
    String scopeType = 'plant',
    String scopeId = '',
    int? shiftCount,
    bool? isHoliday,
    bool? isWeekend,
    String? notes,
  }) async {
    final callable = _f.httpsCallable('upsertCapacityCalendar');
    final ymd = TeepCallableService.periodDateYmd(calendarDateLocal);
    final payload = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'calendarDate': ymd,
      'scopeType': scopeType.trim(),
      'scopeId': scopeId.trim(),
      'calendarTimeSeconds': calendarTimeSeconds,
      'scheduledOperatingTimeSeconds': scheduledOperatingTimeSeconds,
      'plannedProductionTimeSeconds': plannedProductionTimeSeconds,
    };
    if (shiftCount != null) payload['shiftCount'] = shiftCount;
    if (isHoliday != null) payload['isHoliday'] = isHoliday;
    if (isWeekend != null) payload['isWeekend'] = isWeekend;
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    final result = await callable.call(payload);
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
