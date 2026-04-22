import 'package:flutter/material.dart';

import '../planning_session_controller.dart';

/// Dijalog ako ima ručnih Gantt pomicanja, zatim [PlanningSessionController.generatePlan].
Future<void> reoptimizeFcsWithOptionalDialog(
  BuildContext context,
  PlanningSessionController session,
) async {
  if (session.isLocked) {
    return;
  }
  if (session.hasLocalGanttNudges) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ponovno uklopi (FCS)'),
          content: const Text(
            'Ručna pomicanja u Gantt-u bit će poništena. '
            'Motor će izgraditi novi nacrt od trenutno odabranih naloga i parametara (tab Nalozi). Nastaviti?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Uklopi'),
            ),
          ],
        );
      },
    );
    if (ok != true) {
      return;
    }
  }
  await session.generatePlan();
  if (!context.mounted) {
    return;
  }
  final err = session.errorMessage;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err)),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FCS: nacrt ponovno generiran.')),
    );
  }
}
