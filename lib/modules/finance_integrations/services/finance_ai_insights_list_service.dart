import '../models/finance_ai_insight_doc.dart';
import 'finance_controlling_period_read_service.dart';

/// Povijest `finance_ai_insights` za period — isti Callable paket kao KPI/izvedeni agregati.
class FinanceAiInsightsListService {
  FinanceAiInsightsListService();

  final FinanceControllingPeriodReadService _reads =
      FinanceControllingPeriodReadService();

  Future<List<FinanceAiInsightDoc>> loadRecentForPeriod({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
    int limit = 12,
  }) async {
    final cid = companyId.trim();
    final by = businessYearId.trim();
    if (cid.isEmpty || by.isEmpty) {
      return const [];
    }
    final pk = plantKey.trim();
    final lim = limit.clamp(1, 50);
    final bundle = await _reads.load(
      companyId: cid,
      businessYearId: by,
      periodYear: periodYear,
      periodMonth: periodMonth,
      plantKey: pk,
      aiInsightsLimit: lim,
    );
    return bundle.aiInsights;
  }

  Stream<List<FinanceAiInsightDoc>> watchRecentForPeriod({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
    int limit = 12,
  }) {
    return Stream.fromFuture(
      loadRecentForPeriod(
        companyId: companyId,
        businessYearId: businessYearId,
        periodYear: periodYear,
        periodMonth: periodMonth,
        plantKey: plantKey,
        limit: limit,
      ),
    ).asBroadcastStream();
  }
}
