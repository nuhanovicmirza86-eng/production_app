import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../finance_error_mapper.dart';
import '../finance_strings.dart';
import '../finance_system_bottom_inset.dart';
import 'finance_assistant_catalog.dart';
import 'finance_assistant_context.dart';
import 'finance_ux_assistant_service.dart';

class _AssistantMessage {
  const _AssistantMessage({
    required this.isUser,
    required this.text,
    this.isError = false,
    this.retryQuestion,
    this.retryPrefilledKey,
  });

  final bool isUser;
  final String text;
  final bool isError;
  final String? retryQuestion;
  final String? retryPrefilledKey;
}

/// Kontekstualni Finance asistent — bočni panel (široki ekran) ili donji sheet.
class FinanceAssistantPanel extends StatefulWidget {
  const FinanceAssistantPanel({
    super.key,
    required this.contextData,
    this.scrollController,
    this.conversationId,
    this.onConversationIdChanged,
    this.contextListenable,
  });

  final FinanceAssistantContext contextData;
  final ScrollController? scrollController;
  final String? conversationId;
  final ValueChanged<String?>? onConversationIdChanged;
  final ValueListenable<FinanceAssistantContext?>? contextListenable;

  static Future<void> show(
    BuildContext context, {
    required FinanceAssistantContext contextData,
    String? conversationId,
    ValueChanged<String?>? onConversationIdChanged,
    ValueListenable<FinanceAssistantContext?>? contextListenable,
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
              child: FinanceAssistantPanel(
                contextData: contextData,
                conversationId: conversationId,
                onConversationIdChanged: onConversationIdChanged,
                contextListenable: contextListenable,
              ),
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
      useSafeArea: false,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 0.98,
        builder: (_, scrollController) => FinanceAssistantPanel(
          contextData: contextData,
          scrollController: scrollController,
          conversationId: conversationId,
          onConversationIdChanged: onConversationIdChanged,
          contextListenable: contextListenable,
        ),
      ),
    );
  }

  @override
  State<FinanceAssistantPanel> createState() => _FinanceAssistantPanelState();
}

class _FinanceAssistantPanelState extends State<FinanceAssistantPanel> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _messageScroll = ScrollController();
  final _service = FinanceUxAssistantService();
  final _messages = <_AssistantMessage>[];

  String? _conversationId;
  List<String> _suggestedQuestions = const [];
  bool _loading = false;
  bool _seeded = false;
  late FinanceAssistantContext _activeContext;

  String get _locale => FinanceStrings.isEnglish(context) ? 'en' : 'ba';

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _activeContext = widget.contextData;
    _inputFocus.addListener(_onInputFocusChanged);
    widget.contextListenable?.addListener(_onExternalContextChanged);
  }

  void _onExternalContextChanged() {
    final next = widget.contextListenable?.value;
    if (next == null) return;

    final screenChanged = next.screenKey != _activeContext.screenKey;
    final tabChanged = next.tabKey != _activeContext.tabKey;
    if (!screenChanged && !tabChanged) {
      setState(() => _activeContext = next);
      return;
    }

    final screenTitle = FinanceStrings.t(
      context,
      FinanceAssistantCatalog.screenTitleKey(next.screenKey),
    );
    final note = FinanceStrings.t(context, 'finance_assistant_context_changed')
        .replaceAll('{screen}', screenTitle);

    setState(() {
      _activeContext = next;
      _messages.add(_AssistantMessage(isUser: false, text: note));
      _suggestedQuestions = FinanceAssistantCatalog.suggestedQuestionLabels(
        context,
        next.screenKey,
      );
    });
    _scrollMessagesToEnd();
  }

  void _onInputFocusChanged() {
    if (!_inputFocus.hasFocus) return;
    _scrollMessagesToEnd();
  }

  void _scrollMessagesToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageScroll.hasClients) return;
      _messageScroll.animateTo(
        _messageScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    widget.contextListenable?.removeListener(_onExternalContextChanged);
    _inputFocus.removeListener(_onInputFocusChanged);
    _inputFocus.dispose();
    _inputCtrl.dispose();
    _messageScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefilled = widget.contextData.prefilledQuestionKey;
    if (prefilled != null && prefilled.isNotEmpty) {
      await _askBackend(
        question: FinanceStrings.t(context, prefilled),
        prefilledQuestionKey: prefilled,
      );
      return;
    }
    final introKey = FinanceAssistantCatalog.defaultQuestionKeyForScreen(
      _activeContext.screenKey,
    );
    await _askBackend(
      question: FinanceStrings.t(context, introKey),
      prefilledQuestionKey: introKey,
      showUserBubble: false,
    );
  }

  void _setConversationId(String? id) {
    _conversationId = id;
    widget.onConversationIdChanged?.call(id);
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _suggestedQuestions = const [];
      _loading = false;
      _seeded = false;
    });
    _setConversationId(null);
    _seeded = true;
    _bootstrap();
  }

  String _offlineFallbackAnswer({
    String? prefilledQuestionKey,
    required String question,
  }) {
    final prefix = FinanceStrings.t(context, 'finance_assistant_offline_fallback');
  String localBody(String answerKey) {
    final raw = FinanceStrings.t(context, answerKey);
    if (!raw.contains('{screen}')) return raw;
    final screenTitle = FinanceStrings.t(
      context,
      FinanceAssistantCatalog.screenTitleKey(_activeContext.screenKey),
    );
    return raw.replaceAll('{screen}', screenTitle);
  }

    if (prefilledQuestionKey != null && prefilledQuestionKey.isNotEmpty) {
      final answerKey =
          FinanceAssistantCatalog.answerKeyForQuestion(prefilledQuestionKey);
      return '$prefix\n\n${localBody(answerKey)}';
    }
    final qLower = question.toLowerCase();
    if (qLower.contains('na kojem se ekranu') ||
        qLower.contains('čemu služi ovaj tab') ||
        qLower.contains('where am i') ||
        qLower.contains('what is this tab')) {
      return '$prefix\n\n${localBody('finance_assistant_a_what_is_screen')}';
    }
    final intro = FinanceStrings.t(
      context,
      FinanceAssistantCatalog.introKey(_activeContext.screenKey),
    );
    return '$prefix\n\n$intro';
  }

  Future<void> _askBackend({
    required String question,
    String? prefilledQuestionKey,
    bool showUserBubble = true,
  }) async {
    final companyId = _activeContext.companyId.trim();
    if (companyId.isEmpty) {
      setState(() {
        if (showUserBubble) {
          _messages.add(_AssistantMessage(isUser: true, text: question));
        }
        _messages.add(
          _AssistantMessage(
            isUser: false,
            text: FinanceStrings.t(context, 'error_missing_company'),
            isError: true,
          ),
        );
      });
      return;
    }

    setState(() {
      _loading = true;
      if (showUserBubble) {
        _messages.add(_AssistantMessage(isUser: true, text: question));
      }
    });

    try {
      final response = await _service.ask(
        companyId: companyId,
        locale: _locale,
        question: question,
        contextData: _activeContext,
        conversationId: _conversationId,
        prefilledQuestionKey: prefilledQuestionKey,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messages.add(_AssistantMessage(isUser: false, text: response.answer));
        if (response.suggestedQuestions.isNotEmpty) {
          _suggestedQuestions = response.suggestedQuestions;
        }
      });
      _setConversationId(response.conversationId);
      _scrollMessagesToEnd();
    } catch (e) {
      if (!mounted) return;
      final fallback = _offlineFallbackAnswer(
      prefilledQuestionKey: prefilledQuestionKey,
      question: question,
    );
      setState(() {
        _loading = false;
        _messages.add(
          _AssistantMessage(
            isUser: false,
            text: '$fallback\n\n${FinanceErrorMapper.toMessage(e, context: context)}',
            isError: true,
            retryQuestion: question,
            retryPrefilledKey: prefilledQuestionKey,
          ),
        );
        _suggestedQuestions = FinanceAssistantCatalog.suggestedQuestionLabels(
          context,
          _activeContext.screenKey,
        );
      });
    }
  }

  void _askChip(String questionKey) {
    _askBackend(
      question: FinanceStrings.t(context, questionKey),
      prefilledQuestionKey: questionKey,
    );
  }

  void _askSuggested(String label) {
    _askBackend(question: label);
  }

  void _submitFreeText() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    _inputCtrl.clear();
    _askBackend(question: text);
  }

  void _retry(_AssistantMessage msg) {
    if (msg.retryQuestion == null) return;
    setState(() {
      _messages.remove(msg);
    });
    _askBackend(
      question: msg.retryQuestion!,
      prefilledQuestionKey: msg.retryPrefilledKey,
      showUserBubble: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _activeContext;
    final theme = Theme.of(context);
    final isMobileSheet = widget.scrollController != null;
    final screenTitle = FinanceStrings.t(
      context,
      FinanceAssistantCatalog.screenTitleKey(ctx.screenKey),
    );
    final suggestions = _suggestedQuestions.isNotEmpty
        ? _suggestedQuestions
        : FinanceAssistantCatalog.suggestedQuestionLabels(
            context,
            ctx.screenKey,
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
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
                  onPressed: _loading ? null : _resetConversation,
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
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _messageScroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + 1 + (_loading ? 1 : 0),
            itemBuilder: (context, index) {
              if (_loading && index == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final chipIndex = _messages.length + (_loading ? 1 : 0);
              if (index == chipIndex) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map(
                        (label) => ActionChip(
                          label: Text(label),
                          onPressed: _loading
                              ? null
                              : () {
                                  final key = FinanceAssistantCatalog
                                      .questionKeyForLabel(context, label);
                                  if (key != null) {
                                    _askChip(key);
                                  } else {
                                    _askSuggested(label);
                                  }
                                },
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
                        : msg.isError
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.text),
                      if (msg.isError && msg.retryQuestion != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loading ? null : () => _retry(msg),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(FinanceStrings.t(context, 'retry')),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: FinanceSystemBottomInset.anchoredBar(
            context: context,
            liftKeyboardOnParent: isMobileSheet,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  enabled: !_loading,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _loading ? null : (_) => _submitFreeText(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: FinanceStrings.t(
                      context,
                      'finance_assistant_input_hint',
                    ),
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loading ? null : _submitFreeText,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobileSheet) {
      return Padding(
        padding: FinanceSystemBottomInset.sheetLift(context),
        child: body,
      );
    }
    return body;
  }
}
