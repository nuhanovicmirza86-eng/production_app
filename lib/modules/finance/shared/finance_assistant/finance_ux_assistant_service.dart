import 'package:cloud_functions/cloud_functions.dart';

import 'finance_assistant_context.dart';

class FinanceUxAssistantResponse {
  const FinanceUxAssistantResponse({
    required this.answer,
    required this.conversationId,
    required this.turnId,
    required this.language,
    required this.screenKey,
    required this.knowledgeVersion,
    required this.suggestedQuestions,
    required this.limitations,
    required this.fromServer,
  });

  final String answer;
  final String conversationId;
  final String turnId;
  final String language;
  final String screenKey;
  final String knowledgeVersion;
  final List<String> suggestedQuestions;
  final List<String> limitations;
  final bool fromServer;

  factory FinanceUxAssistantResponse.fromMap(Map<String, dynamic> map) {
    return FinanceUxAssistantResponse(
      answer: (map['answer'] ?? '').toString(),
      conversationId: (map['conversationId'] ?? '').toString(),
      turnId: (map['turnId'] ?? '').toString(),
      language: (map['language'] ?? 'ba').toString(),
      screenKey: (map['screenKey'] ?? '').toString(),
      knowledgeVersion: (map['knowledgeVersion'] ?? '').toString(),
      suggestedQuestions: _stringList(map['suggestedQuestions']),
      limitations: _stringList(map['limitations']),
      fromServer: true,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
}

/// Klijent za Callable `askFinanceUxAssistant` (M1 backend).
class FinanceUxAssistantService {
  FinanceUxAssistantService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  static const _callableName = 'askFinanceUxAssistant';
  final FirebaseFunctions _functions;

  Future<FinanceUxAssistantResponse> ask({
    required String companyId,
    required String locale,
    required String question,
    required FinanceAssistantContext contextData,
    String? conversationId,
    String? prefilledQuestionKey,
  }) async {
    final callable = _functions.httpsCallable(_callableName);
    final payload = <String, dynamic>{
      'companyId': companyId,
      'locale': locale,
      'question': question,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversationId': conversationId,
      if (prefilledQuestionKey != null && prefilledQuestionKey.isNotEmpty)
        'prefilledQuestionKey': prefilledQuestionKey,
      'context': contextData.toCallableContext(),
    };
    final result = await callable.call(payload);
    final data = result.data;
    if (data is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Neispravan odgovor Finance asistenta.',
      );
    }
    final map = Map<String, dynamic>.from(data);
    if (map['success'] == false) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: (map['message'] ?? 'Finance asistent nije dostupan.').toString(),
      );
    }
    return FinanceUxAssistantResponse.fromMap(map);
  }
}
