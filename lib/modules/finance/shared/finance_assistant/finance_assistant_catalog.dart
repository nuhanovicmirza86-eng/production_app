import 'package:flutter/material.dart';

import '../finance_strings.dart';
import 'finance_assistant_context.dart';

class FinanceAssistantCatalog {
  FinanceAssistantCatalog._();

  static String screenTitleKey(String screenKey) {
    return 'finance_assistant_screen_$screenKey';
  }

  static String defaultQuestionKeyForScreen(String screenKey) {
    switch (screenKey) {
      case FinanceAssistantScreens.bankMatchConfirm:
        return 'finance_assistant_q_bank_confirm_effect';
      case FinanceAssistantScreens.bankMatchConfirmationDetail:
        return 'finance_assistant_q_bank_cancel_effect';
      case FinanceAssistantScreens.bankMatchSuggestionDetail:
        return 'finance_assistant_q_bank_why_suggested';
      case FinanceAssistantScreens.bankStatementDetail:
        return 'finance_assistant_q_bank_list_purpose';
      case FinanceAssistantScreens.bankStatementsList:
        return 'finance_assistant_q_bank_list_purpose';
      default:
        return 'finance_assistant_q_what_is_screen';
    }
  }

  static List<String> suggestedQuestionKeys(String screenKey) {
    switch (screenKey) {
      case FinanceAssistantScreens.bankStatementsList:
        return const [
          'finance_assistant_q_bank_list_purpose',
          'finance_assistant_q_bank_generate',
          'finance_assistant_q_bank_next_step',
        ];
      case FinanceAssistantScreens.bankStatementDetail:
      case FinanceAssistantScreens.bankMatchSuggestionDetail:
        return const [
          'finance_assistant_q_bank_list_purpose',
          'finance_assistant_q_bank_generate',
          'finance_assistant_q_bank_why_suggested',
          'finance_assistant_q_bank_confirm_effect',
          'finance_assistant_q_bank_next_step',
        ];
      case FinanceAssistantScreens.bankMatchConfirm:
        return const [
          'finance_assistant_q_bank_confirm_effect',
          'finance_assistant_q_bank_next_step',
        ];
      case FinanceAssistantScreens.bankMatchConfirmationDetail:
        return const [
          'finance_assistant_q_bank_cancel_effect',
          'finance_assistant_q_bank_next_step',
        ];
      default:
        return const [
          'finance_assistant_q_what_is_screen',
          'finance_assistant_q_next_step',
        ];
    }
  }

  static List<String> suggestedQuestionLabels(
    BuildContext context,
    String screenKey,
  ) {
    return suggestedQuestionKeys(screenKey)
        .map((k) => FinanceStrings.t(context, k))
        .toList();
  }

  static String? questionKeyForLabel(BuildContext context, String label) {
    for (final key in _allQuestionKeys) {
      if (FinanceStrings.t(context, key) == label) return key;
    }
    return null;
  }

  static const _allQuestionKeys = <String>[
    'finance_assistant_q_what_is_screen',
    'finance_assistant_q_next_step',
    'finance_assistant_q_bank_list_purpose',
    'finance_assistant_q_bank_generate',
    'finance_assistant_q_bank_why_suggested',
    'finance_assistant_q_bank_confirm_effect',
    'finance_assistant_q_bank_cancel_effect',
    'finance_assistant_q_bank_next_step',
  ];

  static String answerKeyForQuestion(String questionKey) {
    const map = <String, String>{
      'finance_assistant_q_what_is_screen': 'finance_assistant_a_what_is_screen',
      'finance_assistant_q_next_step': 'finance_assistant_a_next_step',
      'finance_assistant_q_bank_list_purpose':
          'finance_assistant_a_bank_list_purpose',
      'finance_assistant_q_bank_generate':
          'finance_assistant_a_bank_generate',
      'finance_assistant_q_bank_why_suggested':
          'finance_assistant_a_bank_why_suggested',
      'finance_assistant_q_bank_confirm_effect':
          'finance_assistant_a_bank_confirm_effect',
      'finance_assistant_q_bank_cancel_effect':
          'finance_assistant_a_bank_cancel_effect',
      'finance_assistant_q_bank_next_step':
          'finance_assistant_a_bank_next_step',
    };
    return map[questionKey] ?? 'finance_assistant_a_default';
  }

  static String introKey(String screenKey) {
    switch (screenKey) {
      case FinanceAssistantScreens.bankStatementsList:
        return 'finance_assistant_intro_bank_statements_list';
      case FinanceAssistantScreens.bankStatementDetail:
        return 'finance_assistant_intro_bank_statement_detail';
      case FinanceAssistantScreens.bankMatchConfirm:
        return 'finance_assistant_intro_bank_match_confirm';
      case FinanceAssistantScreens.bankMatchConfirmationDetail:
        return 'finance_assistant_intro_bank_match_confirmation_detail';
      case FinanceAssistantScreens.bankMatchSuggestionDetail:
        return 'finance_assistant_intro_bank_match_suggestion_detail';
      default:
        return 'finance_assistant_intro_default';
    }
  }

  static String contextualNote(
    BuildContext context,
    FinanceAssistantContext ctx,
  ) {
    final parts = <String>[];
    if (ctx.entityStatus != null && ctx.entityStatus!.isNotEmpty) {
      parts.add(
        FinanceStrings.t(context, 'finance_assistant_ctx_status')
            .replaceAll('{status}', ctx.entityStatus!),
      );
    }
    if (ctx.availableActions.isNotEmpty) {
      parts.add(
        FinanceStrings.t(context, 'finance_assistant_ctx_actions')
            .replaceAll('{actions}', ctx.availableActions.join(' · ')),
      );
    }
    return parts.join('\n');
  }
}
