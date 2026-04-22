import 'package:flutter/material.dart';

import '../planning_session_controller.dart';

/// Brzi filteri poola (klijentski); work centar / alat iz šifrarnika kasnije.
class PlanningFiltersBar extends StatelessWidget {
  const PlanningFiltersBar({super.key, required this.session});

  final PlanningSessionController session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final anyFilter = session.poolFilterHasMachine ||
        session.poolFilterDueRisk ||
        session.poolFilterNoMachine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Filteri poola', style: t.textTheme.titleSmall),
            const Spacer(),
            if (anyFilter)
              TextButton(
                onPressed: session.isLocked ? null : session.clearPoolFilters,
                child: const Text('Poništi filtere'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Samo s dodijeljenim strojem'),
              selected: session.poolFilterHasMachine,
              onSelected: session.isLocked ? null : session.setPoolFilterHasMachine,
            ),
            FilterChip(
              label: const Text('Rizik roka (< 3 d)'),
              selected: session.poolFilterDueRisk,
              onSelected: session.isLocked ? null : session.setPoolFilterDueRisk,
            ),
            FilterChip(
              label: const Text('Bez stroja'),
              selected: session.poolFilterNoMachine,
              onSelected: session.isLocked ? null : session.setPoolFilterNoMachine,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Work centar, alat, kupac u opsegu — master podaci i API u sljedećoj fazi.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
