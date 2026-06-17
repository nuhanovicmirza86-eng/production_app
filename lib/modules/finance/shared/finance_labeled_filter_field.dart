import 'package:flutter/material.dart';

/// Naziv filter polja iznad kontrole — bez floating labela koji se reže u uskim Row polovinama.
class FinanceLabeledFilterField extends StatelessWidget {
  const FinanceLabeledFilterField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
        child,
      ],
    );
  }
}

/// Zajednička dekoracija filter dropdowna (bez labelText — koristi [FinanceLabeledFilterField]).
InputDecoration financeFilterInputDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
