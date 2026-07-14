import 'package:flutter/material.dart';

import '../helpers/aps_gantt_info_copy.dart';

/// Dijalog potvrde plana (P4a) — bez slanja u MES.
Future<bool> showApsPlanConfirmDialog(
  BuildContext context, {
  required String scenarioLabel,
  required int operationCount,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Potvrdi plan'),
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
            Text(ApsGanttInfoCopy.planConfirmDialogBody),
            const SizedBox(height: 12),
            Text(
              'Operacija u rasporedu: $operationCount',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Potvrdi plan'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
