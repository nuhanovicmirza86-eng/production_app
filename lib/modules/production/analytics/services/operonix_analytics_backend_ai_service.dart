import '../../ai_analysis/models/ai_analysis_domain.dart';
import '../../ai_analysis/services/ai_analysis_service.dart';

import '../models/analytics_summary_model.dart';
import 'operonix_analytics_ai_payload.dart';

/// [runAiAnalysis] (Vertex/Gemini) iz snimka Operonix Analytics dashboarda.
class OperonixAnalyticsBackendAiService {
  OperonixAnalyticsBackendAiService({AiAnalysisService? analysis})
    : _analysis = analysis ?? AiAnalysisService();

  final AiAnalysisService _analysis;

  /// Vraća Markdown s backend analizom (isti Callable kao ekran „AI analiza”).
  Future<String> runAnalysis({
    required String companyId,
    required String plantKey,
    required OperonixAnalyticsSnapshot snapshot,
  }) async {
    final payload = OperonixAnalyticsAiPayload.build(snapshot);
    final res = await _analysis.run(
      companyId: companyId,
      plantKey: plantKey,
      domain: AiAnalysisDomain.oee,
      payload: payload,
      analysisFocus:
          'Operonix Analytics: poveži TEEP (OEE/OOE/TEEP) s Pareto zastoja i radnim centrima. '
          'Bosanski, sažetak za menadžment, konkretne preporuke (prioritet), spomeni IATF ako ima smisla. '
          'Ako nema TEEP dana, osloni se na zastoje iz downtimeSummary.',
    );
    return res.analysisMarkdown;
  }
}
