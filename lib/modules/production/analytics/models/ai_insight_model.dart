/// Rules-based „OperonixAI” blok (bez LLM-a u prvoj verziji).
class OperonixAiInsight {
  const OperonixAiInsight({
    required this.title,
    required this.summary,
    required this.mainCauses,
    required this.recommendations,
    this.riskNote,
    this.comparisonNote,
  });

  final String title;
  final String summary;
  final List<String> mainCauses;
  final List<String> recommendations;
  final String? riskNote;
  final String? comparisonNote;
}
