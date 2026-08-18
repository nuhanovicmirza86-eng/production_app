import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';

/// Zadnji korišteni proizvodni operateri (M1-I4-C4) — lokalno po kompaniji.
abstract final class RecentProductionOperatorsStore {
  static const _maxItems = 5;

  static String _key(String companyId) =>
      'catalog_evidence_recent_prod_ops_${companyId.trim()}';

  static Future<List<StructuredEntitySearchResult>> load(String companyId) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cid));
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <StructuredEntitySearchResult>[];
      for (final item in list) {
        if (item is! Map) continue;
        final id = (item['id'] ?? '').toString().trim();
        final label = (item['label'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        out.add(
          StructuredEntitySearchResult(
            id: id,
            displayLabel: label.isEmpty ? id : label,
            raw: Map<String, dynamic>.from(item),
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> remember({
    required String companyId,
    required String entityId,
    required String displayLabel,
  }) async {
    final cid = companyId.trim();
    final id = entityId.trim();
    if (cid.isEmpty || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await load(cid);
    final next = <StructuredEntitySearchResult>[
      StructuredEntitySearchResult(
        id: id,
        displayLabel: displayLabel.trim().isEmpty ? id : displayLabel.trim(),
        raw: {'id': id, 'label': displayLabel.trim()},
      ),
      ...existing.where((e) => e.id != id),
    ].take(_maxItems).toList(growable: false);
    await prefs.setString(
      _key(cid),
      jsonEncode(
        next
            .map(
              (e) => {
                'id': e.id,
                'label': e.displayLabel,
              },
            )
            .toList(growable: false),
      ),
    );
  }
}
