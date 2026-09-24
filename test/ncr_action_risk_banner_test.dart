import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/modules/quality/models/ncr_action_history_models.dart';
import 'package:production_app/modules/quality/widgets/ncr_action_risk_banner.dart';

void main() {
  testWidgets('none — mirno stanje bez alarma', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NcrActionRiskBanner(
            risk: NcrActionRiskSignalsResult(
              riskLevel: 'none',
              signals: [],
              ncrDocumentNo: 'NCR-PLM-BR-2026-000001',
              ncrStatusLabel: 'Otvoreno',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nema rizika'), findsOneWidget);
    expect(find.textContaining('high'), findsNothing);
    expect(find.textContaining('overdue'), findsNothing);
  });

  testWidgets('high — poslovna oznaka i BS signal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NcrActionRiskBanner(
            risk: NcrActionRiskSignalsResult(
              riskLevel: 'high',
              signals: [
                NcrActionRiskSignal(
                  code: 'overdue_due',
                  label: 'Kasni rok',
                  description: 'ignored in UI',
                  severity: 'high',
                ),
              ],
              ncrDocumentNo: 'NCR-PLM-BR-2026-000001',
              ncrStatusLabel: 'Otvoreno',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Visok rizik'), findsOneWidget);
    expect(find.text('Kasni rok'), findsOneWidget);
    expect(find.text('overdue_due'), findsNothing);
    expect(find.text('ignored in UI'), findsNothing);
  });

  test('riskLevelLabel — BCS mapiranje', () {
    expect(NcrActionRiskBanner.riskLevelLabel('medium'), 'Srednji rizik');
    expect(NcrActionRiskBanner.riskLevelLabel('low'), 'Nizak rizik');
  });
}
