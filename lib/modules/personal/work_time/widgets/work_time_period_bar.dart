import 'package:flutter/material.dart';

/// Godina + mjesec (isti obrazac na Pregledu, Mjesečnom, Exportu u demu).
class WorkTimePeriodBar extends StatelessWidget {
  const WorkTimePeriodBar({
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
    final t = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text('Period', style: t.textTheme.labelLarge),
        _yearField(),
        _monthField(),
        Text(
          _monthName(month),
          style: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _monthName(int m) {
    const n = <String>[
      '', 'Siječanj', 'Veljača', 'Ožujak', 'Travanj', 'Svibanj', 'Lipanj',
      'Srpanj', 'Kolovoz', 'Rujan', 'Listopad', 'Studeni', 'Prosinac',
    ];
    if (m < 1 || m > 12) return '';
    return n[m];
  }

  Widget _yearField() {
    return DropdownButton<int>(
      value: year,
      items: [for (var y = year - 1; y <= year + 1; y++) y]
          .map(
            (y) => DropdownMenuItem(value: y, child: Text('$y')),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v, month);
      },
    );
  }

  Widget _monthField() {
    return DropdownButton<int>(
      value: month,
      items: List.generate(
        12,
        (i) {
          final m = i + 1;
          return DropdownMenuItem(
            value: m,
            child: Text(m.toString().padLeft(2, '0')),
          );
        },
      ),
      onChanged: (v) {
        if (v != null) onChanged(year, v);
      },
    );
  }
}
