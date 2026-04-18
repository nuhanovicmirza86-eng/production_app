import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/branding/operonix_ai_branding.dart';
import '../services/production_ai_chat_service.dart';

class _ChatLine {
  final bool isUser;
  final String text;

  const _ChatLine({required this.isUser, required this.text});
}

/// Slobodni chatbot (Callable [aiChat]) — odvojeno od operativnog asistenta.
class ProductionAiChatScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionAiChatScreen({super.key, required this.companyData});

  @override
  State<ProductionAiChatScreen> createState() => _ProductionAiChatScreenState();
}

class _ProductionAiChatScreenState extends State<ProductionAiChatScreen> {
  final _svc = ProductionAiChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _lines = <_ChatLine>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty || _loading) return;

    setState(() {
      _lines.add(_ChatLine(isUser: true, text: t));
      _input.clear();
      _error = null;
      _loading = true;
    });
    _scrollToEnd();

    try {
      final reply = await _svc.sendMessage(t);
      if (!mounted) return;
      setState(() {
        _lines.add(_ChatLine(isUser: false, text: reply));
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message ?? e.code;
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

    return Scaffold(
      appBar: AppBar(
        title: Text('$kOperonixAiShortLabel — Chat (MES/OEE)'),
      ),
      body: Column(
        children: [
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
                    child: Text(
                      'Postavi pitanje o proizvodnji, OEE-u ili procesu.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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
                            maxWidth: MediaQuery.sizeOf(context).width * 0.86,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(line.text, style: TextStyle(color: fg)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
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
    );
  }
}
