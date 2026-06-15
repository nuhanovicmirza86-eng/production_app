/// Rezultat ručnog pokretanja `runFinanceAiAdvisoryAnalysis`.
class FinanceAiAnalysisResult {
  const FinanceAiAnalysisResult({
    required this.analysisRunId,
    required this.evaluatedRuleCount,
    required this.createdAlertCount,
    required this.updatedAlertCount,
    required this.resolvedAlertCount,
    required this.skippedInsufficientFactsCount,
    this.idempotentReplay = false,
  });

  final String analysisRunId;
  final int evaluatedRuleCount;
  final int createdAlertCount;
  final int updatedAlertCount;
  final int resolvedAlertCount;
  final int skippedInsufficientFactsCount;
  final bool idempotentReplay;

  factory FinanceAiAnalysisResult.fromMap(Map<String, dynamic> raw) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return FinanceAiAnalysisResult(
      analysisRunId: (raw['analysisRunId'] ?? '').toString(),
      evaluatedRuleCount: asInt(raw['evaluatedRuleCount']),
      createdAlertCount: asInt(raw['createdAlertCount']),
      updatedAlertCount: asInt(raw['updatedAlertCount']),
      resolvedAlertCount: asInt(raw['resolvedAlertCount']),
      skippedInsufficientFactsCount: asInt(raw['skippedInsufficientFactsCount']),
      idempotentReplay: raw['idempotentReplay'] == true,
    );
  }
}
