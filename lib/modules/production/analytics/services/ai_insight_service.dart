import '../models/ai_insight_model.dart';
import '../models/analytics_summary_model.dart';
import 'operonix_analytics_narrator.dart';

/// Ulaz u automatske uvide (trenutno rules-based, isti modul može kasnije zvati backend).
class AiInsightService {
  OperonixAiInsight buildInsight(OperonixAnalyticsSnapshot snapshot) {
    return OperonixAnalyticsNarrator.build(snapshot);
  }
}
