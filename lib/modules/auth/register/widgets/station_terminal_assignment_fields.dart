import 'package:flutter/material.dart';

import '../../../production/station_pages/models/production_station_config.dart';

/// M1-G5-F2 — Admin UI polja za dodjelu accounta terminala stanici.
class StationTerminalAssignmentFields extends StatelessWidget {
  const StationTerminalAssignmentFields({
    super.key,
    required this.stations,
    required this.selectedStationConfigId,
    required this.onStationChanged,
    required this.onRemoveAssignment,
    this.loading = false,
    this.enabled = true,
  });

  final List<ProductionStationConfig> stations;
  final String selectedStationConfigId;
  final ValueChanged<String?> onStationChanged;
  final VoidCallback onRemoveAssignment;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canInteract = enabled && !loading;
    final hasAssignment = selectedStationConfigId.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terminal stanice',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Account terminala nije konfiguracija stanice. '
          'Ovdje se samo otvara već postavljena proizvodna stanica.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: hasAssignment ? selectedStationConfigId : null,
          decoration: InputDecoration(
            labelText: 'Dodijeljena stanica',
            helperText: loading
                ? 'Učitavam stanice...'
                : stations.isEmpty
                ? 'Nema dostupnih stanica za odabrani pogon.'
                : null,
          ),
          items: stations
              .map(
                (station) => DropdownMenuItem<String>(
                  value: station.id,
                  child: Text(
                    station.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: canInteract && stations.isNotEmpty ? onStationChanged : null,
        ),
        if (hasAssignment) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: canInteract ? onRemoveAssignment : null,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Ukloni dodjelu'),
            ),
          ),
        ],
      ],
    );
  }
}

List<ProductionStationConfig> filterTerminalAssignableStations({
  required List<ProductionStationConfig> configs,
  required String plantKey,
}) {
  final pk = plantKey.trim();
  return configs
      .where((c) => c.active)
      .where((c) => !c.isMachineStation)
      .where((c) {
        final configPlant = c.assignedPlantKey.trim();
        if (configPlant.isEmpty) return true;
        if (pk.isEmpty) return false;
        return configPlant == pk;
      })
      .toList()
    ..sort((a, b) {
      final slotCmp = a.stationSlot.compareTo(b.stationSlot);
      if (slotCmp != 0) return slotCmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
}

String? stationTitleForConfigId({
  required List<ProductionStationConfig> configs,
  required String configId,
}) {
  final id = configId.trim();
  if (id.isEmpty) return null;
  for (final c in configs) {
    if (c.id == id) return c.title;
  }
  return null;
}
