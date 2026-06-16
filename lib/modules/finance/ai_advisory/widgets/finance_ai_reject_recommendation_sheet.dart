import 'package:flutter/material.dart';

import '../../shared/finance_strings.dart';
import '../models/finance_ai_interaction_types.dart';

/// Sheet za obavezan razlog odbijanja preporuke.
class FinanceAiRejectRecommendationSheet extends StatefulWidget {
  const FinanceAiRejectRecommendationSheet({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(String reasonCode, String? otherText) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String reasonCode, String? otherText) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FinanceAiRejectRecommendationSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<FinanceAiRejectRecommendationSheet> createState() =>
      _FinanceAiRejectRecommendationSheetState();
}

class _FinanceAiRejectRecommendationSheetState
    extends State<FinanceAiRejectRecommendationSheet> {
  String? _selected;
  final _other = TextEditingController();
  bool _actionInProgress = false;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_selected == null) return false;
    if (_selected == FinanceAiRejectReasonCodes.other) {
      return _other.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _actionInProgress) return;
    final code = _selected!;
    setState(() => _actionInProgress = true);
    try {
      await widget.onSubmit(
        code,
        code == FinanceAiRejectReasonCodes.other ? _other.text.trim() : null,
      );
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
            FinanceStrings.t(context, 'advisory_reject_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...FinanceAiRejectReasonCodes.all.map((code) {
            return RadioListTile<String>(
              value: code,
              groupValue: _selected,
              onChanged: _actionInProgress
                  ? null
                  : (v) => setState(() => _selected = v),
              title: Text(
                FinanceStrings.t(context, 'advisory_reject_reason_$code'),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
          if (_selected == FinanceAiRejectReasonCodes.other)
            TextField(
              controller: _other,
              enabled: !_actionInProgress,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'advisory_reject_other'),
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (!_canSubmit || _actionInProgress) ? null : _submit,
            child: _actionInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(FinanceStrings.t(context, 'advisory_reject_confirm')),
          ),
        ],
      ),
    );
  }
}
