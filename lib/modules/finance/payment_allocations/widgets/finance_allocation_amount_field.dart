import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/finance_strings.dart';

/// Validacija novčanih iznosa alokacije (2 decimale, pozitivan).
class FinanceAllocationAmountUtils {
  FinanceAllocationAmountUtils._();

  static const double tolerance = 0.005;

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  static String normalizeDecimalInput(String input) {
    var s = input.trim().replaceAll(' ', '');
    if (s.isEmpty) return s;
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && !hasDot) {
      return s.replaceAll(',', '.');
    }
    if (hasComma && hasDot) {
      return s.replaceAll(',', '');
    }
    return s;
  }

  static double? parsePositive(String input) {
    final cleaned = normalizeDecimalInput(input);
    if (cleaned.isEmpty) return null;
    final v = double.tryParse(cleaned);
    if (v == null || v <= 0) return null;
    return round2(v);
  }

  static bool hasAtMostTwoDecimals(String input) {
    final cleaned = normalizeDecimalInput(input);
    if (cleaned.isEmpty) return true;
    final parts = cleaned.split('.');
    if (parts.length == 2 && parts[1].length > 2) return false;
    return true;
  }
}

class FinanceAllocationAmountField extends StatelessWidget {
  const FinanceAllocationAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.currency,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? currency;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cur = (currency ?? '').trim().toUpperCase();
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: cur.isEmpty ? null : cur,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final raw = (value ?? '').trim();
        if (raw.isEmpty) {
          return FinanceStrings.t(context, 'allocation_amount_required');
        }
        if (!FinanceAllocationAmountUtils.hasAtMostTwoDecimals(raw)) {
          return FinanceStrings.t(context, 'allocation_amount_decimals');
        }
        final parsed = FinanceAllocationAmountUtils.parsePositive(raw);
        if (parsed == null) {
          return FinanceStrings.t(context, 'allocation_amount_invalid');
        }
        return null;
      },
      onChanged: onChanged,
      onEditingComplete: () => FocusScope.of(context).unfocus(),
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}
