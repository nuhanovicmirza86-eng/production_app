import 'package:cloud_functions/cloud_functions.dart';

/// Povezuje [workTimeRecomputeMonthSummary] (agregat dnevnog u mjesečni).
class WorkTimeRecomputeService {
  WorkTimeRecomputeService({FirebaseFunctions? functions})
      : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  /// Samo admin tvrtke (usklađeno s backendom).
  Future<WorkTimeRecomputeResult> recomputeMonth({
    required String companyId,
    required String plantKey,
    required int year,
    required int month,
  }) async {
    final c = _fn.httpsCallable('workTimeRecomputeMonthSummary');
    final r = await c.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'year': year,
      'month': month,
    });
    final m = r.data;
    if (m is! Map) {
      return const WorkTimeRecomputeResult(
        ok: false,
        errorMessage: 'Neočekivan odgovor poslužitelja.',
      );
    }
    final map = Map<String, dynamic>.from(m);
    final ok = map['ok'] == true;
    if (!ok) {
      return WorkTimeRecomputeResult(
        ok: false,
        errorMessage: map['message']?.toString() ?? 'Greška',
      );
    }
    return WorkTimeRecomputeResult(
      ok: true,
      docId: map['docId']?.toString(),
      dailySummariesCount: (map['dailySummariesCount'] as num?)?.toInt(),
      fundHours: (map['fundHours'] as num?)?.toDouble(),
      settlementStatus: map['settlementStatus']?.toString(),
    );
  }
}

class WorkTimeRecomputeResult {
  const WorkTimeRecomputeResult({
    required this.ok,
    this.errorMessage,
    this.docId,
    this.dailySummariesCount,
    this.fundHours,
    this.settlementStatus,
  });

  final bool ok;
  final String? errorMessage;
  final String? docId;
  final int? dailySummariesCount;
  final double? fundHours;
  final String? settlementStatus;
}
