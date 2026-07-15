import 'dart:math';

import 'structured_entity_search_result.dart';

/// Jedan red repeatable tabele u UI-u.
class StructuredRepeatableRow {
  StructuredRepeatableRow({
    required this.clientRowId,
    Map<String, dynamic>? values,
    Map<String, StructuredEntitySelection>? entitySelections,
  })  : values = Map<String, dynamic>.from(values ?? const {}),
        entitySelections =
            Map<String, StructuredEntitySelection>.from(entitySelections ?? const {});

  final String clientRowId;
  final Map<String, dynamic> values;
  final Map<String, StructuredEntitySelection> entitySelections;

  factory StructuredRepeatableRow.empty() {
    return StructuredRepeatableRow(
      clientRowId: _newClientRowId(),
      values: const {},
      entitySelections: const {},
    );
  }

  factory StructuredRepeatableRow.fromPayload(
    Map<String, dynamic> raw, {
    String? clientRowId,
  }) {
    final values = Map<String, dynamic>.from(raw);
    final persistedId = (values.remove('id') ?? '').toString().trim();
    values.remove('companyId');
    values.remove('createdAt');
    values.remove('createdByUid');
    values.remove('lineIndex');

    final entitySelections = <String, StructuredEntitySelection>{};
    for (final key in [
      'productId',
      'materialId',
      'operatorId',
      'productionOrderId',
    ]) {
      final entityId = (values[key] ?? '').toString().trim();
      if (entityId.isEmpty) continue;
      final snapshotLabel = _snapshotLabelFor(values, key);
      entitySelections[key] = StructuredEntitySelection(
        fieldKey: key,
        entityId: entityId,
        displayLabel: snapshotLabel ?? entityId,
      );
    }

    return StructuredRepeatableRow(
      clientRowId: clientRowId ?? persistedId.ifEmpty(_newClientRowId()),
      values: values,
      entitySelections: entitySelections,
    );
  }

  static String? _snapshotLabelFor(Map<String, dynamic> values, String key) {
    switch (key) {
      case 'productId':
        final code = (values['productCodeSnapshot'] ?? '').toString().trim();
        final name = (values['productNameSnapshot'] ?? '').toString().trim();
        if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
        return code.isNotEmpty ? code : (name.isEmpty ? null : name);
      case 'materialId':
        final code = (values['materialCodeSnapshot'] ?? '').toString().trim();
        final name = (values['materialNameSnapshot'] ?? '').toString().trim();
        if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
        return code.isNotEmpty ? code : (name.isEmpty ? null : name);
      case 'operatorId':
        final name =
            (values['operatorDisplayNameSnapshot'] ?? '').toString().trim();
        return name.isEmpty ? null : name;
      default:
        return null;
    }
  }

  Map<String, dynamic> toPayload() {
    const backendOnlyKeys = {
      'processedQty',
      'durationMinutes',
      'piecesPerHour',
      'minutesPerPiece',
      'productCodeSnapshot',
      'productNameSnapshot',
      'materialCodeSnapshot',
      'materialNameSnapshot',
      'materialTypeSnapshot',
      'operatorDisplayNameSnapshot',
    };
    final out = Map<String, dynamic>.from(values);
    for (final key in backendOnlyKeys) {
      out.remove(key);
    }
    for (final entry in entitySelections.entries) {
      out[entry.key] = entry.value.entityId;
    }
    return out;
  }

  StructuredRepeatableRow copyWith({
    Map<String, dynamic>? values,
    Map<String, StructuredEntitySelection>? entitySelections,
  }) {
    return StructuredRepeatableRow(
      clientRowId: clientRowId,
      values: values ?? Map<String, dynamic>.from(this.values),
      entitySelections: entitySelections ??
          Map<String, StructuredEntitySelection>.from(this.entitySelections),
    );
  }

  void setValue(String key, dynamic value) {
    values[key] = value;
  }

  void setEntitySelection(StructuredEntitySelection? selection) {
    if (selection == null) return;
    entitySelections[selection.fieldKey] = selection;
    values[selection.fieldKey] = selection.entityId;
  }

  String displaySummary(List<String> columnKeys) {
    final parts = <String>[];
    for (final key in columnKeys) {
      final selection = entitySelections[key];
      if (selection != null) {
        parts.add(selection.displayLabel);
        continue;
      }
      final raw = values[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) parts.add(text);
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

extension _StringEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

String _newClientRowId() {
  final rand = Random();
  return 'row_${DateTime.now().microsecondsSinceEpoch}_${rand.nextInt(9999)}';
}
