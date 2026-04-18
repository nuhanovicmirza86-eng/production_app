import 'package:cloud_functions/cloud_functions.dart';

/// Callable [productionTrackingAssistant] — pitanja nad praćenjem proizvodnje (MES kontekst).
class ProductionTrackingAssistantClientService {
  ProductionTrackingAssistantClientService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> ask({
    required String companyId,
    required String plantKey,
    required String prompt,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final p = prompt.trim();
    if (cid.isEmpty || pk.isEmpty || p.isEmpty) {
      throw StateError('companyId, plantKey i prompt su obavezni.');
    }
    if (p.length > 8000) {
      throw StateError('Predugačak upit.');
    }

    final callable = _functions.httpsCallable('productionTrackingAssistant');
    final raw = await callable.call<Map<String, dynamic>>({
      'companyId': cid,
      'plantKey': pk,
      'prompt': p,
    });
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Asistent nije uspio.');
    }
    final text = (data['reply'] ?? '').toString().trim();
    if (text.isEmpty) {
      throw StateError('Prazan odgovor.');
    }
    return text;
  }
}
