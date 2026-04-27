import 'package:flutter/material.dart';

import '../services/waste_quality_reports_aggregator.dart';

class WasteReportPeriodSummaryCard extends StatelessWidget {
  const WasteReportPeriodSummaryCard({
    super.key,
    required this.summary,
  });

  final WasteQualityPeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sažetak perioda (sve faze)',
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _row(t, 'Ukupna količina', _fmtNum(summary.totalQty)),
            _row(t, 'Dobro', _fmtNum(summary.goodQty)),
            _row(t, 'Škart', _fmtNum(summary.scrapQty)),
            _row(t, 'Iskorištenost %', '${summary.yieldPct.toStringAsFixed(1)}%'),
            _row(t, 'Otpad %', '${summary.defectPct.toStringAsFixed(1)}%'),
            const SizedBox(height: 4),
            Text(
              'Broj operativnih unosa: ${summary.entryCount}',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(ThemeData t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: t.textTheme.bodyMedium),
          Text(
            v,
            style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
