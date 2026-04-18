import 'dart:async' show unawaited;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/branding/operonix_ai_branding.dart';
import '../models/production_ai_chat_message.dart';
import '../services/production_ai_chat_persistence.dart';
import '../services/production_tracking_assistant_client_service.dart';

/// Operativni asistent nad praćenjem proizvodnje (Callable [productionTrackingAssistant]).
class ProductionTrackingAssistantScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionTrackingAssistantScreen({
    super.key,
    required this.companyData,
  });

  @override
  State<ProductionTrackingAssistantScreen> createState() =>
      _ProductionTrackingAssistantScreenState();
}

class _ProductionTrackingAssistantScreenState
    extends State<ProductionTrackingAssistantScreen>
    with WidgetsBindingObserver {
  final _svc = ProductionTrackingAssistantClientService();
  final _prompt = TextEditingController();
  final _scroll = ScrollController();
  final List<ProductionAiChatMessage> _turns = [];
  bool _loading = false;
  bool _restored = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prompt.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resyncFromCloud());
    }
  }

  Future<void> _resyncFromCloud() async {
    if (_loading) return;
    final list = await ProductionAiChatPersistence.reloadFromCloud(
      _companyId,
      _plantKey,
    );
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(list);
    });
    _scrollToEnd();
  }

  Future<void> _restore() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      if (mounted) setState(() => _restored = true);
      return;
    }
    final list = await ProductionAiChatPersistence.load(_companyId, _plantKey);
    if (!mounted) return;
    setState(() {
      _turns
        ..clear()
        ..addAll(list);
      _restored = true;
    });
    _scrollToEnd();
  }

  void _schedulePersist() {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    unawaited(ProductionAiChatPersistence.save(_companyId, _plantKey, List.of(_turns)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearThread() async {
    if (_loading) return;
    setState(_turns.clear);
    await ProductionAiChatPersistence.clear(_companyId, _plantKey);
  }

  Future<void> _ask() async {
    final q = _prompt.text.trim();
    if (q.isEmpty || _loading || !_restored) return;

    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() {
        _turns.add(
          const ProductionAiChatMessage.error('Nedostaje companyId ili plantKey.'),
        );
      });
      _schedulePersist();
      _scrollToEnd();
      return;
    }

    setState(() {
      _turns.add(ProductionAiChatMessage.user(q));
      if (_turns.length > 40) {
        _turns.removeRange(0, _turns.length - 40);
      }
      _loading = true;
    });
    _schedulePersist();
    _prompt.clear();
    _scrollToEnd();

    try {
      final text = await _svc.ask(
        companyId: _companyId,
        plantKey: _plantKey,
        prompt: q,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(ProductionAiChatMessage.assistant(text));
        if (_turns.length > 40) {
          _turns.removeRange(0, _turns.length - 40);
        }
        _loading = false;
      });
      _schedulePersist();
      _scrollToEnd();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.add(ProductionAiChatMessage.error(e.message ?? e.code));
        _loading = false;
      });
      _schedulePersist();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.add(ProductionAiChatMessage.error(e.toString()));
        _loading = false;
      });
      _schedulePersist();
      _scrollToEnd();
    }
  }

  MarkdownStyleSheet _md(ThemeData theme) {
    final base = theme.textTheme.bodyMedium?.copyWith(height: 1.38);
    return MarkdownStyleSheet(
      p: base,
      strong: base?.copyWith(fontWeight: FontWeight.w700),
      h1: base?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      h2: base?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      h3: base?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      code: base?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final scheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(kOperonixAiOperationalAssistantTitle),
        actions: [
          if (_turns.isNotEmpty)
            TextButton(
              onPressed: _loading || !_restored ? null : _clearThread,
              child: const Text('Očisti razgovor'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Kontekst za vaš pogon učitava podatke iz sustava. '
              'Povijest razgovora sinkronizira se u oblaku (isti korisnik i pogon na svim uređajima); '
              'lokalno se drži kopija za offline.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: !_restored
                ? const Center(child: CircularProgressIndicator())
                : _turns.isEmpty && !_loading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Postavite pitanje ispod. Stariji razgovor učitava se automatski ako je spremljen.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _turns.length + (_loading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _turns.length && _loading) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Asistent priprema odgovor…',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final m = _turns[i];
                          final maxW = MediaQuery.sizeOf(context).width * 0.88;
                          Widget bubble;
                          if (m.isUser) {
                            bubble = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer.withValues(
                                  alpha: 0.85,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                              child: SelectableText(
                                m.text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            );
                          } else if (m.isError) {
                            bubble = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer.withValues(
                                  alpha: 0.5,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(4),
                                ),
                                border: Border.all(
                                  color: scheme.error.withValues(alpha: 0.4),
                                ),
                              ),
                              child: SelectableText(
                                m.text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            );
                          } else {
                            bubble = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.85,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: MarkdownBody(
                                data: m.text,
                                selectable: true,
                                styleSheet: _md(theme),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: m.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxW),
                                child: bubble,
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          Material(
            color: scheme.surface,
            elevation: 6,
            shadowColor: Colors.black26,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _prompt,
                    enabled: !_loading && _restored,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Pitanje',
                      hintText: 'Npr. Koji je omjer škarta ovaj tjedan?',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onSubmitted: (_) => _ask(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: (_loading || !_restored) ? null : _ask,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_outlined),
                    label: Text(_loading ? 'Odgovor…' : 'Pošalji'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
