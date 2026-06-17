import 'package:flutter/material.dart';

import '../finance_strings.dart';
import 'finance_assistant_context.dart';

class FinanceAssistantCatalog {
  FinanceAssistantCatalog._();

  static String screenTitleKey(String screenKey) {
    return 'finance_assistant_screen_$screenKey';
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
        return const ['finance_assistant_q_bank_next_step'];
    }
  }

  static String answerKeyForQuestion(String questionKey) {
    const map = <String, String>{
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
    return 'finance_assistant_intro_$screenKey';
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
