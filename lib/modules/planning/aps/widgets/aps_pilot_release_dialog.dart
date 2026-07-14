import 'package:flutter/material.dart';

import '../helpers/aps_gantt_info_copy.dart';
import '../widgets/aps_info_icon_button.dart';

/// Dijalog potvrde prije P4b pilot release-a (eksplicitni `pilotAcknowledgement`).
Future<bool> showApsPilotReleaseConfirmDialog(
  BuildContext context, {
  required String scenarioLabel,
}) async {
  var acknowledged = false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Pošalji u MES (pilot)')),
                ApsInfoIconButton(
                  tooltip: 'O pilot slanju u MES',
                  title: 'Pošalji u MES (pilot)',
                  body: ApsGanttInfoCopy.pilotReleaseDialogBody,
                  size: 18,
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scenarij: $scenarioLabel',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(ApsGanttInfoCopy.pilotReleaseDialogBody),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: acknowledged,
                    onChanged: (v) => setState(() => acknowledged = v == true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(ApsGanttInfoCopy.pilotReleaseCheckboxLabel),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: acknowledged ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Pošalji u MES (pilot)'),
              ),
            ],
          );
        },
      );
    },
  );
  return confirmed == true;
}
