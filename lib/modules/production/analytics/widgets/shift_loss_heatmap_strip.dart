import 'package:flutter/material.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../downtime/analytics/downtime_analytics_engine.dart';

/// Pojednostavljeni „heatmap” udjela zastoja po smjeni (cijeli period, ne dan×smjena).
class ShiftLossHeatmapStrip extends StatelessWidget {
  const ShiftLossHeatmapStrip({super.key, required this.byShift});

  final List<DowntimeGroupStats> byShift;

  @override
  Widget build(BuildContext context) {
    if (byShift.isEmpty) {
      return const Text('Nema podataka o smjenama u periodu.');
    }
    final t = Theme.of(context);
    final tot = byShift.fold<int>(0, (a, b) => a + b.minutesClipped);
    if (tot <= 0) {
      return const Text('Sve minute su nula u grupi smjena.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Udio zastoja (min) po smjeni u periodu',
          style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final s in byShift)
              Expanded(
                flex: (s.minutesClipped * 1000 / tot).round().clamp(1, 1000000),
                child: Tooltip(
                  message: '${s.label}\n${s.minutesClipped} min',
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: kOperonixScadaAccentBlue.withValues(
                        alpha: 0.2 + 0.55 * (s.minutesClipped / tot),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in byShift)
              Text(
                '${_short(s.label)}: ${s.minutesClipped} min',
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _short(String s) {
    final t = s.trim();
    if (t.length <= 24) return t;
    return '${t.substring(0, 21)}…';
  }
}
