import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'finance_assistant_context.dart';
import 'finance_assistant_panel.dart';

/// Jedna Finance sesija asistenta — dijeljena kroz hub i sve pod-ekrane modula.
class FinanceModuleAssistantSession {
  FinanceModuleAssistantSession._();

  static FinanceModuleAssistantSession? _active;

  static FinanceModuleAssistantSession? get currentOrNull => _active;

  static FinanceModuleAssistantSession ensure() {
    return _active ??= FinanceModuleAssistantSession._();
  }

  /// Završava sesiju kad korisnik napusti Finance modul (hub dispose).
  static void end() {
    final s = _active;
    _active = null;
    s?.contextNotifier.dispose();
  }

  String? conversationId;
  FinanceAssistantContext? activeContext;
  final ValueNotifier<FinanceAssistantContext?> contextNotifier =
      ValueNotifier<FinanceAssistantContext?>(null);

  void registerContext(FinanceAssistantContext context) {
    activeContext = context;
    contextNotifier.value = context;
  }

  Future<void> openAssistant(
    BuildContext context, {
    String? questionKey,
  }) async {
    final ctx = activeContext;
    if (ctx == null) return;

    final data = questionKey != null && questionKey.isNotEmpty
        ? ctx.copyWith(prefilledQuestionKey: questionKey)
        : ctx;

    await FinanceAssistantPanel.show(
      context,
      contextData: data,
      conversationId: conversationId,
      contextListenable: contextNotifier,
      onConversationIdChanged: (id) {
        conversationId = id;
      },
    );
  }

  void clearConversation() {
    conversationId = null;
  }
}
