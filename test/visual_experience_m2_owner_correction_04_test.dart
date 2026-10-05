import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/modules/production/work_centers/screens/work_center_create_screen.dart';
import 'package:production_app/modules/production/work_centers/screens/work_centers_list_screen.dart';

class _PushObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const plants = [
    (plantKey: 'br', label: 'Brizganje (BR)'),
    (plantKey: 'mt', label: 'Montaža (MT)'),
  ];

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpCenters(
    WidgetTester tester, {
    required ThemeData theme,
    required String role,
    List<({String plantKey, String label})>? plantOptions,
    NavigatorObserver? observer,
  }) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        key: ValueKey('${theme.brightness}-$role'),
        theme: theme,
        navigatorObservers: [?observer],
        home: WorkCentersListScreen(
          companyData: {
            'companyId': 'co',
            'plantKey': 'br',
            'role': role,
          },
          plantOptions: plantOptions,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Premium Pogon filter selects a plant and + opens create', (
    tester,
  ) async {
    final observer = _PushObserver();
    await pumpCenters(
      tester,
      theme: OperonixVisualTheme.premiumMidnight(),
      role: 'admin',
      plantOptions: plants,
      observer: observer,
    );

    expect(find.text('Pogon'), findsOneWidget);
    expect(find.text('Brizganje (BR)'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(PremiumContextCard), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Dodaj'), findsNothing);

    expect(find.byTooltip('Dodaj radni centar'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    final addButton = find.ancestor(
      of: find.byIcon(Icons.add),
      matching: find.byType(IconButton),
    );
    final addBox = tester.renderObject<RenderBox>(addButton);
    expect(addBox.size.shortestSide, greaterThanOrEqualTo(48));
    final addRight = addBox.localToGlobal(Offset.zero).dx + addBox.size.width;
    expect(addRight, lessThanOrEqualTo(360));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Montaža (MT)'), findsWidgets);
    await tester.tap(find.text('Montaža (MT)').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Montaža (MT)'), findsOneWidget);
    expect(find.text('Brizganje (BR)'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);

    final before = observer.pushed.length;
    await tester.tap(find.byTooltip('Dodaj radni centar'));
    await tester.pump();
    expect(tester.takeException(), isNotNull);
    expect(observer.pushed.length, before + 1);
    final route = observer.pushed.last as MaterialPageRoute<void>;
    final page = route.builder(tester.element(find.byType(WorkCentersListScreen)));
    expect(page, isA<WorkCenterCreateScreen>());
    expect((page as WorkCenterCreateScreen).initialPlantKey, 'mt');
  });

  testWidgets('plant-scoped role cannot pick another plant', (tester) async {
    await pumpCenters(
      tester,
      theme: OperonixVisualTheme.premiumMidnight(),
      role: 'production_manager',
      plantOptions: plants,
    );
    expect(find.text('Brizganje (BR)'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Montaža (MT)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Classic Radni centri keeps the floating add action', (
    tester,
  ) async {
    await pumpCenters(
      tester,
      theme: OperonixVisualTheme.classic(),
      role: 'admin',
      plantOptions: plants,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Dodaj radni centar'), findsNothing);
    expect(find.byType(PremiumContextCard), findsNothing);
    expect(find.text('Pogon (filter)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
