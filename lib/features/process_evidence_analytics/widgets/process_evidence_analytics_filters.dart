import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/station_pages/models/production_station_config.dart';

class ProcessEvidenceAnalyticsFiltersPanel extends StatelessWidget {
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

  String _formatDisplayDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filteri',
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DatePickerField(
                  label: 'Period od',
                  value: _formatDisplayDate(dateFrom),
                  onTap: onPickDateFrom,
                ),
                _DatePickerField(
                  label: 'Period do',
                  value: _formatDisplayDate(dateTo),
                  onTap: onPickDateTo,
                ),
                if (canPickPlant)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: plantKey?.isEmpty == true ? null : plantKey,
                      decoration: const InputDecoration(
                        labelText: 'Pogon',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi pogoni'),
                        ),
                        ...plantOptions.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.plantKey,
                            child: Text(p.label, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: loading ? null : onPlantChanged,
                    ),
                  )
                else if ((fixedPlantLabel ?? '').isNotEmpty)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pogon',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      fixedPlantLabel!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    value: processProfileType?.isEmpty == true
                        ? null
                        : processProfileType,
                    decoration: const InputDecoration(
                      labelText: 'Profil evidencije',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: profileOptions.entries
                        .map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.key,
                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: loading ? null : onProfileChanged,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    value: stationConfigId?.isEmpty == true ? null : stationConfigId,
                    decoration: const InputDecoration(
                      labelText: 'Stanica',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sve stanice'),
                      ),
                      ...stationOptions.map(
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
                    onChanged: loading ? null : onStationChanged,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    value: operatorId?.isEmpty == true ? null : operatorId,
                    decoration: const InputDecoration(
                      labelText: 'Operater',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Svi operateri'),
                      ),
                      ...operatorOptions.map(
                        (o) => DropdownMenuItem<String?>(
                          value: o.id,
                          child: Text(o.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: loading ? null : onOperatorChanged,
                  ),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : onApply,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('Primijeni'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(value),
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
