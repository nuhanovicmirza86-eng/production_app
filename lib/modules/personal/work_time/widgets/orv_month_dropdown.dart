import 'package:flutter/material.dart';

/// Hrvatska imena mjeseci (1–12).
const _hrMjeseci = <String>[
  'Siječanj',
  'Veljača',
  'Ožujak',
  'Travanj',
  'Svibanj',
  'Lipanj',
  'Srpanj',
  'Kolovoz',
  'Rujan',
  'Listopad',
  'Studeni',
  'Prosinac',
];

/// Padajući izbor godine i mjeseca s hrvatskim nazivom mjeseca.
class OrvYearMonthToolbar extends StatelessWidget {
  const OrvYearMonthToolbar({
    super.key,
    required this.year,
    required this.month,
    required this.onChanged,
  });

  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.labelSmall;
    final years = <int>[year - 1, year, year + 1];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Godina', style: t),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: year,
          onChanged: (v) {
            if (v != null) {
              onChanged(v, month);
            }
          },
          items: [
            for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
          ],
        ),
        const SizedBox(width: 16),
        Text('Mjesec', style: t),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: month,
          onChanged: (v) {
            if (v != null) {
              onChanged(year, v);
            }
          },
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(
                value: m,
                child: Text(_hrMjeseci[m - 1]),
              ),
          ],
        ),
      ],
    );
  }
}
