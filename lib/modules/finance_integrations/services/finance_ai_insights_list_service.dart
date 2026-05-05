import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_ai_insight_doc.dart';

/// Čitanje povijesti `finance_ai_insights` za isti period kao KPI snimak.
class FinanceAiInsightsListService {
  FinanceAiInsightsListService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<FinanceAiInsightDoc>> watchRecentForPeriod({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
    int limit = 12,
  }) {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    if (cid.isEmpty || by.isEmpty) {
      return Stream<List<FinanceAiInsightDoc>>.value(const []);
    }
    final pk = plantKey.trim();
    final lim = limit.clamp(1, 50);
    Query<Map<String, dynamic>> q = _db
        .collection('finance_ai_insights')
        .where('companyId', isEqualTo: cid)
        .where('businessYearId', isEqualTo: by)
        .where('periodYear', isEqualTo: periodYear)
        .where('periodMonth', isEqualTo: periodMonth)
        .where('plantKey', isEqualTo: pk)
        .orderBy('createdAt', descending: true)
        .limit(lim);

    return q.snapshots().map(
          (snap) => snap.docs
              .map((d) => FinanceAiInsightDoc.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }
}
