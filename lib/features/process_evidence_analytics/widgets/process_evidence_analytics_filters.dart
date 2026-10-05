import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../core/visual/operonix_collapsible_section.dart';
import '../../../core/visual/operonix_shell_metrics.dart';
import '../../../core/visual/premium/operonix_premium_icon.dart';
import '../../../core/visual/premium/premium_icon_accent.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';

class ProcessEvidenceAnalyticsFiltersPanel extends StatefulWidget {
  const ProcessEvidenceAnalyticsFiltersPanel({
    super.key,
    required this.dateFrom,
    required this.dateTo,
    required this.plantKey,
    required this.processProfileType,
    required this.stationConfigId,
    required this.operatorId,
    required this.plantOptions,
    required this.stationOptions,
    required this.operatorOptions,
    required this.canPickPlant,
    required this.fixedPlantLabel,
    required this.loading,
    required this.onPickDateFrom,
    required this.onPickDateTo,
    required this.onPlantChanged,
    required this.onProfileChanged,
    required this.onStationChanged,
    required this.onOperatorChanged,
    required this.onApply,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final String? plantKey;
  final String? processProfileType;
  final String? stationConfigId;
  final String? operatorId;
  final List<({String plantKey, String label})> plantOptions;
  final List<ProductionStationConfig> stationOptions;
  final List<({String id, String label})> operatorOptions;
  final bool canPickPlant;
  final String? fixedPlantLabel;
  final bool loading;
  final VoidCallback onPickDateFrom;
  final VoidCallback onPickDateTo;
  final ValueChanged<String?> onPlantChanged;
  final ValueChanged<String?> onProfileChanged;
  final ValueChanged<String?> onStationChanged;
  final ValueChanged<String?> onOperatorChanged;
  final VoidCallback onApply;

  static const profileOptions = <String?, String>{
    null: 'Svi profili',
    'chemical_dosing': 'Doziranje hemikalija',
    'wastewater_treatment': 'Obrada otpadnih voda',
    'rework_and_painting': 'Dorada i površinska obrada',
  };

  @override
  State<ProcessEvidenceAnalyticsFiltersPanel> createState() =>
      _ProcessEvidenceAnalyticsFiltersPanelState();
}

class _ProcessEvidenceAnalyticsFiltersPanelState
    extends State<ProcessEvidenceAnalyticsFiltersPanel> {
  bool? _expandedOverride;

  bool _mobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width <
        OperonixShellMetrics.wideBreakpoint;
  }

  String _formatDisplayDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String _profileLabel(String? value) {
    return ProcessEvidenceAnalyticsFiltersPanel.profileOptions[value] ??
        'Svi profili';
  }

  String _summary() {
    final parts = <String>[
      '${_formatDisplayDate(widget.dateFrom)} – ${_formatDisplayDate(widget.dateTo)}',
    ];
    if (widget.canPickPlant) {
      final key = widget.plantKey;
      if (key == null || key.isEmpty) {
        parts.add('Svi pogoni');
      } else {
        for (final p in widget.plantOptions) {
          if (p.plantKey == key) {
            parts.add(p.label);
            break;
          }
        }
      }
    } else if ((widget.fixedPlantLabel ?? '').isNotEmpty) {
      parts.add(widget.fixedPlantLabel!);
    }
    if ((widget.processProfileType ?? '').isNotEmpty) {
      parts.add(_profileLabel(widget.processProfileType));
    }
    return parts.join(' · ');
  }

  int get _activeCount {
    var n = 0;
    if ((widget.plantKey ?? '').isNotEmpty) n++;
    if ((widget.processProfileType ?? '').isNotEmpty) n++;
    if ((widget.stationConfigId ?? '').isNotEmpty) n++;
    if ((widget.operatorId ?? '').isNotEmpty) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _mobile(context);
    final expanded = _expandedOverride ?? !mobile;
    return OperonixCollapsibleSection(
      title: 'Filteri',
      summary: _summary(),
      expanded: expanded,
      activeCount: _activeCount,
      glyph: OperonixPremiumGlyph.entryDate,
      role: PremiumIconRole.info,
      onToggle: () => setState(() => _expandedOverride = !expanded),
      child: expanded ? _fields(context) : const SizedBox.shrink(),
    );
  }

  Widget _fields(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.sizeOf(context).width;
        final incoming = constraints.maxWidth;
        final width = incoming.isFinite
            ? math.min(incoming, viewport)
            : viewport;
        final narrow = width < 600;
        final fieldWidth = narrow ? width : math.min(240.0, width);
        final children = <Widget>[
          _DatePickerField(
            label: 'Period od',
            value: _formatDisplayDate(widget.dateFrom),
            onTap: widget.onPickDateFrom,
            width: fieldWidth,
          ),
          _DatePickerField(
            label: 'Period do',
            value: _formatDisplayDate(widget.dateTo),
            onTap: widget.onPickDateTo,
            width: fieldWidth,
          ),
          if (widget.canPickPlant)
            _dropdown<String?>(
              width: fieldWidth,
              label: 'Pogon',
              value: widget.plantKey?.isEmpty == true ? null : widget.plantKey,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Svi pogoni'),
                ),
                ...widget.plantOptions.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p.plantKey,
                    child: Text(p.label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: widget.loading ? null : widget.onPlantChanged,
            )
          else if ((widget.fixedPlantLabel ?? '').isNotEmpty)
            SizedBox(
              width: fieldWidth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Pogon',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  widget.fixedPlantLabel!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          _dropdown<String?>(
            width: fieldWidth,
            label: 'Profil evidencije',
            value: widget.processProfileType?.isEmpty == true
                ? null
                : widget.processProfileType,
            items: ProcessEvidenceAnalyticsFiltersPanel.profileOptions.entries
                .map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: widget.loading ? null : widget.onProfileChanged,
          ),
          _dropdown<String?>(
            width: fieldWidth,
            label: 'Stanica',
            value: widget.stationConfigId?.isEmpty == true
                ? null
                : widget.stationConfigId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sve stanice'),
              ),
              ...widget.stationOptions.map(
                (c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(
                    (c.displayName ?? '').trim().isNotEmpty
                        ? c.displayName!.trim()
                        : 'Slot ${c.effectiveStationSlot}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: widget.loading ? null : widget.onStationChanged,
          ),
          _dropdown<String?>(
            width: fieldWidth,
            label: 'Operater',
            value: widget.operatorId?.isEmpty == true ? null : widget.operatorId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Svi operateri'),
              ),
              ...widget.operatorOptions.map(
                (o) => DropdownMenuItem<String?>(
                  value: o.id,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: widget.loading ? null : widget.onOperatorChanged,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: widget.loading ? null : widget.onApply,
              icon: widget.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Primijeni'),
            ),
          ),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          );
        }
        return Wrap(spacing: 12, runSpacing: 12, children: children);
      },
    );
  }

  Widget _dropdown<T>({
    required double width,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        key: ValueKey<String>('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.width,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            suffixIconConstraints: BoxConstraints(
              minWidth: 36,
              maxWidth: 36,
              minHeight: 36,
              maxHeight: 36,
            ),
          ),
          child: Text(value, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// Helper za učitavanje plant opcija na ekranu.
Future<List<({String plantKey, String label})>> loadAnalyticsPlantOptions({
  required String companyId,
  required String userRole,
  required String userPlantKey,
}) async {
  if (ProductionAccessHelper.canPickPlantFilterForProfileDrivenEvidence(
    userRole,
  )) {
    return CompanyPlantDisplayName.listSelectablePlants(companyId: companyId);
  }
  if (userPlantKey.isEmpty) return const [];
  final label = await CompanyPlantDisplayName.resolve(
    companyId: companyId,
    plantKey: userPlantKey,
  );
  return [(plantKey: userPlantKey, label: label)];
}

List<ProductionStationConfig> filterAnalyticsStationOptions({
  required List<ProductionStationConfig> configs,
  String? plantKey,
  String? processProfileType,
}) {
  const evidenceProfiles = {
    'chemical_dosing',
    'wastewater_treatment',
    'rework_and_painting',
  };

  return configs.where((c) {
    if (!c.active) return false;
    if (!evidenceProfiles.contains(c.processProfileType.trim())) return false;
    if (plantKey != null &&
        plantKey.isNotEmpty &&
        c.assignedPlantKey.trim() != plantKey) {
      return false;
    }
    if (processProfileType != null &&
        processProfileType.isNotEmpty &&
        c.processProfileType.trim() != processProfileType) {
      return false;
    }
    return true;
  }).toList(growable: false);
}
