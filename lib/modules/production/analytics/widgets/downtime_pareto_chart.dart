import 'package:flutter/material.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../downtime/analytics/downtime_analytics_engine.dart';

class DowntimeParetoChart extends StatelessWidget {
  const DowntimeParetoChart({
    super.key,
    required this.rows,
    required this.totalMinutes,
    this.maxRows = 10,
  });

  final List<DowntimeParetoRow> rows;
  final int totalMinutes;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nema podataka za Pareto.'),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length && i < maxRows; i++)
          _ParetoRow(
            row: rows[i],
            total: totalMinutes,
          ),
      ],
    );
  }
}

class _ParetoRow extends StatelessWidget {
  const _ParetoRow({
    required this.row,
    required this.total,
  });

  final DowntimeParetoRow row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final w = total > 0 ? row.minutes / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${row.minutes} min'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: w.clamp(0.0, 1.0),
              minHeight: 8,
              color: kOperonixScadaAccentBlue,
            ),
          ),
          Text(
            '${row.pctOfTotalMinutes.toStringAsFixed(1)}% · kumulativno ${row.cumulativePct.toStringAsFixed(1)}%',
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
