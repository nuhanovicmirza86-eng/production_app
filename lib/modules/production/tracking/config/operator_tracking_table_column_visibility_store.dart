import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'operator_tracking_column_labels.dart';

/// Lokalno na uređaju: koje kolone tablice praćenja prikazati (SharedPreferences).
class OperatorTrackingTableColumnVisibilityStore {
  OperatorTrackingTableColumnVisibilityStore._();

  static const String _prefKey = 'operator_tracking_table_columns_v1';

  /// Svi ključevi (za spremanje u prefs, uključujući pripremnu kolonu).
  static List<String> allKeysUnion() => [
    OperatorTrackingColumnKeys.rowIndex,
    OperatorTrackingColumnKeys.prepDateTime,
    OperatorTrackingColumnKeys.lineOrBatchRef,
    OperatorTrackingColumnKeys.releaseToolOrRodRef,
    OperatorTrackingColumnKeys.itemCode,
    OperatorTrackingColumnKeys.itemName,
    OperatorTrackingColumnKeys.customerName,
    OperatorTrackingColumnKeys.goodQty,
    OperatorTrackingColumnKeys.scrapTotal,
    OperatorTrackingColumnKeys.rawMaterialOrder,
    OperatorTrackingColumnKeys.rawWorkOperator,
    OperatorTrackingColumnKeys.preparedBy,
    OperatorTrackingColumnKeys.actions,
  ];

  /// Redoslijed kolona za trenutnu fazu (bez release ako nije pripremna).
  static List<String> keysInOrder({required bool preparationPhase}) {
    return [
      OperatorTrackingColumnKeys.rowIndex,
      OperatorTrackingColumnKeys.prepDateTime,
      OperatorTrackingColumnKeys.lineOrBatchRef,
      if (preparationPhase) OperatorTrackingColumnKeys.releaseToolOrRodRef,
      OperatorTrackingColumnKeys.itemCode,
      OperatorTrackingColumnKeys.itemName,
      OperatorTrackingColumnKeys.customerName,
      OperatorTrackingColumnKeys.goodQty,
      OperatorTrackingColumnKeys.scrapTotal,
      OperatorTrackingColumnKeys.rawMaterialOrder,
      OperatorTrackingColumnKeys.rawWorkOperator,
      OperatorTrackingColumnKeys.preparedBy,
      OperatorTrackingColumnKeys.actions,
    ];
  }

  /// Ove kolone ne smiju biti skrivene (šifra, naziv, količina dobra).
  static const Set<String> lockedKeys = {
    OperatorTrackingColumnKeys.itemCode,
    OperatorTrackingColumnKeys.itemName,
    OperatorTrackingColumnKeys.goodQty,
    OperatorTrackingColumnKeys.actions,
  };

  static Future<Map<String, bool>> load({required bool preparationPhase}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    final order = keysInOrder(preparationPhase: preparationPhase);
    final out = <String, bool>{for (final k in order) k: true};
    if (raw == null || raw.isEmpty) return out;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final k in order) {
        final v = m[k];
        if (v is bool) out[k] = v;
      }
    } catch (_) {}
    for (final k in lockedKeys) {
      if (out.containsKey(k)) out[k] = true;
    }
    return out;
  }

  static Future<void> save(Map<String, bool> visibility) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = <String, bool>{};
    for (final k in allKeysUnion()) {
      clean[k] = visibility[k] != false;
    }
    for (final k in lockedKeys) {
      clean[k] = true;
    }
    await prefs.setString(_prefKey, jsonEncode(clean));
  }
}
