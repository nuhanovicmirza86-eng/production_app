import 'package:flutter/material.dart';

/// Placeholder za napredne filtere (work centar, alat, rok, …) — ista sadržajna poruka kao prije.
class PlanningFiltersBar extends StatelessWidget {
  const PlanningFiltersBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Filteri (placeholder)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        const Text(
          'Work centar, grupa strojeva, alat, proizvođač, kupac, opseg roka, samo mogući / rizik — '
          'povezivanje s master podacima u sljedećim iteracijama.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
