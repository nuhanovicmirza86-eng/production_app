import 'package:flutter/material.dart';

/// Podsjetnik: obračun se gradi u koracima, ne iz pojedinačnih prijava bez provjere.
class WorkTimeDataLayersHint extends StatelessWidget {
  const WorkTimeDataLayersHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kako se podaci primjenjuju',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _row(
              context,
              1,
              'Prijave',
              'Ulazi i izlazi s termina, kioska ili sata.',
            ),
            const Icon(Icons.arrow_downward, size: 16),
            _row(
              context,
              2,
              'Dnevno',
              'Obračun i kontrola unutar dana (smjena, pauze, odstupanja).',
            ),
            const Icon(Icons.arrow_downward, size: 16),
            _row(
              context,
              3,
              'Mjesečno',
              'Fond, kategorije sati i zatvaranje mjeseca za isplatu.',
            ),
            const SizedBox(height: 6),
            Text(
              'Izbjegavajte isplatu plaće isključivo iz neprovjerenih zapisnika prijava '
              '— uvijek dnevni i mjesecni zatvarajući korak.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int step,
    String title,
    String note,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          child: Text('$step', style: const TextStyle(fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge,
              ),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
