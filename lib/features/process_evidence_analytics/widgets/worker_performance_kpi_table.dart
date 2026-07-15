import 'package:flutter/material.dart';

import '../../../core/ui/standard_table_components.dart';
import '../../../features/station_evidence/utils/profile_driven_evidence_rework_labels.dart';
import '../../../features/station_evidence/widgets/profile_driven_evidence_grid.dart';
import '../models/process_evidence_analytics_models.dart';

class WorkerPerformanceKpiTable extends StatelessWidget {
  const WorkerPerformanceKpiTable({
    super.key,
    required this.operators,
  });

  final List<WorkerPerformanceKpiRow> operators;

  static const _columns = [
    ProfileDrivenEvidenceGridColumn(id: 'name', label: 'Radnik', flex: 3),
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
      id: 'pph',
      label: 'Kom/sat',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'scrapRate',
      label: 'Škart %',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'reworkRate',
      label: 'Pon. dorada %',
      flex: 2,
      align: TextAlign.right,
      numeric: true,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'best',
      label: 'Najbolje operacije',
      flex: 3,
    ),
    ProfileDrivenEvidenceGridColumn(
      id: 'risk',
      label: 'Rizične operacije',
      flex: 3,
    ),
  ];

  String _formatOperationList(List<String> values) {
    if (values.isEmpty) return '—';
    return values.map(formatReworkOperationTypeLabel).join(', ');
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
          'KPI radnika',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (operators.isEmpty)
          Text(
            'Nema podataka o radnicima za odabrane filtere.',
            style: t.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          )
        else
          StandardTableShell(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1200,
                child: Column(
                  children: [
                    ProfileDrivenEvidenceGridTable(columns: _columns),
                    for (final op in operators)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            profileEvidenceGridTextCell(
                              column: _columns[0],
                              text: op.operatorDisplayName,
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[1],
                              text: formatAnalyticsNumber(op.processedQty),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[2],
                              text: formatAnalyticsNumber(op.okQty),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[3],
                              text: formatAnalyticsNumber(op.scrapQty),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[4],
                              text: formatAnalyticsNumber(op.reworkAgainQty),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[5],
                              text: formatDurationMinutes(op.durationMinutes),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[6],
                              text: formatAnalyticsNumber(op.piecesPerHour),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[7],
                              text: formatAnalyticsPercent(op.scrapRate),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[8],
                              text: formatAnalyticsPercent(op.reworkRate),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[9],
                              text: _formatOperationList(op.bestOperationTypes),
                              borderColor: borderColor,
                              rowBackground: rowBackground,
                              cellStyle: cellStyle,
                            ),
                            profileEvidenceGridTextCell(
                              column: _columns[10],
                              text: _formatOperationList(op.riskOperationTypes),
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
            ),
          ),
      ],
    );
  }
}
