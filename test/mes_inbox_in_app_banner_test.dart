import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_in_app_banner.dart';

void main() {
  testWidgets('NOTIF-M1-C-UI-HOTFIX-02 top banner is compact and closable', (
    tester,
  ) async {
    var opened = false;
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MesInboxInAppBanner(
            businessTitle: 'Rizik kašnjenja roka',
            onOpen: () => opened = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    expect(find.text('Nova obavijest'), findsOneWidget);
    expect(find.text('Rizik kašnjenja roka'), findsOneWidget);
    expect(find.text('Otvori'), findsOneWidget);
    expect(find.textContaining('PROD_ORDER'), findsNothing);
    expect(find.textContaining('Nova obavijest:'), findsNothing);
    await tester.tap(find.text('Otvori'));
    expect(opened, isTrue);
    await tester.tap(find.byTooltip('Zatvori'));
    expect(dismissed, isTrue);
  });

  testWidgets('NOTIF-M1-C-UI-HOTFIX-02 layer hides when arrival is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MesInboxInAppBannerLayer(
          arrival: null,
          onOpen: _noop,
          onDismiss: _noop,
          child: Scaffold(
            body: Text('Početna'),
            bottomNavigationBar: NavigationBar(
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Početna',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  label: 'Obavijesti',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Nova obavijest'), findsNothing);
    expect(find.text('Početna'), findsWidgets);
    expect(find.text('Obavijesti'), findsOneWidget);
  });
}

void _noop() {}
