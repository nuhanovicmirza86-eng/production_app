import 'package:flutter/material.dart';

import 'finance_strings.dart';

/// Dijalog za unos razloga — controller se dispose-a u [State.dispose].
Future<String?> showFinanceReasonPromptDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _FinanceReasonPromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _FinanceReasonPromptDialog extends StatefulWidget {
  const _FinanceReasonPromptDialog({
    required this.title,
    required this.hint,
    this.confirmLabel,
  });

  final String title;
  final String hint;
  final String? confirmLabel;

  @override
  State<_FinanceReasonPromptDialog> createState() =>
      _FinanceReasonPromptDialogState();
}

class _FinanceReasonPromptDialogState extends State<_FinanceReasonPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final confirm = widget.confirmLabel ?? FinanceStrings.t(context, 'save');

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(FinanceStrings.t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(confirm),
        ),
      ],
    );
  }
}
