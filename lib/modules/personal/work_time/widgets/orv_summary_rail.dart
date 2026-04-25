import 'package:flutter/material.dart';

/// Sažetak za mjesec i dan + tipične radnje ORV-a (gumbi se povezuju kad backend bude spreman).
class OrvSummaryRail extends StatelessWidget {
  const OrvSummaryRail({
    super.key,
    required this.canCalculate,
    this.monthlyWarning,
  });

  final bool canCalculate;
  final String? monthlyWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Suma za mjesec', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (!canCalculate)
              Text(
                monthlyWarning ?? 'Obračun nije moguć. Ispravite podatke u mreži ili korekcijama.',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                'Mjesec je u skladu za obračun.',
                style: theme.textTheme.bodyMedium,
              ),
            const Divider(height: 20),
            Text('Za dan', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(theme, 'Treba rad', '08:00 h'),
            _row(theme, 'Rad', '08:00 h'),
            _row(theme, 'Produženo', '00:00 h'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              children: [
                _btn('Potvrdi plan smjene'),
                _btn('Unos prema planu'),
                _btn('Posebna pravila'),
                _btn('Bolovanje od–do'),
                _btn('Početak/kraj RO'),
                _btn('Godišnji od–do'),
                FilledButton.tonal(
                  onPressed: null,
                  child: const Text('Osvježi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: theme.textTheme.bodySmall),
          Text(b, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _btn(String t) {
    return OutlinedButton(
      onPressed: null,
      child: Text(t, textAlign: TextAlign.center),
    );
  }
}
