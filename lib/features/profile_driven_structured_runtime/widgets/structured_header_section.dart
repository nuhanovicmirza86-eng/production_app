import 'package:flutter/material.dart';

import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_pages/services/production_controlled_input_master_callable_service.dart';
import '../../catalog_evidence_runtime/utils/evidence_input_empty.dart';
import '../models/structured_entity_search_result.dart';
import '../models/structured_profile_session.dart';
import '../services/production_evidence_entity_search_service.dart';
import 'structured_datetime_field.dart';
import 'structured_entity_search_field.dart';
import 'structured_scan_button.dart';

class StructuredHeaderSection extends StatelessWidget {
  const StructuredHeaderSection({
    super.key,
    required this.profile,
    required this.companyId,
    required this.plantKey,
    required this.state,
    required this.workBaths,
    required this.searchService,
    required this.entitySelections,
    required this.enumSelections,
    required this.dateTimes,
    required this.textControllers,
    required this.onFieldChanged,
    required this.onScanResolved,
    this.enabled = true,
    this.masterLoading = false,
    this.masterError,
    this.excludedFieldKeys = const {},
    this.recentEntitySuggestions = const {},
    this.recentEntitySuggestionLabels = const {},
    this.entitySearchOverrides = const {},
    this.fieldOverrides = const {},
    this.headerNotice,
    this.plantDisplayLabel,
    this.showOrderScan = true,
  });

  final ProductionStationProfileCatalogEntry profile;
  final String companyId;
  final String plantKey;
  final StructuredProfileSessionState state;
  final List<ControlledInputWorkBathOption> workBaths;
  final ProductionEvidenceEntitySearchCallableService searchService;
  final Map<String, StructuredEntitySelection?> entitySelections;
  final Map<String, String?> enumSelections;
  final Map<String, DateTime?> dateTimes;
  final Map<String, TextEditingController> textControllers;
  final VoidCallback onFieldChanged;
  final ValueChanged<StructuredScanResolveResult> onScanResolved;
  final bool enabled;
  final bool masterLoading;
  final Object? masterError;
  /// Polja koja se ne prikazuju u formi (npr. auto-popunjeni kontrolor).
  final Set<String> excludedFieldKeys;
  /// fieldKey → zadnji korišteni entiteti (chips).
  final Map<String, List<StructuredEntitySearchResult>> recentEntitySuggestions;
  /// fieldKey → naslov chips sekcije.
  final Map<String, String> recentEntitySuggestionLabels;
  /// fieldKey → custom search (npr. M1-I9-B BOM picker).
  final Map<String, StructuredEntitySearchFn> entitySearchOverrides;
  /// fieldKey → override katalog polja (helper / minSearchChars).
  final Map<String, ProductionStationProfileField> fieldOverrides;
  /// Opcionalni banner iznad polja (npr. BOM status).
  final Widget? headerNotice;
  /// Ljudski naziv pogona (npr. Brizganje (BR)).
  final String? plantDisplayLabel;
  /// 5S i slične evidencije nisu vezane za nalog — sakrij QR / pretragu naloga.
  final bool showOrderScan;

  List<ProductionStationProfileField> get _fields => profile.structuredHeaderFields
      .where((f) => !excludedFieldKeys.contains(f.key))
      .where(
        (f) => f.isVisibleGiven(
          fieldValues: state.fieldValues,
          enumSelections: enumSelections,
        ),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Zaglavlje operacije',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (masterError != null) ...[
              const SizedBox(height: 8),
              Text(
                masterError.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (showOrderScan) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StructuredScanButton(
                    companyId: companyId,
                    plantKey: plantKey,
                    searchService: searchService,
                    enabled: enabled,
                    onResolved: onScanResolved,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Proizvodni nalog: skenirajte QR / barkod ili unesite broj naloga ručno.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (headerNotice != null) ...[
              headerNotice!,
              const SizedBox(height: 12),
            ],
            ..._fields.map((field) {
              final effective = fieldOverrides[field.key] ?? field;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildField(context, effective),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, ProductionStationProfileField field) {
    if (field.isEntitySelect) {
      return _buildWorkBathDropdown(context, field);
    }
    if (field.isEntitySearchSelect) {
      final overrideSearch = entitySearchOverrides[field.key];
      return StructuredEntitySearchField(
        field: field,
        companyId: companyId,
        plantKey: plantKey,
        plantDisplayLabel: plantDisplayLabel,
        enabled: enabled,
        initialSelection: entitySelections[field.key],
        recentSuggestions:
            recentEntitySuggestions[field.key] ?? const [],
        recentSuggestionsLabel: recentEntitySuggestionLabels[field.key],
        searchFn: overrideSearch ??
            ((query) => searchService.searchByCallable(
                  callableName:
                      field.entitySearchCallable ?? 'searchProductionOrders',
                  companyId: companyId,
                  query: query,
                  assignedPlantKey:
                      ProductionEvidenceEntitySearchCallableService
                              .usesAssignedPlantKey(field.entitySearchCallable)
                          ? plantKey
                          : null,
                )),
        onChanged: (selection) {
          entitySelections[field.key] = selection;
          final snapKey = personNameSnapshotKeyForField(field.key);
          if (selection != null) {
            state.fieldValues[field.key] = selection.entityId;
            final label = selection.displayLabel.trim();
            if (snapKey != null && label.isNotEmpty) {
              state.fieldValues[snapKey] = label;
            }
          } else {
            state.fieldValues.remove(field.key);
            if (snapKey != null) {
              state.fieldValues.remove(snapKey);
            }
          }
          onFieldChanged();
        },
      );
    }
    if (field.type == 'enum') {
      if (field.usesChipEnumControl) {
        return _buildEnumChips(context, field);
      }
      final options = field.enumValues.isNotEmpty
          ? field.enumValues
          : profile.allowedUnits;
      final selected = enumSelections[field.key];
      final dropdownValue =
          selected != null && options.contains(selected) ? selected : null;
      return InputDecorator(
        decoration: _fieldDecoration(context, field),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: dropdownValue,
            hint: Text(evidenceSelectHint()),
            items: options
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(field.enumLabelFor(value)),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled
                ? (value) {
                    enumSelections[field.key] = value;
                    if (value == null) {
                      state.fieldValues.remove(field.key);
                    } else {
                      state.fieldValues[field.key] = value;
                    }
                    onFieldChanged();
                  }
                : null,
          ),
        ),
      );
    }
    if (field.type == 'boolean') {
      return _buildBooleanChips(context, field);
    }
    if (field.type == 'datetime') {
      return StructuredDateTimeField(
        label: field.label,
        required: field.required,
        enabled: enabled,
        helperText: field.helperText,
        value: dateTimes[field.key],
        onChanged: (dt) {
          dateTimes[field.key] = dt;
          if (dt == null) {
            state.fieldValues.remove(field.key);
          } else {
            state.fieldValues[field.key] = structuredDateTimePayload(dt);
          }
          onFieldChanged();
        },
      );
    }
    final controller = textControllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: field.type == 'text' ? 3 : 1,
      maxLength: field.maxLength,
      keyboardType: field.type == 'number'
          ? const TextInputType.numberWithOptions(decimal: false)
          : TextInputType.text,
      decoration: _fieldDecoration(
        context,
        field,
        hintText: field.type == 'string' ? evidenceTextHint() : null,
      ),
      onChanged: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || isEvidenceFormPlaceholder(trimmed)) {
          state.fieldValues.remove(field.key);
        } else {
          state.fieldValues[field.key] = trimmed;
        }
        onFieldChanged();
      },
    );
  }

  /// M1-I3-D — kratki diskretan helper; bez info ikone uz helperText.
  InputDecoration _fieldDecoration(
    BuildContext context,
    ProductionStationProfileField field, {
    String? hintText,
  }) {
    final theme = Theme.of(context);
    final helper = field.helperText?.trim();
    return InputDecoration(
      labelText: field.required ? '${field.label} *' : field.label,
      hintText: hintText,
      border: const OutlineInputBorder(),
      helperText: (helper == null || helper.isEmpty) ? null : helper,
      helperMaxLines: 2,
      helperStyle: theme.textTheme.bodySmall?.copyWith(
        fontSize: 11,
        height: 1.25,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildEnumChips(
    BuildContext context,
    ProductionStationProfileField field,
  ) {
    final options = field.enumValues.isNotEmpty
        ? field.enumValues
        : profile.allowedUnits;
    final selected = enumSelections[field.key];
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: _fieldDecoration(context, field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in options)
              ChoiceChip(
                label: Text(field.enumLabelFor(value)),
                selected: selected == value,
                selectedColor: value == 'not_ok' || value == 'does_not_satisfy'
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.secondaryContainer,
                onSelected: enabled
                    ? (isSelected) {
                        if (!isSelected) return;
                        enumSelections[field.key] = value;
                        state.fieldValues[field.key] = value;
                        onFieldChanged();
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooleanChips(
    BuildContext context,
    ProductionStationProfileField field,
  ) {
    final raw = state.fieldValues[field.key];
    bool? selected;
    if (raw == true || raw == 'true' || raw == 1 || raw == '1') {
      selected = true;
    } else if (raw == false || raw == 'false' || raw == 0 || raw == '0') {
      selected = false;
    }
    return InputDecorator(
      decoration: _fieldDecoration(context, field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: true, label: Text('DA')),
            ButtonSegment<bool>(value: false, label: Text('NE')),
          ],
          emptySelectionAllowed: !field.required,
          showSelectedIcon: false,
          selected: selected == null ? <bool>{} : {selected},
          onSelectionChanged: enabled
              ? (next) {
                  if (next.isEmpty) {
                    state.fieldValues.remove(field.key);
                  } else {
                    state.fieldValues[field.key] = next.first;
                  }
                  onFieldChanged();
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildWorkBathDropdown(
    BuildContext context,
    ProductionStationProfileField field,
  ) {
    final selected = entitySelections[field.key]?.entityId;
    return InputDecorator(
      decoration: _fieldDecoration(context, field),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: workBaths.any((b) => b.id == selected) ? selected : null,
          hint: Text(masterLoading ? 'Učitavanje…' : evidenceSelectHint()),
          items: workBaths
              .map(
                (b) => DropdownMenuItem<String>(
                  value: b.id,
                  child: Text(b.dropdownLabel),
                ),
              )
              .toList(growable: false),
          onChanged: enabled && !masterLoading
              ? (value) {
                  if (value == null || value.isEmpty) {
                    entitySelections[field.key] = null;
                    state.fieldValues.remove(field.key);
                  } else {
                    final bath = workBaths.firstWhere((b) => b.id == value);
                    entitySelections[field.key] = StructuredEntitySelection(
                      fieldKey: field.key,
                      entityId: bath.id,
                      displayLabel: bath.dropdownLabel,
                    );
                    state.fieldValues[field.key] = bath.id;
                  }
                  onFieldChanged();
                }
              : null,
        ),
      ),
    );
  }
}
