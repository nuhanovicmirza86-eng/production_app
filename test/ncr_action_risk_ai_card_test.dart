import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/modules/quality/models/ncr_action_history_models.dart';
import 'package:production_app/modules/quality/widgets/ncr_action_risk_ai_card.dart';

void main() {
  testWidgets('prikazuje Operonix AI Asistent i BS polja', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NcrActionRiskAiCard(
            explanation: NcrActionRiskAiExplanation(
              aiUsed: true,
              procjena: 'Rizik je povišen zbog kasnog roka.',
              zastoJeVazno: 'Rok utječe na isporuku.',
              preporuceniSljedeciKorak: 'Provjeri status dorade.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Operonix AI Asistent'), findsOneWidget);
    expect(find.text('AI procjena rizika'), findsOneWidget);
    expect(find.text('Procjena'), findsOneWidget);
    expect(find.text('Zašto je važno'), findsOneWidget);
    expect(find.text('Preporučeni sljedeći korak'), findsOneWidget);
    expect(find.text('overdue_due'), findsNothing);
  });
}
