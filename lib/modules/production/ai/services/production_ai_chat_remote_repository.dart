import 'package:cloud_functions/cloud_functions.dart';

import '../models/production_ai_chat_message.dart';

/// Povijest Operativnog asistenta — Callable [productionAiAssistantChat] (Admin SDK), ne direktan Firestore.
class ProductionAiChatRemoteRepository {
  ProductionAiChatRemoteRepository._();

  static const _kMaxMessages = 40;

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<List<ProductionAiChatMessage>> loadOnce(
    String companyId,
    String plantKey,
  ) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final callable = _functions.httpsCallable('productionAiAssistantChat');
    final raw = await callable.call<Map<String, dynamic>>({
      'op': 'get',
      'companyId': cid,
      'plantKey': pk,
    });
    final data = raw.data;
    if (data['success'] != true) return const [];
    return _parseMessages(data['messages']);
  }

  static List<ProductionAiChatMessage> _parseMessages(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ProductionAiChatMessage>[];
    for (final x in raw) {
      if (x is! Map) continue;
      try {
        out.add(
          ProductionAiChatMessage.fromJson(
            Map<String, dynamic>.from(x),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    if (out.length > _kMaxMessages) {
      return out.sublist(out.length - _kMaxMessages);
    }
    return out;
  }

  static Future<void> save(
    String companyId,
    String plantKey,
    List<ProductionAiChatMessage> messages,
  ) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;

    var list = messages;
    if (list.length > _kMaxMessages) {
      list = list.sublist(list.length - _kMaxMessages);
    }

    final callable = _functions.httpsCallable('productionAiAssistantChat');
    if (list.isEmpty) {
      await callable.call<Map<String, dynamic>>({
        'op': 'clear',
        'companyId': cid,
        'plantKey': pk,
      });
      return;
    }

    await callable.call<Map<String, dynamic>>({
      'op': 'set',
      'companyId': cid,
      'plantKey': pk,
      'messages': list.map((m) => m.toJson()).toList(),
    });
  }

  static Future<void> delete(String companyId, String plantKey) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;

    final callable = _functions.httpsCallable('productionAiAssistantChat');
    await callable.call<Map<String, dynamic>>({
      'op': 'clear',
      'companyId': cid,
      'plantKey': pk,
    });
  }
}
