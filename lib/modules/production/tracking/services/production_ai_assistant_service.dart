import 'package:cloud_functions/cloud_functions.dart';

/// Callable `productionTrackingAssistant` (europe-west1) — Gemini na backendu.
class ProductionAiAssistantService {
  ProductionAiAssistantService({FirebaseFunctions? functions})
    : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  /// Vraća tekst odgovora ili baca [FirebaseFunctionsException] s porukom od servera.
  Future<String> sendPrompt({
    required String companyId,
    required String plantKey,
    required String prompt,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    final p = prompt.trim();
    if (cid.isEmpty) {
      throw ArgumentError('Nedostaje podatak o kompaniji. Obrati se administratoru.');
    }
    if (pk.isEmpty) {
      throw ArgumentError('Nedostaje plantKey.');
    }
    if (p.isEmpty) {
      throw ArgumentError('Upit je prazan.');
    }

    final res = await _fn
        .httpsCallable('productionTrackingAssistant')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'plantKey': pk,
          'prompt': p,
        });
    final data = res.data;
    final reply = data['reply'] ?? data['message'] ?? data['text'];
    final s = reply?.toString().trim() ?? '';
    if (s.isEmpty) {
      throw StateError('Prazan odgovor s poslužitelja.');
    }
    return s;
  }
}
