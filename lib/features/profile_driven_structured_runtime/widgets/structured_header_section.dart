import 'package:flutter/material.dart';

import '../../../modules/production/station_pages/models/production_station_profile_catalog_entry.dart';import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/production/station_pages/services/production_controlled_input_master_callable_service.dart';
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

  List<ProductionStationProfileField> get _fields =>
      profile.structuredHeaderFields;

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
            const SizedBox(height: 12),
            ..._fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildField(context, field),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, ProductionStationProfileField field) {
    if (field.isEntitySelect) {
      return _buildWorkBathDropdown(field);
    }
    if (field.isEntitySearchSelect) {
      return StructuredEntitySearchField(
        field: field,
        companyId: companyId,
        plantKey: plantKey,
        enabled: enabled,
        initialSelection: entitySelections[field.key],
        searchFn: (query) => searchService.searchByCallable(
          callableName: field.entitySearchCallable ?? 'searchProductionOrders',
          companyId: companyId,
          query: query,
        ),
        onChanged: (selection) {
          entitySelections[field.key] = selection;
          if (selection != null) {
            state.fieldValues[field.key] = selection.entityId;
          } else {
            state.fieldValues.remove(field.key);
          }
          onFieldChanged();
        },
      );
    }
    if (field.type == 'enum') {
      final options = field.enumValues.isNotEmpty
          ? field.enumValues
          : profile.allowedUnits;
      return InputDecorator(
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          border: const OutlineInputBorder(),
          helperText: field.helperText,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: enumSelections[field.key],
            hint: const Text('Odaberite…'),
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
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        border: const OutlineInputBorder(),
        helperText: field.helperText,
      ),
      onChanged: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          state.fieldValues.remove(field.key);
        } else {
          state.fieldValues[field.key] = trimmed;
        }
        onFieldChanged();
      },
    );
  }

  Widget _buildWorkBathDropdown(ProductionStationProfileField field) {
    final selected = entitySelections[field.key]?.entityId;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        border: const OutlineInputBorder(),
        helperText: field.helperText,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: workBaths.any((b) => b.id == selected) ? selected : null,
          hint: Text(masterLoading ? 'Učitavanje…' : 'Odaberite…'),
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
