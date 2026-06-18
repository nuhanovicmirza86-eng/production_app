import 'package:flutter/material.dart';

import '../../finance_integrations/utils/finance_load_error_presenter.dart';
import 'finance_assistant/finance_module_assistant_scope.dart';
import 'finance_assistant/finance_module_assistant_session.dart';
import 'finance_strings.dart';

/// Kratko objašnjenje pojedinačnog pojma preko info ikone (BA/EN: `help_*` ključevi).
class FinanceHelpInfoButton extends StatelessWidget {
  const FinanceHelpInfoButton({
    super.key,
    required this.titleKey,
    required this.bodyKey,
    this.iconSize = 22,
    this.visualDensity = VisualDensity.compact,
    this.padding = EdgeInsets.zero,
    this.assistantQuestionKey,
  });

  final String titleKey;
  final String bodyKey;
  final double iconSize;
  final VisualDensity visualDensity;
  final EdgeInsetsGeometry padding;
  final String? assistantQuestionKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: padding,
      visualDensity: visualDensity,
      tooltip: FinanceStrings.t(context, 'help_info_tooltip'),
      icon: Icon(
        Icons.info_outline,
        size: iconSize,
        color: Theme.of(context).colorScheme.outline,
      ),
      onPressed: () => _showHelp(context),
    );
  }

  Future<void> _showHelp(BuildContext context) async {
    await showFinanceTechnicalDetailDialog(
      context,
      title: FinanceStrings.t(context, titleKey),
      detail: FinanceStrings.t(context, bodyKey),
      closeLabel: FinanceStrings.t(context, 'help_info_close'),
      footer: assistantQuestionKey == null
          ? null
          : TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                final scope = FinanceModuleAssistantScope.maybeOf(context);
                if (scope != null) {
                  scope.openAssistant(questionKey: assistantQuestionKey);
                  return;
                }
                FinanceModuleAssistantSession.currentOrNull?.openAssistant(
                  context,
                  questionKey: assistantQuestionKey,
                );
              },
              child: Text(
                FinanceStrings.t(context, 'finance_assistant_ask_more'),
              ),
            ),
    );
  }
}

/// Naslov sekcije s info ikonom (ne otvara ekran pri tapu na ikonu).
class FinanceHelpSectionTitle extends StatelessWidget {
  const FinanceHelpSectionTitle({
    super.key,
    required this.title,
    required this.helpTitleKey,
    required this.helpBodyKey,
    this.style,
  });

  final String title;
  final String helpTitleKey;
  final String helpBodyKey;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: style ?? Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FinanceHelpInfoButton(
          titleKey: helpTitleKey,
          bodyKey: helpBodyKey,
        ),
      ],
    );
  }
}
