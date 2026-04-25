import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/orv_demo_data.dart';

/// Prijave prema uru (ulaz / izlaz) za odabranog radnika.
class OrvEventControlBlock extends StatelessWidget {
  const OrvEventControlBlock({
    super.key,
    required this.events,
  });

  final List<OrvClockEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Prijave s uređaja', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: null,
                  child: const Text('Dodaj'),
                ),
                OutlinedButton(
                  onPressed: null,
                  child: const Text('Izmijeni'),
                ),
                OutlinedButton(
                  onPressed: null,
                  child: const Text('Izbriši'),
                ),
                OutlinedButton(
                  onPressed: null,
                  child: const Text('Aktiviraj'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('Dan')),
                  DataColumn(label: Text('Vrijeme')),
                  DataColumn(label: Text('Tip')),
                  DataColumn(label: Text('Uređaj')),
                  DataColumn(label: Text('Deaktiviraj')),
                ],
                rows: [
                  for (final e in events)
                    DataRow(
                      cells: [
                        DataCell(Text('${e.day}')),
                        DataCell(Text(e.timeLabel)),
                        DataCell(Text(e.type)),
                        DataCell(Text(e.device)),
                        const DataCell(Text('—')),
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
}
