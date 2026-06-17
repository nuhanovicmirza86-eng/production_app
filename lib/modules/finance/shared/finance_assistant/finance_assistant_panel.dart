import 'package:flutter/material.dart';

import '../finance_strings.dart';
import 'finance_assistant_catalog.dart';
import 'finance_assistant_context.dart';

class _AssistantMessage {
  const _AssistantMessage({
    required this.isUser,
    required this.text,
  });

  final bool isUser;
  final String text;
}

/// Kontekstualni Finance asistent — bočni panel (široki ekran) ili donji sheet.
class FinanceAssistantPanel extends StatefulWidget {
  const FinanceAssistantPanel({
    super.key,
    required this.contextData,
    this.scrollController,
  });

  final FinanceAssistantContext contextData;
  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required FinanceAssistantContext contextData,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 720) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: FinanceStrings.t(context, 'finance_assistant_title'),
        pageBuilder: (ctx, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 8,
            child: SizedBox(
              width: 400,
              height: MediaQuery.sizeOf(ctx).height,
              child: FinanceAssistantPanel(contextData: contextData),
            ),
          ),
        ),
        transitionBuilder: (ctx, anim, _, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return SlideTransition(position: offset, child: child);
        },
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 0.98,
        builder: (_, scrollController) => FinanceAssistantPanel(
          contextData: contextData,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<FinanceAssistantPanel> createState() => _FinanceAssistantPanelState();
}

class _FinanceAssistantPanelState extends State<FinanceAssistantPanel> {
  final _inputCtrl = TextEditingController();
  final _messages = <_AssistantMessage>[];
  bool _seeded = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _seedConversation();
  }

  void _seedConversation() {
    final ctx = widget.contextData;
    final intro = FinanceStrings.t(context, FinanceAssistantCatalog.introKey(ctx.screenKey));
    final note = FinanceAssistantCatalog.contextualNote(context, ctx);
    final body = note.isEmpty ? intro : '$intro\n\n$note';
    setState(() {
      _messages.add(_AssistantMessage(isUser: false, text: body));
    });
    final prefilled = ctx.prefilledQuestionKey;
    if (prefilled != null && prefilled.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ask(prefilled);
      });
    }
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _seeded = false;
    });
    _seeded = true;
    _seedConversation();
  }

  void _ask(String questionKey) {
    final q = FinanceStrings.t(context, questionKey);
    final a = FinanceStrings.t(
      context,
      FinanceAssistantCatalog.answerKeyForQuestion(questionKey),
    );
    setState(() {
      _messages.add(_AssistantMessage(isUser: true, text: q));
      _messages.add(_AssistantMessage(isUser: false, text: a));
    });
  }

  void _submitFreeText() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() {
      _messages.add(_AssistantMessage(isUser: true, text: text));
      _messages.add(
        _AssistantMessage(
          isUser: false,
          text: FinanceStrings.t(context, 'finance_assistant_a_free_text'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.contextData;
    final theme = Theme.of(context);
    final screenTitle = FinanceStrings.t(
      context,
      FinanceAssistantCatalog.screenTitleKey(ctx.screenKey),
    );
    final suggestions = FinanceAssistantCatalog.suggestedQuestionKeys(ctx.screenKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FinanceStrings.t(context, 'finance_assistant_title'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FinanceStrings.t(context, 'finance_assistant_current_screen')
                          .replaceAll('{screen}', screenTitle),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: FinanceStrings.t(context, 'finance_assistant_new_chat'),
                onPressed: _resetConversation,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: FinanceStrings.t(context, 'help_info_close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + 1,
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map(
                        (key) => ActionChip(
                          label: Text(FinanceStrings.t(context, key)),
                          onPressed: () => _ask(key),
                        ),
                      )
                      .toList(),
                );
              }
              final msg = _messages[index];
              return Align(
                alignment:
                    msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg.text),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitFreeText(),
                  decoration: InputDecoration(
                    hintText: FinanceStrings.t(
                      context,
                      'finance_assistant_input_hint',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _submitFreeText,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
