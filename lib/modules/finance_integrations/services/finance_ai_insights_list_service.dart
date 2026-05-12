import '../models/finance_ai_insight_doc.dart';
import 'finance_controlling_period_read_service.dart';

/// Povijest `finance_ai_insights` za period — isti Callable paket kao KPI/izvedeni agregati.
class FinanceAiInsightsListService {
  FinanceAiInsightsListService();

  final FinanceControllingPeriodReadService _reads =
      FinanceControllingPeriodReadService();

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
    return Stream.fromFuture(
      _reads
          .load(
            companyId: cid,
            businessYearId: by,
            periodYear: periodYear,
            periodMonth: periodMonth,
            plantKey: pk,
            aiInsightsLimit: lim,
          )
          .then((b) => b.aiInsights),
    );
  }
}
