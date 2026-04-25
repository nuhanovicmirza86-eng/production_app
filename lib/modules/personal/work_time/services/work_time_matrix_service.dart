import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';

/// Učitava mjesečni ORV sažetak: Callable `workTimeGetMonthSummary` → lokalni demo pri grešci.
class WorkTimeMatrixService {
  WorkTimeMatrixService({FirebaseFunctions? functions})
    : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  Future<WorkTimeMatrixSnapshot> getMonthSnapshot({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return WorkTimeMatrixDemo.snapshotFor(year, month);
    }
    try {
      final c = _fn.httpsCallable('workTimeGetMonthSummary');
      final r = await c.call(<String, dynamic>{
        'companyId': cid,
        'plantKey': plantKey.trim(),
        'year': year,
        'month': month,
      });
      final d = r.data;
      if (d is Map) {
        return WorkTimeMatrixSnapshot.fromJson(
          Map<String, dynamic>.from(d),
        );
      }
    } catch (e, st) {
      debugPrint('workTimeGetMonthSummary fallback: $e $st');
    }
    return WorkTimeMatrixDemo.snapshotFor(year, month);
  }
}

/// Iste ključeve koriste production ekrani ([companyId], [plantKey] u sesiji).
String workTimeCompanyIdFrom(Map<String, dynamic> companyData) {
  return (companyData['companyId'] ?? '').toString().trim();
}

String workTimePlantKeyFrom(Map<String, dynamic> companyData) {
  return (companyData['plantKey'] ?? '').toString().trim();
}
