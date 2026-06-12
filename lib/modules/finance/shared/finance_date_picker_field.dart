import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'finance_strings.dart';

/// Datum isključivo preko calendar pickera (bez ručnog unosa).
class FinanceDatePickerField extends StatelessWidget {
  const FinanceDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(now.year + 5),
      helpText: label,
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd(Localizations.localeOf(context).languageCode);
    final text = value != null ? fmt.format(value!) : '—';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: InkWell(
        onTap: () => _pick(context),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            IconButton(
              tooltip: FinanceStrings.t(context, 'pick_date'),
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () => _pick(context),
            ),
          ],
        ),
      ),
    );
  }
}
