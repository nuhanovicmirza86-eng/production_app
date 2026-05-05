import 'package:cloud_functions/cloud_functions.dart';

/// Callable [runFinanceControllingAiInsight]: AI uvid nad `finance_kpi_snapshots`, sprema `finance_ai_insights`.
class FinanceAiInsightService {
  FinanceAiInsightService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static const String insightKindAnalysis = 'analysis';
  static const String insightKindWatchlist = 'watchlist';

  /// Vraća Markdown tekst za prikaz; dokument je i u Firestoreu.
  Future<({String insightId, String markdown, String insightKind})> runInsight({
    required String companyId,
    required String businessYearId,
    required int periodYear,
    required int periodMonth,
    String plantKey = '',
    String analysisFocus = '',
    String insightKind = insightKindAnalysis,
  }) async {
    final kind = insightKind.trim().toLowerCase() == insightKindWatchlist
        ? insightKindWatchlist
        : insightKindAnalysis;
    final res = await _functions
        .httpsCallable('runFinanceControllingAiInsight')
        .call(<String, dynamic>{
      'companyId': companyId.trim(),
      'businessYearId': businessYearId.trim(),
      'periodYear': periodYear,
      'periodMonth': periodMonth,
      'plantKey': plantKey.trim(),
      'insightKind': kind,
      if (analysisFocus.trim().isNotEmpty) 'analysisFocus': analysisFocus.trim(),
    });
    final raw = res.data;
    if (raw is! Map || raw['success'] != true) {
      throw StateError('Finance AI uvid nije uspio.');
    }
    final id = (raw['insightId'] ?? '').toString();
    final md = (raw['analysisMarkdown'] ?? '').toString();
    if (id.isEmpty || md.trim().isEmpty) {
      throw StateError('Neočekivani odgovor servera (AI).');
    }
    final kindOut = (raw['insightKind'] ?? kind).toString().trim();
    return (
      insightId: id,
      markdown: md.trim(),
      insightKind:
          kindOut.toLowerCase() == insightKindWatchlist
              ? insightKindWatchlist
              : insightKindAnalysis,
    );
  }
}
