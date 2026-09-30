import 'package:flutter/material.dart';

import '../operonix_ai_ux_copy.dart';

/// Shared Operonix Industrial chat composer: field + circular send on the right.
class OperonixAiChatComposer extends StatelessWidget {
  const OperonixAiChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.loading = false,
    this.hintText = kOperonixAiComposerHint,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final bool loading;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final canSend =
                enabled && !loading && controller.text.trim().isNotEmpty;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled && !loading,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSend) onSend();
                    },
                    decoration: InputDecoration(
                      hintText: hintText,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    tooltip: 'Pošalji',
                    onPressed: canSend ? onSend : null,
                    icon: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
