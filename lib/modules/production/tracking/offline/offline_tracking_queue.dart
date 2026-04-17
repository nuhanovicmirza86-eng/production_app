import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Lokalni red za unose praćenja kad mreža nije dostupna (mobilni / desktop).
/// Na webu se ne koristi (nema pouzdanog lokalnog zapisa).
class OfflineTrackingQueue {
  OfflineTrackingQueue._();

  static const _fileName = 'offline_operator_tracking_queue.json';

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$_fileName');
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> loadAll() async {
    final f = await _file();
    if (f == null || !await f.exists()) return [];
    try {
      final raw = await f.readAsString();
      if (raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<int> count() async {
    final all = await loadAll();
    return all.length;
  }

  static Future<void> enqueue(Map<String, dynamic> payload) async {
    final f = await _file();
    if (f == null) {
      throw StateError('Offline red nije dostupan na ovoj platformi.');
    }
    final all = await loadAll();
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    all.add({
      ...payload,
      'localQueueId': id,
      'queuedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await f.writeAsString(jsonEncode(all));
  }

  static Future<void> removeByLocalQueueId(String id) async {
    final f = await _file();
    if (f == null) return;
    final all = await loadAll();
    all.removeWhere((e) => (e['localQueueId'] ?? '').toString() == id);
    await f.writeAsString(jsonEncode(all));
  }

  static Future<void> clear() async {
    final f = await _file();
    if (f == null || !await f.exists()) return;
    await f.writeAsString('[]');
  }
}
