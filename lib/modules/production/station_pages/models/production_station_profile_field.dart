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
    this.verifierEditable,
    this.scope,
    this.helperText,
    this.entitySearchCallable,
    this.minSearchChars = 2,
    this.labelFields = const [],
    this.enumLabels = const {},
    this.legacyEnumLabels = const {},
    this.scanEnabled = false,
    this.uiControl,
    this.visibleWhenField,
    this.visibleWhenEquals,
    this.visibleWhenAnyOfFields = const [],
    this.signedByLoggedInUser = false,
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
  /// M1-I15-D-HOTFIX-27 — verifikator unosi, operater ne vidi u zaglavlju.
  final bool? verifierEditable;
  final String? scope;
  final String? helperText;
  final String? entitySearchCallable;
  final int minSearchChars;
  final List<String> labelFields;
  final Map<String, String> enumLabels;
  final Map<String, String> legacyEnumLabels;
  final bool scanEnabled;
  /// Katalog `uiControl` (npr. chips umjesto dropdowna).
  final String? uiControl;
  /// Katalog `visibleWhen.field` (npr. workContextType).
  final String? visibleWhenField;
  /// Katalog `visibleWhen.equals`.
  final String? visibleWhenEquals;
  /// Katalog `visibleWhen.anyOfFields` (npr. 5S checklist Nije u redu).
  final List<String> visibleWhenAnyOfFields;
  /// M1-I15-D-HOTFIX-14 — potpis prijavljenog korisnika, nije picker tuđeg imena.
  final bool signedByLoggedInUser;

  bool get isEntitySelect => type == 'entity_select';

  bool get isEntitySearchSelect => type == 'entity_search_select';

  bool get isBackendPopulated => populatedBy == 'backend';

  bool get isSessionScope => scope == 'session';

  bool get isVerifierEditable => verifierEditable == true;

  bool get isOperatorEditable {
    if (isBackendPopulated) return false;
    if (isSessionScope) return false;
    if (isVerifierEditable) return false;
    if (operatorEditable == false) return false;
    return true;
  }

  bool get usesChipEnumControl =>
      (uiControl ?? '').trim().toLowerCase() == 'chips';

  bool get hasVisibleWhen {
    if (visibleWhenAnyOfFields.isNotEmpty) return true;
    final f = (visibleWhenField ?? '').trim();
    final e = (visibleWhenEquals ?? '').trim();
    return f.isNotEmpty && e.isNotEmpty;
  }

  String _resolvedValueForVisibilityKey(
    String key, {
    required Map<String, dynamic> fieldValues,
    required Map<String, String?> enumSelections,
  }) {
    final fromEnum = (enumSelections[key] ?? '').trim();
    if (fromEnum.isNotEmpty) return fromEnum;
    return (fieldValues[key] ?? '').toString().trim();
  }

  /// Je li polje vidljivo prema trenutnim header vrijednostima.
  bool isVisibleGiven({
    required Map<String, dynamic> fieldValues,
    required Map<String, String?> enumSelections,
  }) {
    if (!hasVisibleWhen) return true;
    final expected = (visibleWhenEquals ?? '').trim();
    if (visibleWhenAnyOfFields.isNotEmpty) {
      return visibleWhenAnyOfFields.any((key) {
        return _resolvedValueForVisibilityKey(
              key,
              fieldValues: fieldValues,
              enumSelections: enumSelections,
            ) ==
            expected;
      });
    }
    final key = visibleWhenField!.trim();
    return _resolvedValueForVisibilityKey(
          key,
          fieldValues: fieldValues,
          enumSelections: enumSelections,
        ) ==
        expected;
  }

  factory ProductionStationProfileField.fromMap(Map<String, dynamic> data) {
    String? visibleWhenField;
    String? visibleWhenEquals;
    var visibleWhenAnyOfFields = const <String>[];
    final visibleWhenRaw = data['visibleWhen'];
    if (visibleWhenRaw is Map) {
      final f = (visibleWhenRaw['field'] ?? '').toString().trim();
      final e = (visibleWhenRaw['equals'] ?? '').toString().trim();
      if (f.isNotEmpty && e.isNotEmpty) {
        visibleWhenField = f;
        visibleWhenEquals = e;
      } else if (e.isNotEmpty) {
        visibleWhenEquals = e;
      }
      visibleWhenAnyOfFields = _parseStringList(visibleWhenRaw['anyOfFields']);
    }
    final uiControl = (data['uiControl'] ?? '').toString().trim();
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
      verifierEditable: data['verifierEditable'] == true ? true : null,
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
      uiControl: uiControl.isEmpty ? null : uiControl,
      visibleWhenField: visibleWhenField,
      visibleWhenEquals: visibleWhenEquals,
      visibleWhenAnyOfFields: visibleWhenAnyOfFields,
      signedByLoggedInUser: data['signedByLoggedInUser'] == true,
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

  ProductionStationProfileField copyWith({
    String? label,
    String? helperText,
    int? minSearchChars,
    String? entitySearchCallable,
  }) {
    return ProductionStationProfileField(
      key: key,
      label: label ?? this.label,
      type: type,
      required: required,
      maxLength: maxLength,
      min: min,
      uiOrder: uiOrder,
      enumFrom: enumFrom,
      enumValues: enumValues,
      entityCollection: entityCollection,
      entityListCallable: entityListCallable,
      valueField: valueField,
      labelField: labelField,
      filterDependsOn: filterDependsOn,
      filterMode: filterMode,
      filterListCallable: filterListCallable,
      populatedBy: populatedBy,
      operatorEditable: operatorEditable,
      verifierEditable: verifierEditable,
      scope: scope,
      helperText: helperText ?? this.helperText,
      entitySearchCallable: entitySearchCallable ?? this.entitySearchCallable,
      minSearchChars: minSearchChars ?? this.minSearchChars,
      labelFields: labelFields,
      enumLabels: enumLabels,
      legacyEnumLabels: legacyEnumLabels,
      scanEnabled: scanEnabled,
      uiControl: uiControl,
      visibleWhenField: visibleWhenField,
      visibleWhenEquals: visibleWhenEquals,
      visibleWhenAnyOfFields: visibleWhenAnyOfFields,
      signedByLoggedInUser: signedByLoggedInUser,
    );
  }
}
