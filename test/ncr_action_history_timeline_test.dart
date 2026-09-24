import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:production_app/modules/quality/models/ncr_action_history_models.dart';
import 'package:production_app/modules/quality/widgets/ncr_action_history_timeline.dart';

void main() {
  testWidgets('prazna historija — poslovna poruka', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NcrActionHistoryTimeline(entries: []),
        ),
      ),
    );

    expect(
      find.text(NcrActionHistoryTimeline.emptyMessage),
      findsOneWidget,
    );
    expect(find.textContaining('UID'), findsNothing);
  });

  testWidgets('prikaz poslovnog reda historije', (tester) async {
    const entry = NcrActionHistoryEntry(
      occurredAt: '02.09.2026. 09:10',
      stepLabel: 'Postavljena akcija',
      actionLabel: 'Potrebna dorada',
      ownerLabel: 'Ana · Voditelj kvaliteta',
      executorLabel: 'Marko · Operater proizvodnje',
      dueLabel: '05.09.2026. 17:00',
      statusLabel: 'Otvoreno',
      note: 'Provjeri dimenziju.',
      eventSourceLabel: 'Odobrenje prvog komada',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NcrActionHistoryTimeline(
            entries: [
              NcrActionHistoryHubRow(
                entry: entry,
                ncrDocumentNo: 'NCR-PLM-BR-2026-000001',
                ncrStatusLabel: 'Otvoreno',
                ncrId: 'internal-not-shown',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Historija akcija'), findsOneWidget);
    expect(find.text('Potrebna dorada'), findsOneWidget);
    expect(find.text('Izvor događaja'), findsOneWidget);
    expect(find.text('internal-not-shown'), findsNothing);
  });
}
