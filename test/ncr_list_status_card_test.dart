import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/quality/models/qms_list_models.dart';
import 'package:production_app/modules/quality/widgets/ncr_list_status_card.dart';

void main() {
  QmsNcrRow row({required String status, String code = 'NCR-TEST01'}) {
    return QmsNcrRow(
      id: 'internal-should-not-show',
      ncrCode: code,
      source: 'PROCESS',
      status: status,
      severity: 'HIGH',
      description:
          'Automatski iz evidencije: Odobrenje prvog komada. Nalog: BR-260603-93314. Proizvod: GK400002.',
      productId: 'GK400002',
      productionOrderId: 'BR-260603-93314',
      createdAtIso: '2026-08-27T11:21:05.215Z',
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required String status,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NcrListStatusCard(
            row: row(status: status),
            onTap: () {},
          ),
        ),
      ),
    );
  }

  group('NcrListStatusCard — premium status obrub', () {
    testWidgets('otvoreni NCR ima tekstualni badge Otvoreno', (tester) async {
      await pumpCard(tester, status: 'OPEN');
      expect(find.text('Otvoreno'), findsOneWidget);
      expect(find.text('NCR-TEST01'), findsOneWidget);
      expect(find.textContaining('internal-should-not-show'), findsNothing);
    });

    testWidgets('zatvoreni NCR ima tekstualni badge Zatvoreno', (tester) async {
      await pumpCard(tester, status: 'CLOSED');
      expect(find.text('Zatvoreno'), findsOneWidget);
    });

    testWidgets('prikazuje poslovna polja bez raw ID-a', (tester) async {
      await pumpCard(tester, status: 'OPEN');
      expect(find.text('GK400002'), findsOneWidget);
      expect(find.text('BR-260603-93314'), findsOneWidget);
      expect(find.textContaining('2026-08-27T'), findsNothing);
      expect(find.textContaining('27.08.2026.'), findsOneWidget);
    });
  });
}
