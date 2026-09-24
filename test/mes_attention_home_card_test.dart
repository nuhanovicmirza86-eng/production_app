import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/notifications/mes_attention_home_card.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_attention.dart';

void main() {
  testWidgets('NOTIF-M1-C-UI-HOTFIX-01 home card uses chips not slash badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MesAttentionHomeCard(
            counts: const MesInboxAttentionCounts(
              newCount: 198,
              waitingActionCount: 50,
            ),
            onOpenInbox: () {},
          ),
        ),
      ),
    );
    expect(find.text('Potrebna pažnja'), findsOneWidget);
    expect(find.text('198 novih'), findsOneWidget);
    expect(find.text('50 čeka akciju'), findsOneWidget);
    expect(find.text('Otvori obavijesti'), findsOneWidget);
    expect(find.text('99+ / 50'), findsNothing);
    expect(find.text('99+'), findsNothing);
    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('NOTIF-M1-C-UI-HOTFIX-01 nav badge is compact 99+', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MesInboxNavBadge(
            counts: MesInboxAttentionCounts(
              newCount: 198,
              waitingActionCount: 50,
            ),
            outlined: true,
          ),
        ),
      ),
    );
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('99+ / 50'), findsNothing);
    expect(find.textContaining(' / '), findsNothing);
  });
}
