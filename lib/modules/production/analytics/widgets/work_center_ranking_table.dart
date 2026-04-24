import 'package:flutter/material.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../downtime/analytics/downtime_analytics_engine.dart';

class WorkCenterRankingTable extends StatelessWidget {
  const WorkCenterRankingTable({
    super.key,
    required this.rows,
    this.onSelect,
  });

  final List<DowntimeGroupStats> rows;
  final void Function(DowntimeGroupStats row)? onSelect;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nema podataka po radnom centru.'),
      );
    }
    final list = rows.take(15).toList();
    return Card(
      shape: operonixProductionCardShape(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('Radni centar')),
            DataColumn(label: Text('Zastoji'), numeric: true),
            DataColumn(label: Text('Min'), numeric: true),
            DataColumn(label: Text('OEE min'), numeric: true),
          ],
          rows: [
            for (final g in list)
              DataRow(
                onSelectChanged: onSelect == null
                    ? null
                    : (_) {
                        onSelect!(g);
                      },
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        g.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text('${g.events}')),
                  DataCell(Text('${g.minutesClipped}')),
                  DataCell(Text('${g.minutesOee}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
