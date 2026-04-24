import 'package:flutter/material.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../downtime/analytics/downtime_analytics_engine.dart';

class DowntimeDailyBars extends StatelessWidget {
  const DowntimeDailyBars({super.key, required this.buckets});

  final List<DowntimeDailyBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Nema dnevnog razdvajanja u periodu.')),
      );
    }
    final vals = buckets.map((e) => e.minutesClipped.toDouble()).toList();
    final labels = buckets
        .map(
          (e) =>
              '${e.dayLocal.day.toString().padLeft(2, '0')}.'
              '${e.dayLocal.month.toString().padLeft(2, '0')}.',
        )
        .toList();
    return CustomPaint(
      painter: _VerticalBarPainter(
        values: vals,
        labels: labels,
        color: kOperonixScadaAccentBlue,
      ),
      child: const SizedBox(height: 200, width: double.infinity),
    );
  }
}

class _VerticalBarPainter extends CustomPainter {
  _VerticalBarPainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV * 1.08;
    final barW = n > 0 ? (size.width - 16) / n : 0.0;
    final h = size.height - 22;

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final bh = top > 0 ? (v / top) * h : 0.0;
      final x = 8 + i * barW;
      final paint = Paint()..color = color.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + barW * 0.12, h - bh, barW * 0.76, bh),
          const Radius.circular(3),
        ),
        paint,
      );

      if (n <= 31) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: n > 18 ? 7 : 9,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barW);
        tp.paint(
          canvas,
          Offset(x + (barW - tp.width) / 2, h + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarPainter oldDelegate) =>
      oldDelegate.values != values;
}
