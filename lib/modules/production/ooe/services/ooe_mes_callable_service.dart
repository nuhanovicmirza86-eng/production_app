import 'package:cloud_functions/cloud_functions.dart';

/// MES/OOE katalog (`ooe_loss_reasons`, `shift_contexts`) — Callable upisi.
class OoeMesCallableService {
  OoeMesCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  String _c(String? s) => (s ?? '').toString().trim();

  Future<String> upsertOoeLossReasonCreate({
    required String companyId,
    required String plantKey,
    required String code,
    required String name,
    String? description,
    required String category,
    String? tpmLossKey,
    required bool isPlanned,
    required bool affectsAvailability,
    required bool affectsPerformance,
    required bool affectsQuality,
    int sortOrder = 0,
  }) async {
    final h = _f.httpsCallable('upsertOoeLossReason');
    final m = <String, dynamic>{
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'code': code,
      'name': name,
      'category': category,
      'isPlanned': isPlanned,
      'affectsAvailability': affectsAvailability,
      'affectsPerformance': affectsPerformance,
      'affectsQuality': affectsQuality,
      'sortOrder': sortOrder,
    };
    if (description != null && description.trim().isNotEmpty) {
      m['description'] = description.trim();
    }
    if (tpmLossKey != null && _c(tpmLossKey).isNotEmpty) {
      m['tpmLossKey'] = tpmLossKey;
    }
    final r = await h.call(m);
    final d = r.data;
    if (d is Map) {
      final id = d['reasonId']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    throw Exception('Nevaždan odgovor (reasonId).');
  }

  Future<void> upsertOoeLossReasonUpdate({
    required String reasonId,
    required String companyId,
    required String plantKey,
    required String name,
    required String description,
    required String category,
    String tpmLossKey = '',
    required bool isPlanned,
    required bool affectsAvailability,
    required bool affectsPerformance,
    required bool affectsQuality,
    required bool active,
    required int sortOrder,
  }) async {
    final h = _f.httpsCallable('upsertOoeLossReason');
    await h.call({
      'reasonId': _c(reasonId),
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'name': name,
      'description': description,
      'category': category,
      'tpmLossKey': tpmLossKey,
      'isPlanned': isPlanned,
      'affectsAvailability': affectsAvailability,
      'affectsPerformance': affectsPerformance,
      'affectsQuality': affectsQuality,
      'active': active,
      'sortOrder': sortOrder,
    });
  }

  Future<void> upsertShiftContext({
    required String companyId,
    required String plantKey,
    required String shiftDateKey,
    required String shiftCode,
    required int operatingTimeSeconds,
    int plannedBreakSeconds = 0,
    int? plannedStartAtMs,
    int? plannedEndAtMs,
    bool isWorkingShift = true,
    bool active = true,
    String? notes,
    String? createdBy,
  }) async {
    final h = _f.httpsCallable('upsertShiftContext');
    final m = <String, dynamic>{
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'shiftDateKey': _c(shiftDateKey),
      'shiftCode': _c(shiftCode).toUpperCase(),
      'operatingTimeSeconds': operatingTimeSeconds,
      'plannedBreakSeconds': plannedBreakSeconds,
      'isWorkingShift': isWorkingShift,
      'active': active,
    };
    m['plannedStartAtMs'] = plannedStartAtMs;
    m['plannedEndAtMs'] = plannedEndAtMs;
    if (notes != null && _c(notes).isNotEmpty) {
      m['notes'] = _c(notes);
    }
    if (createdBy != null && _c(createdBy).isNotEmpty) {
      m['createdBy'] = _c(createdBy);
    }
    await h.call(m);
  }

  Future<void> deleteShiftContext({
    required String companyId,
    required String plantKey,
    required String shiftDateKey,
    required String shiftCode,
  }) async {
    final h = _f.httpsCallable('deleteShiftContext');
    await h.call({
      'companyId': _c(companyId),
      'plantKey': _c(plantKey),
      'shiftDateKey': _c(shiftDateKey),
      'shiftCode': _c(shiftCode).toUpperCase(),
    });
  }
}
