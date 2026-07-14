import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../models/aps_gantt_resource_lane.dart';
import '../models/aps_schedule_operation_view.dart';
import 'aps_gantt_operation_bar.dart';
import 'aps_gantt_timeline.dart';

/// Fiksni stupac s kodom resursa (lijevo od timeline-a).
class ApsGanttResourceLabel extends StatelessWidget {
  const ApsGanttResourceLabel({
    super.key,
    required this.lane,
    required this.height,
    required this.width,
  });

  final ApsGanttResourceLane lane;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
          right: BorderSide(color: theme.dividerColor),
        ),
        color: theme.colorScheme.surface,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              lane.displayLabel,
              style: theme.textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Resurs',
            icon: Icon(Icons.info_outline, size: 16, color: theme.hintColor),
            onPressed: () => showApsGanttInfoDialog(
              context,
              title: 'Resurs',
              body:
                  'Red prikazuje operacije zakazane na resursu ${lane.displayLabel}. '
                  'Samo za pregled — pomjeranje operacija nije dostupno.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Jedan red Gantt-a — operacije na vremenskoj liniji.
class ApsGanttResourceRow extends StatelessWidget {
  const ApsGanttResourceRow({
    super.key,
    required this.lane,
    required this.horizonStart,
    required this.horizonEnd,
    required this.timelineWidth,
    this.rowHeight = 52,
  });

  final ApsGanttResourceLane lane;
  final DateTime horizonStart;
  final DateTime horizonEnd;
  final double timelineWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: timelineWidth,
      height: rowHeight,
      child: Stack(
        children: [
          ApsGanttTimelineGrid(
            horizonStart: horizonStart,
            horizonEnd: horizonEnd,
            width: timelineWidth,
            height: rowHeight,
          ),
          ...lane.operations.map((op) {
            final frac = apsGanttBarFractions(
              horizonStart: horizonStart,
              horizonEnd: horizonEnd,
              opStart: op.scheduledStart,
              opEnd: op.scheduledEnd,
            );
            return ApsGanttOperationBar(
              operation: op,
              left: frac.left * timelineWidth,
              width: frac.width * timelineWidth,
              height: rowHeight - 8,
            );
          }),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(height: 1, color: theme.dividerColor),
          ),
        ],
      ),
    );
  }
}

/// Kompaktan prikaz operacije u listi ispod Gantt-a.
class ApsGanttOperationSummaryTile extends StatelessWidget {
  const ApsGanttOperationSummaryTile({super.key, required this.operation});

  final ApsScheduleOperationView operation;

  static final _timeFmt = DateFormat('d.M. HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = operation.scheduledStart;
    final end = operation.scheduledEnd;
    final timeLine = start != null && end != null
        ? '${_timeFmt.format(start)} – ${_timeFmt.format(end)}'
        : '—';

    return ListTile(
      dense: true,
      title: Text('${operation.resourceCode} · ${operation.primaryLabel}'),
      subtitle: Text(
        [
          if (operation.productLine != null) operation.productLine!,
          timeLine,
          operation.statusLabel,
        ].join(' · '),
      ),
      trailing: operation.isDraftPlanned
          ? IconButton(
              icon: const Icon(Icons.info_outline, size: 20),
              tooltip: ApsGanttInfoCopy.draftPlannedTitle,
              onPressed: () => showApsGanttInfoDialog(
                context,
                title: ApsGanttInfoCopy.draftPlannedTitle,
                body: ApsGanttInfoCopy.draftPlannedBody,
              ),
            )
          : null,
      leading: Chip(
        label: Text(
          operation.statusLabel,
          style: theme.textTheme.labelSmall,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
