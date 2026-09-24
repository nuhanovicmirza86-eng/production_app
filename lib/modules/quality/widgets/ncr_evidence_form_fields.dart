import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/ncr_rework_execution_choice_options.dart';

final kNcrEvidenceQtyFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

/// Numeričko polje evidencije — prazno po defaultu, select-all na fokus, Enter → sljedeće.
class NcrEvidenceQtyField extends StatefulWidget {
  const NcrEvidenceQtyField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onFieldSubmitted,
    this.validator,
    this.qtySumError = false,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final VoidCallback onFieldSubmitted;
  final String? Function(String?)? validator;
  final bool qtySumError;
  final TextInputAction textInputAction;

  @override
  State<NcrEvidenceQtyField> createState() => _NcrEvidenceQtyFieldState();
}

class _NcrEvidenceQtyFieldState extends State<NcrEvidenceQtyField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_selectAllOnFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_selectAllOnFocus);
    super.dispose();
  }

  void _selectAllOnFocus() {
    if (!widget.focusNode.hasFocus) return;
    final text = widget.controller.text;
    if (text.isEmpty) return;
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.number,
      textInputAction: widget.textInputAction,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      inputFormatters: kNcrEvidenceQtyFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: theme.textTheme.bodyMedium,
        suffixText: 'kom',
        suffixStyle: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        errorText: widget.qtySumError ? ' ' : null,
        errorStyle: widget.qtySumError
            ? const TextStyle(height: 0, fontSize: 0)
            : null,
      ),
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onFieldSubmitted(),
      onTap: () {
        final text = widget.controller.text;
        if (text.isNotEmpty) {
          widget.controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: text.length,
          );
        }
      },
    );
  }
}

/// Kontrolisani izbor (chip) + opcioni slobodan unos za „Drugo”.
class NcrEvidenceControlledChoiceField extends FormField<String> {
  NcrEvidenceControlledChoiceField({
    super.key,
    required String label,
    required List<String> options,
    required ValueChanged<String?> onSelectionChanged,
    TextEditingController? otherController,
    FocusNode? otherFocusNode,
    String? initialValue,
    String? Function(String?)? validator,
    String otherLabel = ncrReworkChoiceOther,
  }) : super(
          initialValue: initialValue,
          validator: validator,
          builder: (state) {
            final theme = Theme.of(state.context);
            final selected = state.value;
            final showOther =
                otherController != null && selected == otherLabel;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: label,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    errorText: state.errorText,
                    contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in options)
                        ChoiceChip(
                          label: Text(option),
                          selected: selected == option,
                          showCheckmark: true,
                          onSelected: (v) {
                            if (!v) return;
                            state.didChange(option);
                            onSelectionChanged(option);
                            state.validate();
                          },
                        ),
                    ],
                  ),
                ),
                if (showOther) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: otherController,
                    focusNode: otherFocusNode,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Opiši — $otherLabel',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => state.validate(),
                  ),
                ],
              ],
            );
          },
        );
}

/// Kartica sekcije forme evidencije.
class NcrEvidenceSectionCard extends StatelessWidget {
  const NcrEvidenceSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon = Icons.fact_check_outlined,
  });

  final String title;
  final List<Widget> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
