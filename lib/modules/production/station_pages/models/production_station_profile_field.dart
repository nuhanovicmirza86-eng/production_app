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
    this.legacyEnumLabels = const {},
    this.scanEnabled = false,
    this.visibleWhenField,
    this.visibleWhenEquals,
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
  final Map<String, String> legacyEnumLabels;
  final bool scanEnabled;
  /// Katalog `visibleWhen.field` (npr. workContextType).
  final String? visibleWhenField;
  /// Katalog `visibleWhen.equals`.
  final String? visibleWhenEquals;

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

  bool get hasVisibleWhen {
    final f = (visibleWhenField ?? '').trim();
    final e = (visibleWhenEquals ?? '').trim();
    return f.isNotEmpty && e.isNotEmpty;
  }

  /// Je li polje vidljivo prema trenutnim header vrijednostima.
  bool isVisibleGiven({
    required Map<String, dynamic> fieldValues,
    required Map<String, String?> enumSelections,
  }) {
    if (!hasVisibleWhen) return true;
    final key = visibleWhenField!.trim();
    final expected = visibleWhenEquals!.trim();
    final fromEnum = (enumSelections[key] ?? '').trim();
    if (fromEnum.isNotEmpty) return fromEnum == expected;
    final fromState = (fieldValues[key] ?? '').toString().trim();
    return fromState == expected;
  }

  factory ProductionStationProfileField.fromMap(Map<String, dynamic> data) {
    String? visibleWhenField;
    String? visibleWhenEquals;
    final visibleWhenRaw = data['visibleWhen'];
    if (visibleWhenRaw is Map) {
      final f = (visibleWhenRaw['field'] ?? '').toString().trim();
      final e = (visibleWhenRaw['equals'] ?? '').toString().trim();
      if (f.isNotEmpty && e.isNotEmpty) {
        visibleWhenField = f;
        visibleWhenEquals = e;
      }
    }
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
      legacyEnumLabels: _parseEnumLabels(data['legacyEnumLabels']),
      scanEnabled: data['scanEnabled'] == true,
      visibleWhenField: visibleWhenField,
      visibleWhenEquals: visibleWhenEquals,
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
    return enumLabels[trimmed] ??
        legacyEnumLabels[trimmed] ??
        trimmed;
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
