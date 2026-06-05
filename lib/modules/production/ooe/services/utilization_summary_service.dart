import 'package:cloud_firestore/cloud_firestore.dart';

import '../../analytics/services/analytics_summary_reads_callable_service.dart';
import '../models/utilization_summary.dart';

/// Čitanje [utilization_summaries].
///
/// M4: Callable [listUtilizationSummaries] primarno; Firestore fallback privremeno.
class UtilizationSummaryService {
  UtilizationSummaryService({
    FirebaseFirestore? firestore,
    AnalyticsSummaryReadsCallableService? readsCallable,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _readsCallable =
           readsCallable ?? AnalyticsSummaryReadsCallableService();

  final FirebaseFirestore _db;
  final AnalyticsSummaryReadsCallableService _readsCallable;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('utilization_summaries');

  String _s(dynamic v) => (v ?? '').toString().trim();

  Stream<List<UtilizationSummary>> watchRecentForPlant({
    required String companyId,
    required String plantKey,
    int limit = 40,
  }) {
    final cid = _s(companyId);
    final pk = _s(plantKey);

    return AnalyticsSummaryReadsCallableService.watchWithCallablePrimary(
      fetchPrimary: () => _readsCallable.listUtilizationSummaries(
        companyId: cid,
        plantKey: pk,
        limit: limit,
      ),
      firestoreFallback: () => _col
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: pk)
          .orderBy('periodDate', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(UtilizationSummary.fromDoc).toList()),
    );
  }
}
