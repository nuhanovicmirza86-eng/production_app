import 'package:cloud_functions/cloud_functions.dart';

import '../models/ai_analysis_domain.dart';

/// Callable [runAiAnalysis] — strukturirani podaci (ne chat).
///
/// [payload] mora biti JSON-objekt (mapa); građu priprema UI/servis iz Firestore/modela.
class AiAnalysisService {
  AiAnalysisService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  /// Pokreće analizu na Vertex AI (backend).
  Future<AiAnalysisResult> run({
    required String companyId,
    String? plantKey,
    /// Kada je `true`, prazan [plantKey] šalje se u Callable (company-wide + domena generic|qms na backendu).
    bool allowEmptyPlantKey = false,
    required AiAnalysisDomain domain,
    required Map<String, dynamic> payload,
    String? analysisFocus,
  }) async {
    final cid = companyId.trim();
    final pk = (plantKey ?? '').trim();
    if (cid.isEmpty) {
      throw StateError('companyId je obavezan.');
    }
    if (pk.isEmpty && !allowEmptyPlantKey) {
      throw StateError('plantKey je obavezan.');
    }
    if (payload.isEmpty) {
      throw StateError('payload ne smije biti prazan.');
    }

    final body = <String, dynamic>{
      'companyId': cid,
      'domain': domain.apiValue,
      'payload': payload,
    };
    body['plantKey'] = pk;
    final focus = analysisFocus?.trim();
    if (focus != null && focus.isNotEmpty) {
      body['analysisFocus'] = focus;
    }

    final callable = _functions.httpsCallable('runAiAnalysis');
    final raw = await callable.call<Map<String, dynamic>>(body);
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('AI analiza nije uspjela.');
    }
    final md = (data['analysisMarkdown'] ?? '').toString().trim();
    if (md.isEmpty) {
      throw StateError('Prazan odgovor analize.');
    }
    return AiAnalysisResult(
      analysisMarkdown: md,
      domain: data['domain']?.toString() ?? domain.apiValue,
    );
  }
}

class AiAnalysisResult {
  final String analysisMarkdown;
  final String domain;

  const AiAnalysisResult({
    required this.analysisMarkdown,
    required this.domain,
  });
}
