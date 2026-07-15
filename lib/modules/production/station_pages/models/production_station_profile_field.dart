/// Polje profila stanice iz repo kataloga (`fields[]`).
class ProductionStationProfileField {
  const ProductionStationProfileField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.maxLength,
    this.min,
    this.uiOrder = 0,
    this.enumFrom,
    this.enumValues = const [],
    this.entityCollection,
    this.entityListCallable,
    this.valueField = 'id',
    this.labelField = 'displayName',
    this.filterDependsOn,
    this.filterMode,
    this.filterListCallable,
    this.populatedBy,
    this.operatorEditable,
    this.scope,
    this.helperText,
    this.entitySearchCallable,
    this.minSearchChars = 2,
    this.labelFields = const [],
    this.enumLabels = const {},
    this.scanEnabled = false,
  });

  final String key;
  final String label;
  final String type;
  final bool required;
  final int? maxLength;
  final num? min;
  final int uiOrder;
  final String? enumFrom;
  final List<String> enumValues;
  final String? entityCollection;
  final String? entityListCallable;
  final String valueField;
  final String labelField;
  final String? filterDependsOn;
  final String? filterMode;
  final String? filterListCallable;
  final String? populatedBy;
  final bool? operatorEditable;
  final String? scope;
  final String? helperText;
  final String? entitySearchCallable;
  final int minSearchChars;
  final List<String> labelFields;
  final Map<String, String> enumLabels;
  final bool scanEnabled;

  bool get isEntitySelect => type == 'entity_select';

  bool get isEntitySearchSelect => type == 'entity_search_select';

  bool get isBackendPopulated => populatedBy == 'backend';

  bool get isSessionScope => scope == 'session';

  bool get isOperatorEditable {
    if (isBackendPopulated) return false;
    if (operatorEditable == false) return false;
    if (isSessionScope) return false;
    return true;
  }

  factory ProductionStationProfileField.fromMap(Map<String, dynamic> data) {
    return ProductionStationProfileField(
      key: (data['key'] ?? '').toString().trim(),
      label: (data['label'] ?? '').toString().trim(),
      type: (data['type'] ?? 'string').toString().trim().toLowerCase(),
      required: data['required'] == true,
      maxLength: (data['maxLength'] as num?)?.toInt(),
      min: data['min'] as num?,
      uiOrder: (data['uiOrder'] as num?)?.toInt() ?? 0,
      enumFrom: (data['enumFrom'] ?? '').toString().trim().isEmpty
          ? null
          : (data['enumFrom'] ?? '').toString().trim(),
      enumValues: _parseEnumValues(data['enumValues']),
      entityCollection: (data['entityCollection'] ?? '').toString().trim().isEmpty
          ? null
          : (data['entityCollection'] ?? '').toString().trim(),
      entityListCallable: (data['entityListCallable'] ?? '')
          .toString()
          .trim()
          .isEmpty
          ? null
          : (data['entityListCallable'] ?? '').toString().trim(),
      valueField: (data['valueField'] ?? 'id').toString().trim().isEmpty
          ? 'id'
          : (data['valueField'] ?? 'id').toString().trim(),
      labelField: (data['labelField'] ?? 'displayName').toString().trim().isEmpty
          ? 'displayName'
          : (data['labelField'] ?? 'displayName').toString().trim(),
      filterDependsOn: (data['filterDependsOn'] ?? '')
          .toString()
          .trim()
          .isEmpty
          ? null
          : (data['filterDependsOn'] ?? '').toString().trim(),
      filterMode: (data['filterMode'] ?? '').toString().trim().isEmpty
          ? null
          : (data['filterMode'] ?? '').toString().trim(),
      filterListCallable: (data['filterListCallable'] ?? '')
          .toString()
          .trim()
          .isEmpty
          ? null
          : (data['filterListCallable'] ?? '').toString().trim(),
      populatedBy: (data['populatedBy'] ?? '').toString().trim().isEmpty
          ? null
          : (data['populatedBy'] ?? '').toString().trim(),
      operatorEditable: data['operatorEditable'] is bool
          ? data['operatorEditable'] as bool
          : null,
      scope: (data['scope'] ?? '').toString().trim().isEmpty
          ? null
          : (data['scope'] ?? '').toString().trim(),
      helperText: (data['helperText'] ?? '').toString().trim().isEmpty
          ? null
          : (data['helperText'] ?? '').toString().trim(),
      entitySearchCallable: (data['entitySearchCallable'] ?? '')
          .toString()
          .trim()
          .isEmpty
          ? null
          : (data['entitySearchCallable'] ?? '').toString().trim(),
      minSearchChars: (data['minSearchChars'] as num?)?.toInt() ?? 2,
      labelFields: _parseStringList(data['labelFields']),
      enumLabels: _parseEnumLabels(data['enumLabels']),
      scanEnabled: data['scanEnabled'] == true,
    );
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((v) => v.toString().trim())
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, String> _parseEnumLabels(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final k = key.toString().trim();
      final v = value.toString().trim();
      if (k.isNotEmpty && v.isNotEmpty) out[k] = v;
    });
    return out;
  }

  String enumLabelFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return enumLabels[trimmed] ?? trimmed;
  }

  static List<String> _parseEnumValues(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((v) => v.toString().trim())
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
  }

  static List<ProductionStationProfileField> sortedList(
    Iterable<ProductionStationProfileField> fields,
  ) {
    final list = fields.toList(growable: false);
    list.sort((a, b) {
      if (a.uiOrder != b.uiOrder) return a.uiOrder.compareTo(b.uiOrder);
      return a.label.compareTo(b.label);
    });
    return list;
  }
}
