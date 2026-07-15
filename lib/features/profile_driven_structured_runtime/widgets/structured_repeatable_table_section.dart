import 'package:flutter/material.dart';

import '../../../core/format/ba_formatted_date.dart';
import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../models/structured_entity_search_result.dart';
import '../models/structured_profile_session.dart';
import '../models/structured_repeatable_row.dart';
import '../services/production_evidence_entity_search_service.dart';
import '../utils/structured_datetime_value.dart';
import 'operator_work_log_row_layout.dart';
import 'structured_datetime_field.dart';
import 'structured_entity_search_field.dart';

class StructuredRepeatableTableSection extends StatelessWidget {
  const StructuredRepeatableTableSection({
    super.key,
    required this.tableDef,
    required this.profile,
    required this.companyId,
    required this.plantKey,
    required this.rows,
    required this.searchService,
    required this.onRowsChanged,
    this.enabled = true,
  });

  final StructuredRepeatableTableDefinition tableDef;
  final ProductionStationProfileCatalogEntry profile;
  final String companyId;
  final String plantKey;
  final List<StructuredRepeatableRow> rows;
  final ProductionEvidenceEntitySearchCallableService searchService;
  final ValueChanged<List<StructuredRepeatableRow>> onRowsChanged;
  final bool enabled;

  List<ProductionStationProfileField> get _rowDialogColumns {
    if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)) {
      return OperatorWorkLogRowLayout.dialogColumns(tableDef.columns);
    }
    return tableDef.operatorColumns;
  }

  List<String> get _summaryColumnKeys {
    final columns = _rowDialogColumns;
    final keys = <String>[];
    for (final col in columns) {
      if (col.isEntitySearchSelect || col.type == 'enum' || col.type == 'number') {
        keys.add(col.key);
      }
      if (keys.length >= 4) break;
    }
    return keys;
  }

  Future<void> _openRowEditor({
    required BuildContext context,
    StructuredRepeatableRow? existing,
    required int? index,
  }) async {
    final draft = existing?.copyWith() ?? StructuredRepeatableRow.empty();
    final enumSelections = <String, String?>{};
    final dateTimes = <String, DateTime?>{};
    final entitySelections =
        Map<String, StructuredEntitySelection?>.from(draft.entitySelections);
    final textControllers = <String, TextEditingController>{};

    for (final col in _rowDialogColumns) {
      final raw = draft.values[col.key];
      if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key) &&
          OperatorWorkLogRowLayout.isReworkYesNoField(col.key)) {
        enumSelections[OperatorWorkLogRowLayout.reworkYesNoUiKey] =
            OperatorWorkLogRowLayout.yesNoFromStoredQty(raw);
        continue;
      }
      if (col.type == 'enum') {
        enumSelections[col.key] = raw?.toString();
      } else if (col.type == 'datetime') {
        dateTimes[col.key] = StructuredDateTimeValue.parse(raw);
      } else if (col.type == 'number' || _isTextLike(col.type)) {
        textControllers[col.key] = TextEditingController(
          text: raw == null ? '' : raw.toString(),
        );
      }
    }

    if (existing == null &&
        OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)) {
      dateTimes['startedAt'] ??= DateTime.now();
    }

    final scrollController = ScrollController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            String? validationError;

            String fieldLabel(ProductionStationProfileField col) {
              if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)) {
                return OperatorWorkLogRowLayout.displayLabel(col);
              }
              return col.label;
            }

            bool validate() {
              for (final col in _rowDialogColumns) {
                final required = OperatorWorkLogRowLayout.isOperatorWorkLogTable(
                      tableDef.key,
                    )
                    ? OperatorWorkLogRowLayout.isRequired(col)
                    : col.required;
                if (!required) continue;
                final label = fieldLabel(col);
                if (col.isEntitySearchSelect) {
                  final sel = entitySelections[col.key];
                  if (sel == null || sel.entityId.isEmpty) {
                    validationError = structuredRequiredFieldMessage(label);
                    return false;
                  }
                  continue;
                }
                if (col.type == 'enum') {
                  final v = enumSelections[col.key];
                  if (v == null || v.isEmpty) {
                    validationError = structuredRequiredFieldMessage(label);
                    return false;
                  }
                  continue;
                }
                if (col.type == 'datetime') {
                  if (dateTimes[col.key] == null) {
                    validationError = structuredRequiredFieldMessage(label);
                    return false;
                  }
                  continue;
                }
                if (col.type == 'number') {
                  if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(
                        tableDef.key,
                      ) &&
                      OperatorWorkLogRowLayout.isReworkYesNoField(col.key)) {
                    continue;
                  }
                  final text = textControllers[col.key]?.text.trim() ?? '';
                  final n = double.tryParse(text.replaceAll(',', '.'));
                  if (n == null) {
                    validationError = structuredRequiredFieldMessage(label);
                    return false;
                  }
                  if (col.min != null && n < col.min!) {
                    validationError =
                        'Polje «$label» mora biti ≥ ${col.min}.';
                    return false;
                  }
                  continue;
                }
                final text = textControllers[col.key]?.text.trim() ?? '';
                if (text.isEmpty) {
                  validationError = structuredRequiredFieldMessage(label);
                  return false;
                }
              }
              if (tableDef.key == 'operator_work_logs' &&
                  _computedOperatorProcessedQty(
                        textControllers,
                        enumSelections: enumSelections,
                      ) <=
                      0) {
                validationError =
                    'Unesite broj OK i/ili neispravnih komada — ukupno se računa automatski.';
                return false;
              }
              if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)) {
                final start = dateTimes['startedAt'];
                final end = dateTimes['finishedAt'];
                if (start != null &&
                    end != null &&
                    !StructuredDateTimeValue.isEndAfterStart(start, end)) {
                  validationError =
                      '«Kraj rada» mora biti nakon «Početak rada» '
                      '(${BaFormattedDate.formatDateTime(start)} → '
                      '${BaFormattedDate.formatDateTime(end)}).';
                  return false;
                }
              }
              validationError = null;
              return true;
            }

            void showValidationFailure() {
              setLocal(() {});
              if (scrollController.hasClients) {
                scrollController.jumpTo(0);
              }
            }

            double computedTotal = 0;
            if (tableDef.key == 'operator_work_logs') {
              computedTotal = _computedOperatorProcessedQty(
                textControllers,
                enumSelections: enumSelections,
              );
            }

            void applyDraftValues() {
              if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)) {
                final yesNo =
                    enumSelections[OperatorWorkLogRowLayout.reworkYesNoUiKey] ??
                        'NE';
                draft.setValue(
                  'reworkAgainQty',
                  OperatorWorkLogRowLayout.qtyFromYesNo(yesNo),
                );
              }
              for (final col in _rowDialogColumns) {
                if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(
                      tableDef.key,
                    ) &&
                    OperatorWorkLogRowLayout.isReworkYesNoField(col.key)) {
                  continue;
                }
                if (col.isEntitySearchSelect) {
                  final sel = entitySelections[col.key];
                  if (sel != null) {
                    draft.setEntitySelection(sel);
                  } else {
                    draft.values.remove(col.key);
                  }
                  continue;
                }
                if (col.type == 'enum') {
                  final v = enumSelections[col.key];
                  if (v == null || v.isEmpty) {
                    draft.values.remove(col.key);
                  } else {
                    draft.setValue(col.key, v);
                  }
                  continue;
                }
                if (col.type == 'datetime') {
                  final dt = dateTimes[col.key];
                  if (dt == null) {
                    draft.values.remove(col.key);
                  } else {
                    draft.setValue(
                      col.key,
                      structuredDateTimePayload(dt),
                    );
                  }
                  continue;
                }
                if (col.type == 'number') {
                  if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(
                        tableDef.key,
                      ) &&
                      OperatorWorkLogRowLayout.isReworkYesNoField(col.key)) {
                    continue;
                  }
                  final text = textControllers[col.key]?.text.trim() ?? '';
                  final n = double.tryParse(text.replaceAll(',', '.'));
                  if (n == null) {
                    draft.values.remove(col.key);
                  } else {
                    draft.setValue(col.key, n);
                  }
                  continue;
                }
                if (_isTextLike(col.type)) {
                  final text = textControllers[col.key]?.text.trim() ?? '';
                  if (text.isEmpty) {
                    draft.values.remove(col.key);
                  } else {
                    draft.setValue(col.key, text);
                  }
                }
              }
              if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)) {
                for (final key in OperatorWorkLogRowLayout.backendOnlyFieldKeys) {
                  draft.values.remove(key);
                }
              }
            }

            return AlertDialog(
              title: Text(
                existing == null ? 'Dodaj red — ${tableDef.label}' : 'Uredi red',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (validationError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      validationError!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ..._rowDialogColumns.expand((col) {
                        final widgets = <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildColumnField(
                              context: context,
                              col: col,
                              draft: draft,
                              entitySelections: entitySelections,
                              enumSelections: enumSelections,
                              dateTimes: dateTimes,
                              textControllers: textControllers,
                              onChanged: () => setLocal(() {}),
                            ),
                          ),
                        ];
                        if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(
                              tableDef.key,
                            ) &&
                            col.key == 'reworkAgainQty') {
                          widgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                child: Text(
                                  'Ukupno obrađeno (automatski): '
                                  '${computedTotal > 0 ? _formatQty(computedTotal) : '—'}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ),
                          );
                        }
                        return widgets;
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!validate()) {
                      showValidationFailure();
                      return;
                    }
                    applyDraftValues();
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Spremi red'),
                ),
              ],
            );
          },
        );
      },
    );

    scrollController.dispose();

    for (final c in textControllers.values) {
      c.dispose();
    }
    if (saved != true) return;

    final next = List<StructuredRepeatableRow>.from(rows);
    if (index == null) {
      next.add(draft);
    } else {
      next[index] = draft;
    }
    onRowsChanged(next);
  }

  Widget _buildColumnField({
    required BuildContext context,
    required ProductionStationProfileField col,
    required StructuredRepeatableRow draft,
    required Map<String, StructuredEntitySelection?> entitySelections,
    required Map<String, String?> enumSelections,
    required Map<String, DateTime?> dateTimes,
    required Map<String, TextEditingController> textControllers,
    required VoidCallback onChanged,
  }) {
    final label = OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)
        ? OperatorWorkLogRowLayout.displayLabel(col)
        : col.label;
    final required = OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key)
        ? OperatorWorkLogRowLayout.isRequired(col)
        : col.required;

    if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(tableDef.key) &&
        OperatorWorkLogRowLayout.isReworkYesNoField(col.key)) {
      final selected =
          enumSelections[OperatorWorkLogRowLayout.reworkYesNoUiKey] ?? 'NE';
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: 'DA = ima ponovne dorade, NE = nema.',
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selected,
            items: OperatorWorkLogRowLayout.reworkYesNoValues
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled
                ? (value) {
                    enumSelections[OperatorWorkLogRowLayout.reworkYesNoUiKey] =
                        value ?? 'NE';
                    onChanged();
                  }
                : null,
          ),
        ),
      );
    }

    if (col.isEntitySearchSelect) {
      return StructuredEntitySearchField(
        field: col,
        companyId: companyId,
        plantKey: plantKey,
        enabled: enabled,
        initialSelection: entitySelections[col.key],
        labelOverride: label,
        requiredOverride: required,
        searchFn: (query) => searchService.searchByCallable(
          callableName: col.entitySearchCallable ?? 'searchProducts',
          companyId: companyId,
          query: query,
          assignedPlantKey: col.entitySearchCallable == 'searchPlantOperators'
              ? plantKey
              : null,
        ),
        onChanged: (selection) {
          entitySelections[col.key] = selection;
          if (selection != null) {
            draft.setEntitySelection(selection);
          } else {
            draft.values.remove(col.key);
            draft.entitySelections.remove(col.key);
          }
          onChanged();
        },
      );
    }
    if (col.type == 'enum') {
      final options = col.enumValues.isNotEmpty
          ? col.enumValues
          : (col.enumFrom == 'units.allowedUnits' ? profile.allowedUnits : const []);
      return InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: enumSelections[col.key],
            hint: const Text('Odaberite…'),
            items: options
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(col.enumLabelFor(value)),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled
                ? (value) {
                    enumSelections[col.key] = value;
                    onChanged();
                  }
                : null,
          ),
        ),
      );
    }
    if (col.type == 'datetime') {
      return StructuredDateTimeField(
        label: label,
        required: required,
        enabled: enabled,
        value: dateTimes[col.key],
        onChanged: (dt) {
          dateTimes[col.key] = dt;
          onChanged();
        },
      );
    }
    final controller = textControllers.putIfAbsent(
      col.key,
      () => TextEditingController(
        text: draft.values[col.key]?.toString() ?? '',
      ),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: col.type == 'text' ? 3 : 1,
      maxLength: col.maxLength,
      keyboardType: col.type == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tableDef.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: enabled
                      ? () => _openRowEditor(
                          context: context,
                          index: null,
                        )
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj red'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(
                tableDef.minRows > 0
                    ? 'Obavezno najmanje ${tableDef.minRows} red(ova).'
                    : 'Nema unesenih redova.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Sažetak')),
                    DataColumn(label: Text('Akcije')),
                  ],
                  rows: [
                    for (var i = 0; i < rows.length; i++)
                      DataRow(
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(rows[i].displaySummary(_summaryColumnKeys))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Uredi red',
                                  onPressed: enabled
                                      ? () => _openRowEditor(
                                          context: context,
                                          existing: rows[i],
                                          index: i,
                                        )
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Obriši red',
                                  onPressed: enabled
                                      ? () {
                                          final next =
                                              List<StructuredRepeatableRow>.from(
                                                rows,
                                              )..removeAt(i);
                                          onRowsChanged(next);
                                        }
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isTextLike(String type) => type == 'string' || type == 'text';

  double _computedOperatorProcessedQty(
    Map<String, TextEditingController> textControllers, {
    Map<String, String?>? enumSelections,
  }) {
    double readQty(String key) {
      final text = textControllers[key]?.text.trim() ?? '';
      final n = double.tryParse(text.replaceAll(',', '.'));
      if (n == null || n.isNaN) return 0;
      return n < 0 ? 0 : n;
    }

    final rework = enumSelections == null
        ? readQty('reworkAgainQty')
        : 0.0;

    return readQty('okQty') + readQty('scrapQty') + rework;
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}

/// Poruka kada obavezno polje nije popunjeno.
String structuredRequiredFieldMessage(String label) =>
    'Obavezno polje «$label» nije popunjeno.';

/// Validacija svih repeatable tabela prije save/finish.
String? validateStructuredTables({
  required List<StructuredRepeatableTableDefinition> tables,
  required StructuredProfileSessionState state,
}) {
  for (final table in tables) {
    final rows = state.rowsFor(table.key);
    if (table.minRows > 0 && rows.length < table.minRows) {
      return '${table.label}: obavezno najmanje ${table.minRows} red(ova). '
          'Dodajte red prije spremanja.';
    }
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final columns = OperatorWorkLogRowLayout.isOperatorWorkLogTable(table.key)
          ? OperatorWorkLogRowLayout.dialogColumns(table.columns)
          : table.operatorColumns;
      for (final col in columns) {
        final required = OperatorWorkLogRowLayout.isOperatorWorkLogTable(table.key)
            ? OperatorWorkLogRowLayout.isRequired(col)
            : col.required;
        if (!required) continue;
        if (col.isEntitySearchSelect) {
          final sel = row.entitySelections[col.key];
          final label = OperatorWorkLogRowLayout.isOperatorWorkLogTable(table.key)
              ? OperatorWorkLogRowLayout.displayLabel(col)
              : col.label;
          if (sel == null || sel.entityId.isEmpty) {
            return '${table.label}, red ${rowIndex + 1}: '
                '${structuredRequiredFieldMessage(label)}';
          }
          continue;
        }
        final raw = row.values[col.key];
        final label = OperatorWorkLogRowLayout.isOperatorWorkLogTable(table.key)
            ? OperatorWorkLogRowLayout.displayLabel(col)
            : col.label;
        if (raw == null || (raw is String && raw.trim().isEmpty)) {
          return '${table.label}, red ${rowIndex + 1}: '
              '${structuredRequiredFieldMessage(label)}';
        }
      }
      if (OperatorWorkLogRowLayout.isOperatorWorkLogTable(table.key)) {
        final ok = _parseQty(row.values['okQty']);
        final scrap = _parseQty(row.values['scrapQty']);
        if (ok + scrap <= 0) {
          return '${table.label}, red ${rowIndex + 1}: unesite broj OK '
              'i/ili neispravnih komada — ukupno se računa automatski.';
        }
        final start = StructuredDateTimeValue.parse(row.values['startedAt']);
        final end = StructuredDateTimeValue.parse(row.values['finishedAt']);
        if (start != null &&
            end != null &&
            !StructuredDateTimeValue.isEndAfterStart(start, end)) {
          return '${table.label}, red ${rowIndex + 1}: «Kraj rada» mora biti '
              'nakon «Početak rada» '
              '(${BaFormattedDate.formatDateTime(start)} → '
              '${BaFormattedDate.formatDateTime(end)}).';
        }
      }
    }
  }
  return null;
}

double _parseQty(dynamic raw) {
  if (raw is num) return raw < 0 ? 0 : raw.toDouble();
  final n = double.tryParse(raw?.toString().replaceAll(',', '.') ?? '');
  if (n == null || n.isNaN) return 0;
  return n < 0 ? 0 : n;
}

String? validateStructuredHeader({
  required List<ProductionStationProfileField> fields,
  required StructuredProfileSessionState state,
  required Map<String, StructuredEntitySelection?> entitySelections,
  required Map<String, String?> enumSelections,
  required Map<String, DateTime?> dateTimes,
}) {
  for (final field in fields) {
    if (!field.required) continue;
    if (field.isEntitySelect || field.isEntitySearchSelect) {
      final sel = entitySelections[field.key];
      if (sel == null || sel.entityId.isEmpty) {
        return structuredRequiredFieldMessage(field.label);
      }
      continue;
    }
    if (field.type == 'enum') {
      final v = enumSelections[field.key] ?? state.fieldValues[field.key]?.toString();
      if (v == null || v.trim().isEmpty) {
        return structuredRequiredFieldMessage(field.label);
      }
      continue;
    }
    if (field.type == 'datetime') {
      if (dateTimes[field.key] == null &&
          state.fieldValues[field.key] == null) {
        return structuredRequiredFieldMessage(field.label);
      }
      continue;
    }
    if (field.type == 'number') {
      final raw = state.fieldValues[field.key];
      if (raw == null) {
        return structuredRequiredFieldMessage(field.label);
      }
      final n = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(',', '.'));
      if (n == null) {
        return structuredRequiredFieldMessage(field.label);
      }
      continue;
    }
    final raw = state.fieldValues[field.key];
    if (raw == null || (raw is String && raw.trim().isEmpty)) {
      return structuredRequiredFieldMessage(field.label);
    }
  }

  final started = dateTimes['startedAt'] ??
      StructuredDateTimeValue.parse(state.fieldValues['startedAt']);
  final finished = dateTimes['finishedAt'] ??
      StructuredDateTimeValue.parse(state.fieldValues['finishedAt']);
  final hasStarted = fields.any((f) => f.key == 'startedAt');
  final hasFinished = fields.any((f) => f.key == 'finishedAt');
  if (hasStarted &&
      hasFinished &&
      started != null &&
      finished != null &&
      !StructuredDateTimeValue.isEndAfterStart(started, finished)) {
    return '«Vrijeme završetka» mora biti nakon «Vrijeme početka» '
        '(${BaFormattedDate.formatDateTime(started)} → '
        '${BaFormattedDate.formatDateTime(finished)}).';
  }
  return null;
}
