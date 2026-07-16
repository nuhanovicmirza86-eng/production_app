import 'package:flutter/material.dart';

import '../../../features/process_evidence_analytics/models/process_evidence_analytics_models.dart';
import '../../../features/process_evidence_analytics/widgets/normative_comparison_panel.dart';
import '../../../features/process_evidence_analytics/widgets/process_evidence_breakdown_tables.dart';
import '../../../features/station_evidence/utils/profile_driven_evidence_rework_labels.dart';
import '../widgets/workforce_screen_help.dart';

/// Objektivni KPI iz evidencija procesa (read-only blok na KPI radnika).
class WorkforceEvidenceKpiSection extends StatelessWidget {
  const WorkforceEvidenceKpiSection({
    super.key,
    required this.kpiRow,
    required this.breakdowns,
    required this.loading,
    this.error,
  });

  final WorkerPerformanceKpiRow? kpiRow;
  final Map<String, List<ProcessEvidenceBreakdownRow>> breakdowns;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Objektivni KPI iz evidencija procesa',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const WorkforceScreenHelpIcon(
              title: WorkforceHelpTexts.evidenceKpiSectionTitle,
              message: WorkforceHelpTexts.evidenceKpiSectionMessage,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if ((error ?? '').isNotEmpty)
          Text(
            error!,
            style: TextStyle(color: cs.error),
          )
        else if (kpiRow == null)
          Text(
            'Nema evidencija procesa za odabranog radnika u periodu.',
            style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else ...[
          NormativeComparisonPanel(comparison: kpiRow!.normativeComparison),
          const SizedBox(height: 12),
          _metricsWrap(context, kpiRow!),
          const SizedBox(height: 12),
          _operationLists(context, kpiRow!),
          const SizedBox(height: 16),
          ProcessEvidenceBreakdownTable(
            title: 'Po profilu',
            rows: breakdowns['profile'] ?? const [],
            dimension: 'profile',
          ),
          const SizedBox(height: 16),
          ProcessEvidenceBreakdownTable(
            title: 'Po tipu operacije',
            rows: breakdowns['operation_type'] ?? const [],
            dimension: 'operation_type',
          ),
          const SizedBox(height: 16),
          ProcessEvidenceBreakdownTable(
            title: 'Po proizvodu',
            rows: breakdowns['product'] ?? const [],
            dimension: 'product',
          ),
          const SizedBox(height: 16),
          ProcessEvidenceBreakdownTable(
            title: 'Po razlogu škarta',
            rows: breakdowns['scrap_reason'] ?? const [],
            dimension: 'scrap_reason',
          ),
        ],
      ],
    );
  }

  Widget _metricsWrap(BuildContext context, WorkerPerformanceKpiRow row) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metricChip(context, 'Obrađeno', formatAnalyticsNumber(row.processedQty)),
        _metricChip(context, 'OK', formatAnalyticsNumber(row.okQty)),
        _metricChip(context, 'Škart', formatAnalyticsNumber(row.scrapQty)),
        _metricChip(
          context,
          'Ponovna dorada',
          formatAnalyticsNumber(row.reworkAgainQty),
        ),
        _metricChip(
          context,
          'Vrijeme',
          formatDurationMinutes(row.durationMinutes),
        ),
        _metricChip(
          context,
          'Komada/sat',
          formatAnalyticsNumber(row.piecesPerHour),
        ),
        _metricChip(context, 'Škart %', formatAnalyticsPercent(row.scrapRate)),
        _metricChip(
          context,
          'Ponovna dorada %',
          formatAnalyticsPercent(row.reworkRate),
        ),
      ],
    );
  }

  Widget _operationLists(BuildContext context, WorkerPerformanceKpiRow row) {
    final t = Theme.of(context);
    final best = row.bestOperationTypes
        .map(formatReworkOperationTypeLabel)
        .join(', ');
    final risk = row.riskOperationTypes
        .map(formatReworkOperationTypeLabel)
        .join(', ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operacije',
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Najbolje operacije: ${best.isEmpty ? '—' : best}'),
            Text('Rizične operacije: ${risk.isEmpty ? '—' : risk}'),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(BuildContext context, String label, String value) {
    final t = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
