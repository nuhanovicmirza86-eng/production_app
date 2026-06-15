import 'package:flutter/material.dart';

import '../../shared/finance_strings.dart';

/// Sheet za feedback na advisory alert.
class FinanceAiFeedbackSheet extends StatefulWidget {
  const FinanceAiFeedbackSheet({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(String feedbackKind, String comment) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String feedbackKind, String comment) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FinanceAiFeedbackSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<FinanceAiFeedbackSheet> createState() => _FinanceAiFeedbackSheetState();
}

class _FinanceAiFeedbackSheetState extends State<FinanceAiFeedbackSheet> {
  String? _selectedKind;
  final _comment = TextEditingController();
  bool _actionInProgress = false;

  static const _kinds = <String>[
    'helpful',
    'not_helpful',
    'incorrect_facts',
    'wrong_severity',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final kind = _selectedKind;
    if (kind == null || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await widget.onSubmit(kind, _comment.text.trim());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FinanceStrings.t(context, 'advisory_feedback_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._kinds.map((kind) {
            return RadioListTile<String>(
              value: kind,
              groupValue: _selectedKind,
              onChanged: _actionInProgress
                  ? null
                  : (v) => setState(() => _selectedKind = v),
              title: Text(FinanceStrings.t(context, 'advisory_feedback_$kind')),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
          TextField(
            controller: _comment,
            enabled: !_actionInProgress,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'advisory_feedback_comment'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_selectedKind == null || _actionInProgress) ? null : _submit,
            child: _actionInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(FinanceStrings.t(context, 'advisory_feedback_submit')),
          ),
        ],
      ),
    );
  }
}

/// Sheet za obavezan razlog odbacivanja.
class FinanceAiDismissSheet extends StatefulWidget {
  const FinanceAiDismissSheet({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(String reason) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String reason) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FinanceAiDismissSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<FinanceAiDismissSheet> createState() => _FinanceAiDismissSheetState();
}

class _FinanceAiDismissSheetState extends State<FinanceAiDismissSheet> {
  String? _selected;
  final _other = TextEditingController();
  bool _actionInProgress = false;

  static const _reasonKeys = <String>[
    'risk_resolved',
    'known_circumstance',
    'incorrect_incomplete_data',
    'not_relevant',
    'other',
  ];

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? _buildReason() {
    if (_selected == null) return null;
    if (_selected == 'other') {
      final t = _other.text.trim();
      return t.isEmpty ? null : t;
    }
    return FinanceStrings.t(context, 'advisory_dismiss_reason_$_selected');
  }

  Future<void> _submit() async {
    final reason = _buildReason();
    if (reason == null || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await widget.onSubmit(reason);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FinanceStrings.t(context, 'advisory_dismiss_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._reasonKeys.map((key) {
            return RadioListTile<String>(
              value: key,
              groupValue: _selected,
              onChanged: _actionInProgress
                  ? null
                  : (v) => setState(() => _selected = v),
              title: Text(FinanceStrings.t(context, 'advisory_dismiss_reason_$key')),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
          if (_selected == 'other')
            TextField(
              controller: _other,
              enabled: !_actionInProgress,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'advisory_dismiss_other'),
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_buildReason() == null || _actionInProgress) ? null : _submit,
            child: _actionInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(FinanceStrings.t(context, 'advisory_dismiss_confirm')),
          ),
        ],
      ),
    );
  }
}
