import 'package:flutter/material.dart';

/// Kompaktni linijski prikaz niza dnevnih postotaka otpada (0–100).
class DefectPctSparkline extends StatelessWidget {
  const DefectPctSparkline({
    super.key,
    required this.values,
    required this.labels,
    this.height = 88,
  });

  final List<double> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    if (values.isEmpty) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: values, color: c, labels: labels),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.labels,
  });

  final List<double> values;
  final Color color;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    var minV = 0.0;
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV < 1) {
      maxV = 10.0;
    } else {
      maxV = (maxV * 1.15).clamp(5.0, 100.0);
    }
    if (maxV <= minV) {
      maxV = 10.0;
    }
    const bottomPad = 20.0;
    final h = size.height - bottomPad;

    double yFor(double v) {
      final t = (v - minV) / (maxV - minV);
      return h * (1 - t);
    }

    final dx = n <= 1 ? 0.0 : size.width / (n - 1);
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (n == 1) {
      final y = yFor(values[0]);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    } else {
      for (var i = 0; i < n - 1; i++) {
        canvas.drawLine(
          Offset(i * dx, yFor(values[i])),
          Offset((i + 1) * dx, yFor(values[i + 1])),
          linePaint,
        );
      }
    }

    final style = TextStyle(
      color: color.withValues(alpha: 0.7),
      fontSize: n > 18 ? 8 : 10,
    );
    for (var i = 0; i < labels.length && i < n; i++) {
      if (n > 20 && i % 2 == 1) continue;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (i * dx) - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0, size.width - tp.width), h + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
