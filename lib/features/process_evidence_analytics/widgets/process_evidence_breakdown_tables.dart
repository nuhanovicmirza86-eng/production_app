import 'package:flutter/material.dart';

import '../../../core/ui/standard_table_components.dart';
import '../../../features/station_evidence/utils/profile_driven_evidence_rework_labels.dart';
import '../../../features/station_evidence/widgets/profile_driven_evidence_grid.dart';
import '../models/process_evidence_analytics_models.dart';

class ProcessEvidenceBreakdownTables extends StatelessWidget {
  const ProcessEvidenceBreakdownTables({
    super.key,
    required this.breakdowns,
  });

  final Map<String, List<ProcessEvidenceBreakdownRow>> breakdowns;

  static const _sections = <({String dimension, String title})>[
    (dimension: 'profile', title: 'Po profilu'),
    (dimension: 'station', title: 'Po stanici'),
    (dimension: 'operator', title: 'Po operateru'),
    (dimension: 'operation_type', title: 'Po tipu operacije'),
    (dimension: 'scrap_reason', title: 'Po razlogu škarta'),
    (dimension: 'material_type', title: 'Po materijalu'),
    (dimension: 'product', title: 'Po proizvodu'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in _sections) ...[
          ProcessEvidenceBreakdownTable(
            title: section.title,
            rows: breakdowns[section.dimension] ?? const [],
            dimension: section.dimension,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class ProcessEvidenceBreakdownTable extends StatelessWidget {
  const ProcessEvidenceBreakdownTable({
    super.key,
    required this.title,
    required this.rows,
    required this.dimension,
  });

  final String title;
  final List<ProcessEvidenceBreakdownRow> rows;
  final String dimension;

  static const _columns = [
    ProfileDrivenEvidenceGridColumn(id: 'label', label: 'Stavka', flex: 3),
    ProfileDrivenEvidenceGridColumn(
      id: 'processed',
      label: 'Obrađeno',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'ok',
      label: 'OK',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'scrap',
      label: 'Škart',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'rework',
      label: 'Pon. dorada',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'duration',
      label: 'Vrijeme',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'rate',
      label: 'Kom/sat',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
  ];

  String _formatLabel(ProcessEvidenceBreakdownRow row) {
    if (dimension == 'profile') {
      return formatProcessEvidenceProfileLabel(row.label);
    }
    if (dimension == 'operation_type') {
      return formatReworkOperationTypeLabel(row.label);
    }
    return row.label;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final borderColor = StandardTableMetrics.borderColor(cs);
    final cellStyle = StandardTableMetrics.cellStyle(cs);
    final rowBackground = StandardTableMetrics.rowBackground(cs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            'Nema podataka za odabrane filtere.',
            style: t.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          )
        else
          StandardTableShell(
            child: Column(
              children: [
                ProfileDrivenEvidenceGridTable(columns: _columns),
                for (final row in rows)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        profileEvidenceGridTextCell(
                          column: _columns[0],
                          text: _formatLabel(row),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                        ),
                        profileEvidenceGridTextCell(
                          column: _columns[1],
                          text: formatAnalyticsNumber(row.processedTotalQty),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                        ),
                        profileEvidenceGridTextCell(
                          column: _columns[2],
                          text: formatAnalyticsNumber(row.okTotalQty),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                        ),
                        profileEvidenceGridTextCell(
                          column: _columns[3],
                          text: formatAnalyticsNumber(row.scrapTotalQty),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                        ),
                        profileEvidenceGridTextCell(
                          column: _columns[4],
                          text: formatAnalyticsNumber(row.reworkAgainTotalQty),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                        ),
                        profileEvidenceGridTextCell(
                          column: _columns[5],
                          text: formatDurationMinutes(row.durationMinutesTotal),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                        ),
                        profileEvidenceGridTextCell(
                          column: _columns[6],
                          text: formatAnalyticsNumber(row.averagePiecesPerHour),
                          borderColor: borderColor,
                          rowBackground: rowBackground,
                          cellStyle: cellStyle,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
