import 'package:cloud_functions/cloud_functions.dart';

/// Callable [aiChat] — slobodni chat (odvojeno od analize i operativnog asistenta).
class ProductionAiChatService {
  ProductionAiChatService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> sendMessage(String message) async {
    final m = message.trim();
    if (m.isEmpty) {
      throw StateError('Poruka je prazna.');
    }

    final callable = _functions.httpsCallable('aiChat');
    final raw = await callable.call<Map<String, dynamic>>({
      'message': m,
      'clientContext': 'production',
    });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Chat nije uspio.');
    }
    final text = (data['response'] ?? '').toString().trim();
    if (text.isEmpty) {
      throw StateError('Prazan odgovor.');
    }
    return text;
  }
}
