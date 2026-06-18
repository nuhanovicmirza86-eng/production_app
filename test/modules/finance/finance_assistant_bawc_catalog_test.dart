import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_catalog.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_context.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('bs'),
      home: child,
    );
  }

  testWidgets('M2-M3: BAWC predložena pitanja u katalogu', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    final context = tester.element(find.byType(SizedBox));

    final keys = FinanceAssistantCatalog.suggestedQuestionKeys(
      FinanceAssistantScreens.budgetVsActual,
    );
    expect(keys, contains('finance_assistant_q_bawc_outflow_above_plan'));
    expect(keys, contains('finance_assistant_q_wc_dio_ccc_unavailable'));
    expect(keys.length, 8);

    for (final key in keys) {
      final label = FinanceStrings.t(context, key);
      expect(label.isNotEmpty, true);
      expect(
        FinanceAssistantCatalog.questionKeyForLabel(context, label),
        key,
      );
      expect(
        FinanceAssistantCatalog.answerKeyForQuestion(key),
        isNot('finance_assistant_a_default'),
      );
    }
  });
}
