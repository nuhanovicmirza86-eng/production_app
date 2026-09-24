import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/firebase_callable_user_message.dart';
import '../services/production_ai_assistant_feedback_service.dart';

/// Premium feedback red ispod AI odgovora (AI-M2-G2).
///
/// Pozitivno: odmah submit. Negativno: kontrolisan razlog + opcionalni komentar.
class OperonixAiAssistantFeedbackBar extends StatefulWidget {
  const OperonixAiAssistantFeedbackBar({
    super.key,
    required this.companyId,
    this.plantKey,
    this.plantDisplayName,
    this.module = 'production',
    this.contract = 'aiChat',
    this.periodFrom,
    this.periodTo,
    this.feedbackService,
    this.onSubmitted,
  });

  final String companyId;
  final String? plantKey;
  final String? plantDisplayName;
  final String module;
  final String contract;
  final String? periodFrom;
  final String? periodTo;
  final ProductionAiAssistantFeedbackService? feedbackService;
  final VoidCallback? onSubmitted;

  @override
  State<OperonixAiAssistantFeedbackBar> createState() =>
      _OperonixAiAssistantFeedbackBarState();
}

class _NegativeReasonOption {
  const _NegativeReasonOption({
    required this.reasonCode,
    required this.label,
  });

  final String reasonCode;
  final String label;
}

const List<_NegativeReasonOption> _kNegativeReasons = [
  _NegativeReasonOption(
    reasonCode: ProductionAiAssistantFeedbackService.reasonNotActionable,
    label: 'Odgovor nije dovoljno konkretan',
  ),
  _NegativeReasonOption(
    reasonCode: ProductionAiAssistantFeedbackService.reasonIncomplete,
    label: 'Nedostaju podaci iz sistema',
  ),
  _NegativeReasonOption(
    reasonCode: ProductionAiAssistantFeedbackService.reasonWrongFacts,
    label: 'Pogrešan zaključak',
  ),
  _NegativeReasonOption(
    reasonCode: ProductionAiAssistantFeedbackService.reasonNotActionable,
    label: 'Previše općenito',
  ),
  _NegativeReasonOption(
    reasonCode: ProductionAiAssistantFeedbackService.reasonOther,
    label: 'Teško razumljivo',
  ),
  _NegativeReasonOption(
    reasonCode: ProductionAiAssistantFeedbackService.reasonOther,
    label: 'Drugo',
  ),
];

class _OperonixAiAssistantFeedbackBarState
    extends State<OperonixAiAssistantFeedbackBar> {
  late final ProductionAiAssistantFeedbackService _svc;
  bool _submitting = false;
  bool _submitted = false;
  String? _statusNote;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _svc = widget.feedbackService ?? ProductionAiAssistantFeedbackService();
  }

  Future<void> _submitPositive() async {
    if (_submitted || _submitting) return;
    await _send(
      rating: ProductionAiAssistantFeedbackService.ratingHelpful,
      reasonCode: ProductionAiAssistantFeedbackService.reasonClearAndUseful,
    );
  }

  Future<void> _openNegativeSheet() async {
    if (_submitted || _submitting) return;

    final result = await showModalBottomSheet<_NegativeFeedbackDraft>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) {
        return PopScope(
          canPop: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: const _NegativeFeedbackSheet(),
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    await _send(
      rating: ProductionAiAssistantFeedbackService.ratingNotHelpful,
      reasonCode: result.reasonCode,
      comment: result.comment,
    );
  }

  Future<void> _send({
    required String rating,
    required String reasonCode,
    String? comment,
  }) async {
    if (_submitted || _submitting) return;
    setState(() {
      _submitting = true;
      _statusError = null;
      _statusNote = null;
    });

    try {
      final note = await _svc.submit(
        companyId: widget.companyId,
        rating: rating,
        reasonCode: reasonCode,
        comment: comment,
        module: widget.module,
        contract: widget.contract,
        plantKey: widget.plantKey,
        plantDisplayName: widget.plantDisplayName,
        periodFrom: widget.periodFrom,
        periodTo: widget.periodTo,
      );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
        _statusNote = note;
      });
      widget.onSubmitted?.call();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusError = firebaseCallableUserMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusError =
            'Povratnu informaciju nije bilo moguće poslati. Pokušajte ponovo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          _statusNote ??
              ProductionAiAssistantFeedbackService.confirmationNote,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Da li je odgovor bio koristan?',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: _submitting ? null : _submitPositive,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Korisno'),
              ),
              OutlinedButton(
                onPressed: _submitting ? null : _openNegativeSheet,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Nije korisno'),
              ),
              if (_submitting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_statusError != null) ...[
            const SizedBox(height: 6),
            Text(
              _statusError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NegativeFeedbackDraft {
  const _NegativeFeedbackDraft({
    required this.reasonCode,
    this.comment,
  });

  final String reasonCode;
  final String? comment;
}

class _NegativeFeedbackSheet extends StatefulWidget {
  const _NegativeFeedbackSheet();

  @override
  State<_NegativeFeedbackSheet> createState() => _NegativeFeedbackSheetState();
}

class _NegativeFeedbackSheetState extends State<_NegativeFeedbackSheet> {
  int? _selectedIndex;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _selectedIndex != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Šta nije bilo dobro?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _kNegativeReasons.length; i++)
                    RadioListTile<int>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: i,
                      groupValue: _selectedIndex,
                      title: Text(
                        _kNegativeReasons[i].label,
                        style: theme.textTheme.bodyMedium,
                      ),
                      onChanged: (v) => setState(() => _selectedIndex = v),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Komentar (opcionalno)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Odustani'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: !canSend
                      ? null
                      : () {
                          final opt = _kNegativeReasons[_selectedIndex!];
                          Navigator.of(context).pop(
                            _NegativeFeedbackDraft(
                              reasonCode: opt.reasonCode,
                              comment: _comment.text.trim(),
                            ),
                          );
                        },
                  child: const Text('Pošalji povratnu informaciju'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
