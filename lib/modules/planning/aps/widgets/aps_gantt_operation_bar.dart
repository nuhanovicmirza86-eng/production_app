import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../models/aps_schedule_operation_view.dart';

/// Bar jedne operacije na Gantt vremenskoj liniji (read-only).
class ApsGanttOperationBar extends StatelessWidget {
  const ApsGanttOperationBar({
    super.key,
    required this.operation,
    required this.left,
    required this.width,
    required this.height,
  });

  final ApsScheduleOperationView operation;
  final double left;
  final double width;
  final double height;

  static final _timeFmt = DateFormat('d.M. HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = operation.scheduledStart;
    final end = operation.scheduledEnd;
    final tooltip = StringBuffer()
      ..writeln(operation.primaryLabel);
    if (operation.productLine != null) {
      tooltip.writeln(operation.productLine);
    }
    tooltip.writeln('Resurs: ${operation.resourceCode}');
    if (start != null && end != null) {
      tooltip.writeln(
        '${_timeFmt.format(start)} – ${_timeFmt.format(end)}',
      );
    }
    tooltip.write('Status: ${operation.statusLabel}');

    final barColor = operation.isDraftPlanned
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.secondaryContainer;
    final onBar = operation.isDraftPlanned
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSecondaryContainer;

    return Positioned(
      left: left + 2,
      top: 4,
      width: width.clamp(24, double.infinity) - 4,
      height: height,
      child: Tooltip(
        message: tooltip.toString().trim(),
        child: Material(
          color: barColor,
          borderRadius: BorderRadius.circular(4),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => showApsGanttInfoDialog(
              context,
              title: operation.primaryLabel,
              body: _detailBody(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          operation.primaryLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: onBar,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (operation.productLine != null)
                          Text(
                            operation.productLine!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: onBar.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (operation.isDraftPlanned)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      icon: Icon(Icons.info_outline, size: 14, color: onBar),
                      tooltip: ApsGanttInfoCopy.draftPlannedTitle,
                      onPressed: () => showApsGanttInfoDialog(
                        context,
                        title: ApsGanttInfoCopy.draftPlannedTitle,
                        body: ApsGanttInfoCopy.draftPlannedBody,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _detailBody() {
    final buf = StringBuffer();
    buf.writeln('Resurs: ${operation.resourceCode}');
    if (operation.productLine != null) {
      buf.writeln('Proizvod: ${operation.productLine}');
    }
    final start = operation.scheduledStart;
    final end = operation.scheduledEnd;
    if (start != null && end != null) {
      buf.writeln(
        'Termin: ${_timeFmt.format(start)} – ${_timeFmt.format(end)}',
      );
    }
    if (operation.durationMinutes != null) {
      buf.writeln('Trajanje: ${operation.durationMinutes} min');
    }
    buf.write('${ApsGanttInfoCopy.draftPlannedTitle}: ${operation.statusLabel}. ');
    buf.write(ApsGanttInfoCopy.draftPlannedBody);
    return buf.toString().trim();
  }
}
