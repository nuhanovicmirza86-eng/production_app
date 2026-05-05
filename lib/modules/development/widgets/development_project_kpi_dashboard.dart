import 'package:flutter/material.dart';

import '../models/development_project_model.dart';
import '../utils/development_help_texts.dart';
import '../../production/ooe/widgets/ooe_info_icon.dart';

/// KPI ploče (Stage-Gate / NPI) — dijeljeno između detalja projekta i demo prikaza.
class DevelopmentProjectKpiDashboard extends StatelessWidget {
  const DevelopmentProjectKpiDashboard({
    super.key,
    required this.kpi,
    required this.progressPercent,
  });

  final DevelopmentProjectKpi kpi;
  final int progressPercent;

  static String _fmtNum(double? v) {
    if (v == null) return '—';
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = progressPercent.clamp(0, 100);

    Widget tile(
      String label,
      String value, {
      IconData? icon,
      required String helpTooltip,
      required String helpTitle,
      required String helpBody,
    }) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: tt.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  OoeInfoIcon(
                    tooltip: helpTooltip,
                    dialogTitle: helpTitle,
                    dialogBody: helpBody,
                    iconSize: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tiles = <Widget>[
      tile(
        'Schedule performance',
        _fmtNum(kpi.schedulePerformance),
        icon: Icons.schedule,
        helpTooltip: DevelopmentHelpTexts.kpiScheduleTooltip,
        helpTitle: DevelopmentHelpTexts.kpiScheduleTitle,
        helpBody: DevelopmentHelpTexts.kpiScheduleBody,
      ),
      tile(
        'Cost performance',
        _fmtNum(kpi.costPerformance),
        icon: Icons.savings_outlined,
        helpTooltip: DevelopmentHelpTexts.kpiCostTooltip,
        helpTitle: DevelopmentHelpTexts.kpiCostTitle,
        helpBody: DevelopmentHelpTexts.kpiCostBody,
      ),
      tile(
        'Quality readiness',
        _fmtNum(kpi.qualityReadiness),
        icon: Icons.verified_outlined,
        helpTooltip: DevelopmentHelpTexts.kpiQualityTooltip,
        helpTitle: DevelopmentHelpTexts.kpiQualityTitle,
        helpBody: DevelopmentHelpTexts.kpiQualityBody,
      ),
      tile(
        'Gate pass rate',
        _fmtNum(kpi.gatePassRate),
        icon: Icons.flag_outlined,
        helpTooltip: DevelopmentHelpTexts.kpiGatePassTooltip,
        helpTitle: DevelopmentHelpTexts.kpiGatePassTitle,
        helpBody: DevelopmentHelpTexts.kpiGatePassBody,
      ),
      tile(
        'Risk score',
        _fmtNum(kpi.riskScore),
        icon: Icons.shield_outlined,
        helpTooltip: DevelopmentHelpTexts.kpiRiskTooltip,
        helpTitle: DevelopmentHelpTexts.kpiRiskTitle,
        helpBody: DevelopmentHelpTexts.kpiRiskBody,
      ),
      tile(
        'Overall health',
        _fmtNum(kpi.overallHealthScore),
        icon: Icons.health_and_safety_outlined,
        helpTooltip: DevelopmentHelpTexts.kpiOverallTooltip,
        helpTitle: DevelopmentHelpTexts.kpiOverallTitle,
        helpBody: DevelopmentHelpTexts.kpiOverallBody,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KPI — pregled projekta',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                OoeInfoIcon(
                  tooltip: DevelopmentHelpTexts.kpiDashboardTooltip,
                  dialogTitle: DevelopmentHelpTexts.kpiDashboardTitle,
                  dialogBody: DevelopmentHelpTexts.kpiDashboardBody,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Performans rasporeda i troška, kvaliteta, prolaz Gate-ova i zdravlje — '
              'iz agregata i izvršenja (nema ručnog zaobilaska odobrenja).',
              style: tt.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Text('Operativni napredak', style: tt.labelLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct / 100.0,
                minHeight: 10,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text('$pct %', style: tt.labelMedium),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final colW = w > 520 ? (w - 10) / 2 : w;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: tiles
                      .map(
                        (e) => SizedBox(
                          width: colW,
                          child: e,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
