import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Gornja vremenska skala Gantt-a (horizon).
class ApsGanttTimeline extends StatelessWidget {
  const ApsGanttTimeline({
    super.key,
    required this.horizonStart,
    required this.horizonEnd,
    required this.width,
    this.height = 36,
  });

  final DateTime horizonStart;
  final DateTime horizonEnd;
  final double width;
  final double height;

  static final _dayFmt = DateFormat('d.M.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = horizonEnd.difference(horizonStart).inMilliseconds;
    if (totalMs <= 0) {
      return SizedBox(
        width: width,
        height: height,
        child: const Center(child: Text('Nevaljan horizon')),
      );
    }

    final dayCount = horizonEnd.difference(horizonStart).inDays.clamp(1, 120);
    final tickEvery = dayCount <= 14 ? 1 : (dayCount / 10).ceil();

    final ticks = <Widget>[];
    var day = DateTime(
      horizonStart.year,
      horizonStart.month,
      horizonStart.day,
    );
    final endDay = DateTime(horizonEnd.year, horizonEnd.month, horizonEnd.day);
    var i = 0;
    while (!day.isAfter(endDay)) {
      if (i % tickEvery == 0) {
        final offset = day.difference(horizonStart).inMilliseconds / totalMs;
        ticks.add(
          Positioned(
            left: (offset * width).clamp(0, width - 40),
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 1, height: 8, color: theme.dividerColor),
                Text(
                  _dayFmt.format(day),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      day = day.add(const Duration(days: 1));
      i++;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Stack(children: ticks),
    );
  }
}

/// Vertikalne linije dana u tijelu Gantt-a.
class ApsGanttTimelineGrid extends StatelessWidget {
  const ApsGanttTimelineGrid({
    super.key,
    required this.horizonStart,
    required this.horizonEnd,
    required this.width,
    required this.height,
  });

  final DateTime horizonStart;
  final DateTime horizonEnd;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = horizonEnd.difference(horizonStart).inMilliseconds;
    if (totalMs <= 0) return SizedBox(width: width, height: height);

    final dayCount = horizonEnd.difference(horizonStart).inDays.clamp(1, 120);
    final lines = <Widget>[];
    for (var d = 1; d <= dayCount; d++) {
      final x = (d / dayCount) * width;
      lines.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 0,
          child: Container(width: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(children: lines),
    );
  }
}

/// Izračun širine timeline-a prema trajanju horizonta.
double apsGanttTimelineWidth({
  required DateTime horizonStart,
  required DateTime horizonEnd,
  required double viewportWidth,
  double minWidth = 640,
  double pixelsPerDay = 48,
}) {
  final days = horizonEnd.difference(horizonStart).inDays.clamp(1, 365);
  return (days * pixelsPerDay).clamp(minWidth, viewportWidth * 3);
}

/// Udjeli pozicije operacije unutar horizonta (0–1).
({double left, double width}) apsGanttBarFractions({
  required DateTime horizonStart,
  required DateTime horizonEnd,
  required DateTime? opStart,
  required DateTime? opEnd,
}) {
  final totalMs = horizonEnd.difference(horizonStart).inMilliseconds;
  if (totalMs <= 0 || opStart == null || opEnd == null) {
    return (left: 0, width: 0);
  }
  final startMs = opStart.difference(horizonStart).inMilliseconds;
  final endMs = opEnd.difference(horizonStart).inMilliseconds;
  final left = (startMs / totalMs).clamp(0.0, 1.0);
  final right = (endMs / totalMs).clamp(0.0, 1.0);
  final width = (right - left).clamp(0.02, 1.0);
  return (left: left, width: width);
}
