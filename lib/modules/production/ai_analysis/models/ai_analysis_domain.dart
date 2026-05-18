/// Usklađeno s backend Callable [runAiAnalysis] (`domain`).
enum AiAnalysisDomain {
  scada,
  oee,
  productionFlow,
  generic,
  /// QMS / kvaliteta (Callable [runAiAnalysis], domena `qms`) — RBAC `quality_qms` + modul quality.
  qms,
}

extension AiAnalysisDomainApi on AiAnalysisDomain {
  /// Vrijednost koju očekuje Cloud Function.
  String get apiValue {
    switch (this) {
      case AiAnalysisDomain.scada:
        return 'scada';
      case AiAnalysisDomain.oee:
        return 'oee';
      case AiAnalysisDomain.productionFlow:
        return 'production_flow';
      case AiAnalysisDomain.generic:
        return 'generic';
      case AiAnalysisDomain.qms:
        return 'qms';
    }
  }
}
