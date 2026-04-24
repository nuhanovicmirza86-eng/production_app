import 'package:flutter/material.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../ooe/models/teep_summary.dart';

/// Trend OEE/OOE/TEEP (0–100 %) iz dnevnih [TeepSummary] (scope plant/day).
class OeeTrendLineChart extends StatelessWidget {
  const OeeTrendLineChart({
    super.key,
    required this.plantDaysAsc,
    this.mode = OeeTrendMode.oee,
  });

  final List<TeepSummary> plantDaysAsc;
  final OeeTrendMode mode;

  @override
  Widget build(BuildContext context) {
    if (plantDaysAsc.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Nema dnevnih TEEP podataka za trend.')),
      );
    }
    final vals = plantDaysAsc.map<double>((e) {
      switch (mode) {
        case OeeTrendMode.oee:
          return (e.oee * 100).clamp(0, 100).toDouble();
        case OeeTrendMode.ooe:
          return (e.ooe * 100).clamp(0, 100).toDouble();
        case OeeTrendMode.teep:
          return (e.teep * 100).clamp(0, 100).toDouble();
      }
    }).toList();
    final labels = plantDaysAsc
        .map(
          (e) =>
              '${e.periodDate.toLocal().day.toString().padLeft(2, '0')}.'
              '${e.periodDate.toLocal().month.toString().padLeft(2, '0')}.',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: vals,
              color: kOperonixScadaAccentBlue,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (plantDaysAsc.length <= 20)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

enum OeeTrendMode { oee, ooe, teep }

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    if (n == 1) {
      final p = values.first / 100.0;
      final y = size.height * (1 - p);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    final maxV = 100.0;
    final w = size.width;
    final h = size.height - 4;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = (i / (n - 1)) * w;
      final p = (values[i] / maxV).clamp(0, 1);
      final y = h * (1 - p) + 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
