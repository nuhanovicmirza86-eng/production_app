import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/ui/standard_list_components.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_filter_bar.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_presentation.dart';

void main() {
  test('NOTIF-M1-B4-UI-HOTFIX-01 uses standard Filteri title', () {
    expect(MesInboxPresentation.filterBarButtonLabel(), 'Filteri');
    expect(MesInboxPresentation.filterBarStatusGroupLabel(), 'Status');
    expect(MesInboxPresentation.filterBarPeriodGroupLabel(), 'Period');
  });

  testWidgets('NOTIF-M1-B4-UI-HOTFIX-01 uses StandardFilterPanel collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(const _FilterHarness());
    expect(find.byType(StandardFilterPanel), findsOneWidget);
    expect(find.text('Filteri'), findsOneWidget);
    expect(find.text('Promijeni filtere'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(tester.getSize(find.byType(MesInboxFilterBar)).height, lessThan(90));
  });

  testWidgets('NOTIF-M1-B4-UI-HOTFIX-01 tap Filteri expands panel', (
    tester,
  ) async {
    await tester.pumpWidget(const _FilterHarness());
    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Kritično'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Danas'), findsOneWidget);
  });

  testWidgets('NOTIF-M1-B4-UI-HOTFIX-01 stays open after pick like other lists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _FilterHarness());
    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kritično'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Kritično'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

class _FilterHarness extends StatefulWidget {
  const _FilterHarness();

  @override
  State<_FilterHarness> createState() => _FilterHarnessState();
}

class _FilterHarnessState extends State<_FilterHarness> {
  MesInboxListFilter _filter = MesInboxListFilter.unread;
  MesInboxPeriodFilter _period = MesInboxPeriodFilter.all;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            MesInboxFilterBar(
              filter: _filter,
              period: _period,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
              onFilterSelected: (filter) => setState(() => _filter = filter),
              onPeriodSelected: (period) => setState(() => _period = period),
            ),
            const Divider(height: 1),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    );
  }
}
