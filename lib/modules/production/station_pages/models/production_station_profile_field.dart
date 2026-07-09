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
  });

  final String key;
  final String label;
  final String type;
  final bool required;
  final int? maxLength;
  final num? min;
  final int uiOrder;
  final String? enumFrom;
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

  bool get isEntitySelect => type == 'entity_select';

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
    );
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
