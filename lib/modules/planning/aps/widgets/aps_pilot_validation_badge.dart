import 'package:flutter/material.dart';

import '../helpers/aps_gantt_info_copy.dart';
import 'aps_info_icon_button.dart';

/// Vidljiva oznaka pilot validacije (P4-32) — nije kozmetika, štiti proces.
class ApsPilotValidationBadge extends StatelessWidget {
  const ApsPilotValidationBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = ApsGanttInfoCopy.pilotValidationBadge;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            avatar: Icon(Icons.science_outlined, size: 16, color: cs.onSecondaryContainer),
            label: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            ),
            backgroundColor: cs.secondaryContainer,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          ApsInfoIconButton(
            tooltip: 'O pilot validaciji',
            title: ApsGanttInfoCopy.pilotValidationBadge,
            body: ApsGanttInfoCopy.pilotValidationInfoBody,
            size: 16,
          ),
        ],
      );
    }

    return Material(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.science_outlined, color: cs.onSecondaryContainer, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
            ApsInfoIconButton(
              tooltip: 'O pilot validaciji',
              title: ApsGanttInfoCopy.pilotValidationBadge,
              body: ApsGanttInfoCopy.pilotValidationInfoBody,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
