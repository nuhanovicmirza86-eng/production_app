import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/production_ai_chat_message.dart';
import 'production_ai_chat_remote_repository.dart';

/// Lokalni cache + Callable (isti thread na uređajima za istog korisnika i pogon).
class ProductionAiChatPersistence {
  ProductionAiChatPersistence._();

  static const _kVersion = 'v1';
  static const _kMaxMessages = 40;

  static String _storageKey(String companyId, String plantKey) {
    final c = Uri.encodeComponent(companyId.trim());
    final p = Uri.encodeComponent(plantKey.trim());
    return 'prod_ai_operational_thread_${_kVersion}_${c}_$p';
  }

  static Future<List<ProductionAiChatMessage>> _loadLocal(
    String companyId,
    String plantKey,
  ) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(cid, pk));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <ProductionAiChatMessage>[];
      for (final x in decoded) {
        if (x is! Map) continue;
        out.add(
          ProductionAiChatMessage.fromJson(
            Map<String, dynamic>.from(x),
          ),
        );
      }
      if (out.length > _kMaxMessages) {
        return out.sublist(out.length - _kMaxMessages);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveLocal(
    String companyId,
    String plantKey,
    List<ProductionAiChatMessage> messages,
  ) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(cid, pk);
    if (messages.isEmpty) {
      await prefs.remove(key);
      return;
    }

    var list = messages;
    if (list.length > _kMaxMessages) {
      list = list.sublist(list.length - _kMaxMessages);
    }

    final encoded = jsonEncode(list.map((m) => m.toJson()).toList());
    await prefs.setString(key, encoded);
  }

  /// Učitaj: prvo oblak (ako je prijava), inače lokalno; prazno u oblaku + puno lokalno → upload.
  static Future<List<ProductionAiChatMessage>> load(
    String companyId,
    String plantKey,
  ) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final local = await _loadLocal(cid, pk);
    final loggedIn = FirebaseAuth.instance.currentUser != null;

    if (!loggedIn) {
      return local;
    }

    try {
      final remote =
          await ProductionAiChatRemoteRepository.loadOnce(cid, pk);
      if (remote.isNotEmpty) {
        await _saveLocal(cid, pk, remote);
        return remote;
      }
      if (local.isNotEmpty) {
        await ProductionAiChatRemoteRepository.save(cid, pk, local);
        return local;
      }
      return const [];
    } catch (_) {
      return local;
    }
  }

  /// Ponovno učitaj iz oblaka (npr. povratak u aplikaciju) bez migracije s praznog u puno lokalno ako oblak kaže prazno.
  static Future<List<ProductionAiChatMessage>> reloadFromCloud(
    String companyId,
    String plantKey,
  ) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    if (FirebaseAuth.instance.currentUser == null) {
      return _loadLocal(cid, pk);
    }

    try {
      final remote =
          await ProductionAiChatRemoteRepository.loadOnce(cid, pk);
      if (remote.isNotEmpty) {
        await _saveLocal(cid, pk, remote);
        return remote;
      }
      return _loadLocal(cid, pk);
    } catch (_) {
      return _loadLocal(cid, pk);
    }
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

    await _saveLocal(cid, pk, list);

    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await ProductionAiChatRemoteRepository.save(cid, pk, list);
    } catch (_) {
      // Offline — ostaje lokalni cache.
    }
  }

  static Future<void> clear(String companyId, String plantKey) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;

    await _saveLocal(cid, pk, const []);

    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await ProductionAiChatRemoteRepository.delete(cid, pk);
    } catch (_) {
      // Offline
    }
  }
}
