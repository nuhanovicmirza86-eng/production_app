import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import 'structured_repeatable_row.dart';

/// Ponašanje sesije iz kataloga (`sessionBehavior`).
class StructuredProfileSessionBehavior {
  const StructuredProfileSessionBehavior({
    required this.inputModel,
    this.headerScope,
    this.lineStorage,
    this.subcollections = const [],
    this.scanCallable,
  });

  final String inputModel;
  final String? headerScope;
  final String? lineStorage;
  final List<String> subcollections;
  final String? scanCallable;

  bool get isStructured => inputModel.trim() == 'structured';

  bool get isStructuredLite => inputModel.trim() == 'structured_lite';

  factory StructuredProfileSessionBehavior.fromMap(Map<String, dynamic>? raw) {
    final data = raw ?? const <String, dynamic>{};
    final subs = <String>[];
    final subsRaw = data['subcollections'];
    if (subsRaw is List) {
      for (final item in subsRaw) {
        final s = item.toString().trim();
        if (s.isNotEmpty) subs.add(s);
      }
    }
    return StructuredProfileSessionBehavior(
      inputModel: (data['inputModel'] ?? '').toString().trim(),
      headerScope: (data['headerScope'] ?? '').toString().trim().isEmpty
          ? null
          : (data['headerScope'] ?? '').toString().trim(),
      lineStorage: (data['lineStorage'] ?? '').toString().trim().isEmpty
          ? null
          : (data['lineStorage'] ?? '').toString().trim(),
      subcollections: subs,
      scanCallable: (data['scanCallable'] ?? '').toString().trim().isEmpty
          ? null
          : (data['scanCallable'] ?? '').toString().trim(),
    );
  }
}

/// Definicija repeatable tabele iz kataloga.
class StructuredRepeatableTableDefinition {
  const StructuredRepeatableTableDefinition({
    required this.key,
    required this.label,
    required this.subcollection,
    required this.minRows,
    required this.uiOrder,
    required this.columns,
  });

  final String key;
  final String label;
  final String subcollection;
  final int minRows;
  final int uiOrder;
  final List<ProductionStationProfileField> columns;

  List<ProductionStationProfileField> get operatorColumns =>
      columns.where((c) => c.isOperatorEditable).toList(growable: false);

  factory StructuredRepeatableTableDefinition.fromMap(
    Map<String, dynamic> data,
  ) {
    final columnsRaw = data['columns'];
    final columns = <ProductionStationProfileField>[];
    if (columnsRaw is List) {
      for (final item in columnsRaw) {
        if (item is Map) {
          columns.add(
            ProductionStationProfileField.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    return StructuredRepeatableTableDefinition(
      key: (data['key'] ?? '').toString().trim(),
      label: (data['label'] ?? '').toString().trim(),
      subcollection: (data['subcollection'] ?? '').toString().trim(),
      minRows: (data['minRows'] as num?)?.toInt() ?? 0,
      uiOrder: (data['uiOrder'] as num?)?.toInt() ?? 0,
      columns: ProductionStationProfileField.sortedList(columns),
    );
  }
}

/// Payload ključevi za Callable update/finish (camelCase).
class StructuredProfileTablePayloadKeys {
  static const processedItems = 'processedItems';
  static const materialConsumptions = 'materialConsumptions';
  static const operatorWorkLogs = 'operatorWorkLogs';
  static const scrapItems = 'scrapItems';
  static const controlledItems = 'controlledItems';

  static const subcollectionToPayloadKey = {
    'processed_items': processedItems,
    'material_consumptions': materialConsumptions,
    'operator_work_logs': operatorWorkLogs,
    'scrap_items': scrapItems,
    'controlled_items': controlledItems,
  };

  static String? payloadKeyForTable(String tableKey) =>
      subcollectionToPayloadKey[tableKey.trim()];
}

/// Lokalno stanje structured sesije (header + 4 tabele).
class StructuredProfileSessionState {
  StructuredProfileSessionState({
    Map<String, dynamic>? fieldValues,
    Map<String, List<StructuredRepeatableRow>>? tablesByKey,
  })  : fieldValues = Map<String, dynamic>.from(fieldValues ?? const {}),
        tablesByKey = tablesByKey ?? const {};

  Map<String, dynamic> fieldValues;
  Map<String, List<StructuredRepeatableRow>> tablesByKey;

  List<StructuredRepeatableRow> rowsFor(String tableKey) =>
      List<StructuredRepeatableRow>.from(tablesByKey[tableKey] ?? const []);

  void setRows(String tableKey, List<StructuredRepeatableRow> rows) {
    tablesByKey = {...tablesByKey, tableKey: rows};
  }

  Map<String, dynamic> buildUpdatePayload({Iterable<String>? tableKeys}) {
    final payload = <String, dynamic>{
      'fieldValues': Map<String, dynamic>.from(fieldValues),
    };
    final keys = tableKeys ??
        StructuredProfileTablePayloadKeys.subcollectionToPayloadKey.keys;
    for (final tableKey in keys) {
      final payloadKey =
          StructuredProfileTablePayloadKeys.payloadKeyForTable(tableKey);
      if (payloadKey == null) continue;
      payload[payloadKey] = rowsFor(tableKey)
          .map((row) => row.toPayload())
          .toList(growable: false);
    }
    return payload;
  }
}

extension StructuredProfileCatalogEntryX on ProductionStationProfileCatalogEntry {
  StructuredProfileSessionBehavior? get sessionBehaviorModel {
    if (sessionBehavior.isEmpty) return null;
    return StructuredProfileSessionBehavior.fromMap(sessionBehavior);
  }

  bool get isStructuredInputModel =>
      sessionBehaviorModel?.isStructured ?? false;

  bool get isStructuredLiteInputModel =>
      sessionBehaviorModel?.isStructuredLite ?? false;

  List<StructuredRepeatableTableDefinition> get repeatableTableDefinitions {
    final out = <StructuredRepeatableTableDefinition>[];
    for (final raw in repeatableTables) {
      out.add(StructuredRepeatableTableDefinition.fromMap(raw));
    }
    out.sort((a, b) {
      if (a.uiOrder != b.uiOrder) return a.uiOrder.compareTo(b.uiOrder);
      return a.label.compareTo(b.label);
    });
    return out;
  }

  List<ProductionStationProfileField> get structuredHeaderFields =>
      fields.where((f) => f.isOperatorEditable).toList(growable: false);
}
