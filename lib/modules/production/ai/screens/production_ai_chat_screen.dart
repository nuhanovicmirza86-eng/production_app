import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/ai/production_ai_context_scope.dart';
import '../../../../core/branding/operonix_ai_branding.dart'
    show kOperonixAiChatScreenTitle;
import '../models/operonix_ai_entity_chat_binding.dart';
import '../services/firebase_callable_user_message.dart';
import '../services/production_ai_chat_service.dart';
import '../widgets/operonix_ai_assistant_feedback_bar.dart';
import '../widgets/operonix_ai_assistant_navigator.dart';

class _ChatLine {
  final bool isUser;
  final String text;
  /// Stabilan ključ za feedback stanje (jednom po AI odgovoru).
  final String? feedbackKey;

  const _ChatLine({
    required this.isUser,
    required this.text,
    this.feedbackKey,
  });
}

/// Slobodni razgovor s asistentom — odvojeno od operativnog pomoćnika za praćenje.
class ProductionAiChatScreen extends StatefulWidget {
  const ProductionAiChatScreen({
    super.key,
    required this.companyData,
    this.initialInputText,
    this.entityBinding,
    this.autoAskWithBinding = false,
  });

  final Map<String, dynamic> companyData;
  final String? initialInputText;

  /// AI-M2-G3 — context binding s detalj ekrana (F routing preko poslovnog ključa).
  final OperonixAiEntityChatBinding? entityBinding;

  /// Jednom pošalji starter pitanje s bindingom (bez ručnog tipkanja ID-a).
  final bool autoAskWithBinding;

  @override
  State<ProductionAiChatScreen> createState() => _ProductionAiChatScreenState();
}

class _ProductionAiChatScreenState extends State<ProductionAiChatScreen> {
  final _svc = ProductionAiChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _lines = <_ChatLine>[];
  int _feedbackSeq = 0;
  bool _loading = false;
  bool _autoAskStarted = false;
  String? _error;

  OperonixAiEntityChatBinding? get _binding {
    final b = widget.entityBinding;
    if (b == null || !b.isReady) return null;
    return b;
  }

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String? get _plantKey {
    final v = (widget.companyData['plantKey'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  String? get _plantDisplayName {
    final v = (widget.companyData['plantDisplayName'] ??
            widget.companyData['plantName'] ??
            '')
        .toString()
        .trim();
    return v.isEmpty ? null : v;
  }

  /// Rolling 30 dana — metapodatak za feedback (bez čuvanja sadržaja chata).
  ({String from, String to}) get _feedbackPeriod {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: 30));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return (from: fmt(from), to: fmt(to));
  }

  @override
  void initState() {
    super.initState();
    final pre = widget.initialInputText;
    if (pre != null && pre.trim().isNotEmpty) {
      _input.text = pre.trim();
    }
    if (widget.autoAskWithBinding && _binding != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoAskStarted) return;
        _autoAskStarted = true;
        _sendVisible(_binding!.starterQuestion);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty || _loading) return;
    _input.clear();
    await _sendVisible(t);
  }

  /// [visibleText] ide u bubble; Callable dobija routable poruku s bindingom.
  Future<void> _sendVisible(String visibleText) async {
    final visible = visibleText.trim();
    if (visible.isEmpty || _loading) return;

    final routable = _binding?.toRoutableMessage(visible) ?? visible;

    setState(() {
      _lines.add(_ChatLine(isUser: true, text: visible));
      _error = null;
      _loading = true;
    });
    _scrollToEnd();

    try {
      final prior = _lines.length > 1
          ? _lines.sublist(0, _lines.length - 1)
          : const <_ChatLine>[];
      final turns = <Map<String, String>>[
        for (final line in prior)
          if (line.text.trim().isNotEmpty)
            {
              'role': line.isUser ? 'user' : 'assistant',
              'text': line.text.trim(),
            },
      ];
      final clipped =
          turns.length > 20 ? turns.sublist(turns.length - 20) : turns;
      final reply = await _svc.sendMessage(
        routable,
        conversationTurns: clipped,
      );
      if (!mounted) return;
      final key = 'fb_${++_feedbackSeq}';
      setState(() {
        _lines.add(_ChatLine(isUser: false, text: reply, feedbackKey: key));
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = firebaseCallableUserMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final period = _feedbackPeriod;
    final binding = _binding;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(kOperonixAiChatScreenTitle),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardBottom),
        child: Column(
          children: [
            if (binding != null) OperonixAiEntityContextChip(binding: binding),
            if (_error != null)
              Material(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            Expanded(
              child: _lines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          binding != null
                              ? 'Asistent koristi kontekst: ${binding.displayLabel}. '
                                  'Možete dopisati pitanje ili pričekati odgovor na početni upit.'
                              : ProductionAiContextScope.hintForEmptyChat(
                                  widget.companyData,
                                ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _lines.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (_loading && i == _lines.length) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final line = _lines[i];
                        final bg = line.isUser
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest;
                        final fg = line.isUser
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface;
                        return Align(
                          alignment: line.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.sizeOf(context).width * 0.86,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.text, style: TextStyle(color: fg)),
                                if (!line.isUser &&
                                    line.feedbackKey != null &&
                                    _companyId.isNotEmpty)
                                  OperonixAiAssistantFeedbackBar(
                                    key: ValueKey(line.feedbackKey),
                                    companyId: _companyId,
                                    plantKey: _plantKey,
                                    plantDisplayName: _plantDisplayName,
                                    module: binding?.feedbackModule ??
                                        'production',
                                    contract:
                                        binding?.feedbackContract ?? 'aiChat',
                                    periodFrom: period.from,
                                    periodTo: period.to,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Poruka…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _loading ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
