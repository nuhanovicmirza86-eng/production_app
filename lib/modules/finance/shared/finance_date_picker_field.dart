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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          softWrap: true,
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
