import 'package:cloud_functions/cloud_functions.dart';

/// Callables: uređaji, događaji, korekcije, status, izvoz (ORV cijeli lanac).
class WorkTimeOperationalService {
  WorkTimeOperationalService({FirebaseFunctions? functions})
      : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  Future<List<Map<String, dynamic>>> listDevices({
    required String companyId,
  }) async {
    final c = _fn.httpsCallable('workTimeListDevices');
    final r = await c.call(<String, dynamic>{'companyId': companyId});
    final d = r.data;
    if (d is! Map) return [];
    final items = d['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String?> upsertDevice({
    required String companyId,
    required String plantKey,
    required String displayName,
    String? deviceId,
    String networkLabel = '',
    bool isActive = true,
  }) async {
    final c = _fn.httpsCallable('workTimeUpsertDevice');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'displayName': displayName,
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      'networkLabel': networkLabel,
      'isActive': isActive,
    });
    final d = r.data;
    if (d is! Map) return null;
    return d['deviceId']?.toString();
  }

  Future<List<Map<String, dynamic>>> listEvents({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
  }) async {
    final c = _fn.httpsCallable('workTimeListEvents');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'year': year,
      'month': month,
    });
    final d = r.data;
    if (d is! Map) return [];
    final items = d['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String?> recordEvent({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    required String eventKind, // in | out
    required String occurredAtIso,
    String deviceId = '',
    String? idempotencyKey,
  }) async {
    final c = _fn.httpsCallable('workTimeRecordEvent');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      'eventKind': eventKind,
      'occurredAtIso': occurredAtIso,
      'deviceId': deviceId,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotencyKey': idempotencyKey,
    });
    final d = r.data;
    if (d is! Map) return null;
    return d['eventId']?.toString();
  }

  Future<Map<String, dynamic>> recomputeDailySummariesForMonth({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
  }) async {
    final c = _fn.httpsCallable('workTimeRecomputeDailySummariesForMonth');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'year': year,
      'month': month,
    });
    final d = r.data;
    if (d is! Map) return {};
    return Map<String, dynamic>.from(d);
  }

  Future<List<Map<String, dynamic>>> listCorrections({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
  }) async {
    final c = _fn.httpsCallable('workTimeListCorrections');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'year': year,
      'month': month,
    });
    final d = r.data;
    if (d is! Map) return [];
    final items = d['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Spec: items u [data.items].
  Future<String?> createCorrection({
    required String companyId,
    required String plantKey,
    required String employeeDocId,
    required String dateKeyYyyyMmDd,
    required String reason,
    double? overrideWorkedHours,
  }) async {
    final c = _fn.httpsCallable('workTimeCreateCorrection');
    final p = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'employeeDocId': employeeDocId,
      'dateKey': dateKeyYyyyMmDd,
      'reason': reason,
    };
    if (overrideWorkedHours != null) p['overrideWorkedHours'] = overrideWorkedHours;
    final r = await c.call(p);
    final d = r.data;
    if (d is! Map) return null;
    return d['correctionId']?.toString();
  }

  Future<void> resolveCorrection({
    required String companyId,
    required String correctionId,
    required String resolution, // approved | rejected
  }) async {
    final c = _fn.httpsCallable('workTimeResolveCorrection');
    await c.call(<String, dynamic>{
      'companyId': companyId,
      'correctionId': correctionId,
      'resolution': resolution,
    });
  }

  Future<void> setMonthSettlementStatus({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
    required String settlementStatus,
  }) async {
    final c = _fn.httpsCallable('workTimeSetMonthSettlementStatus');
    await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'year': year,
      'month': month,
      'settlementStatus': settlementStatus,
    });
  }

  /// Vraća `csv` ako backend pošalje puni zapis; inače prazan string.
  Future<Map<String, dynamic>> createPayrollExport({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
  }) async {
    final c = _fn.httpsCallable('workTimeCreatePayrollExport');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'year': year,
      'month': month,
    });
    final d = r.data;
    if (d is! Map) return {};
    return Map<String, dynamic>.from(d);
  }

  Future<List<Map<String, dynamic>>> listPayrollExports({
    required String companyId,
  }) async {
    final c = _fn.httpsCallable('workTimeListPayrollExports');
    final r = await c.call(<String, dynamic>{'companyId': companyId});
    final d = r.data;
    if (d is! Map) return [];
    final items = d['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// null [employeeDocIds] = nema ograničenja (ili nije menadžer s dodjelom).
  Future<({bool restricted, List<String>? employeeDocIds})> listMyManagedEmployees({
    required String companyId,
    required String plantKey,
  }) async {
    final c = _fn.httpsCallable('workTimeListMyManagedEmployees');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
    });
    final d = r.data;
    if (d is! Map) {
      return (restricted: false, employeeDocIds: null);
    }
    final rest = d['restricted'] == true;
    final raw = d['employeeDocIds'];
    if (!rest || raw is! List) {
      return (restricted: false, employeeDocIds: null);
    }
    final ids = raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    return (restricted: true, employeeDocIds: ids);
  }

  Future<List<Map<String, dynamic>>> listOrvAssignmentManagers({
    required String companyId,
  }) async {
    final c = _fn.httpsCallable('workTimeListOrvAssignmentManagers');
    final r = await c.call(<String, dynamic>{'companyId': companyId});
    final d = r.data;
    if (d is! Map) return [];
    final items = d['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listManagerAssignments({
    required String companyId,
    required String plantKey,
  }) async {
    final c = _fn.httpsCallable('workTimeListManagerAssignments');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
    });
    final d = r.data;
    if (d is! Map) return [];
    final items = d['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> setManagerAssignment({
    required String companyId,
    required String plantKey,
    required String managerUid,
    required List<String> employeeDocIds,
  }) async {
    final c = _fn.httpsCallable('workTimeSetManagerAssignment');
    await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'managerUid': managerUid,
      'employeeDocIds': employeeDocIds,
    });
  }
}
