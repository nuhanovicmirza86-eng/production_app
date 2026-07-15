import '../../../modules/production/station_pages/models/production_station_profile_field.dart';

/// Kanonski UI za dijalog reda tabele `operator_work_logs` (M1-D3).
/// Ne ovisi o uiOrder / starijoj verziji kataloga s Callabla.
class OperatorWorkLogRowLayout {
  OperatorWorkLogRowLayout._();

  static const tableKey = 'operator_work_logs';

  static const dialogFieldOrder = <String>[
    'operatorId',
    'startedAt',
    'okQty',
    'scrapQty',
    'reworkAgainQty',
    'finishedAt',
    'note',
  ];

  static const backendOnlyFieldKeys = <String>{
    'processedQty',
    'durationMinutes',
    'piecesPerHour',
    'minutesPerPiece',
    'operatorDisplayNameSnapshot',
  };

  /// UI ključ za DA/NE izbor (mapira se na `reworkAgainQty` pri spremanju).
  static const reworkYesNoUiKey = 'reworkAgainYesNo';

  static const reworkYesNoValues = <String>['NE', 'DA'];

  static bool isReworkYesNoField(String fieldKey) => fieldKey == 'reworkAgainQty';

  static String yesNoFromStoredQty(dynamic raw) {
    final qty = _parseQty(raw);
    return qty > 0 ? 'DA' : 'NE';
  }

  static double qtyFromYesNo(String? yesNo) => yesNo == 'DA' ? 1 : 0;

  static double _parseQty(dynamic raw) {
    if (raw is num) return raw < 0 ? 0 : raw.toDouble();
    final n = double.tryParse(raw?.toString().replaceAll(',', '.') ?? '');
    if (n == null || n.isNaN) return 0;
    return n < 0 ? 0 : n;
  }

  static bool isOperatorWorkLogTable(String tableKey) =>
      tableKey.trim() == OperatorWorkLogRowLayout.tableKey;

  static List<ProductionStationProfileField> dialogColumns(
    Iterable<ProductionStationProfileField> catalogColumns,
  ) {
    final byKey = <String, ProductionStationProfileField>{
      for (final col in catalogColumns) col.key: col,
    };
    final out = <ProductionStationProfileField>[];
    for (final key in dialogFieldOrder) {
      final col = byKey[key];
      if (col != null) {
        out.add(_withCanonicalPresentation(col));
      }
    }
    return out;
  }

  static String displayLabel(ProductionStationProfileField col) {
    return switch (col.key) {
      'operatorId' => 'Operater',
      'startedAt' => 'Početak rada',
      'okQty' => 'Broj OK komada',
      'scrapQty' => 'Broj neispravnih komada',
      'reworkAgainQty' => 'Ponovna dorada',
      'finishedAt' => 'Kraj rada',
      'note' => 'Napomena',
      _ => col.label,
    };
  }

  static bool isRequired(ProductionStationProfileField col) {
    return switch (col.key) {
      'operatorId' => true,
      'startedAt' => true,
      'okQty' => true,
      'finishedAt' => true,
      _ => col.required,
    };
  }

  static ProductionStationProfileField _withCanonicalPresentation(
    ProductionStationProfileField col,
  ) {
    return ProductionStationProfileField(
      key: col.key,
      label: displayLabel(col),
      type: col.type,
      required: isRequired(col),
      maxLength: col.maxLength,
      min: col.min,
      uiOrder: col.uiOrder,
      enumFrom: col.enumFrom,
      enumValues: col.enumValues,
      entityCollection: col.entityCollection,
      entityListCallable: col.entityListCallable,
      valueField: col.valueField,
      labelField: col.labelField,
      filterDependsOn: col.filterDependsOn,
      filterMode: col.filterMode,
      filterListCallable: col.filterListCallable,
      populatedBy: col.populatedBy,
      operatorEditable: col.operatorEditable,
      scope: col.scope,
      helperText: col.helperText,
      entitySearchCallable: col.entitySearchCallable,
      minSearchChars: col.minSearchChars,
      labelFields: col.labelFields,
      enumLabels: col.enumLabels,
      scanEnabled: col.scanEnabled,
    );
  }
}
