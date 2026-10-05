import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/premium_station_palette.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/features/process_evidence_analytics/widgets/process_evidence_analytics_filters.dart';
import 'package:production_app/modules/commercial/orders/screens/orders_list_screen.dart';
import 'package:production_app/modules/production/planning/models/planning_scenario_record.dart';
import 'package:production_app/modules/production/planning/screens/planning_scenarios_tab.dart';
import 'package:production_app/modules/production/planning/screens/production_planning_home_screen.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_config.dart';
import 'package:production_app/modules/production/tracking/config/station_screen_theme.dart';
import 'package:production_app/modules/production/tracking/config/station_screen_theme_store.dart';
import 'package:production_app/modules/production/work_centers/screens/work_centers_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setPhone(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  PlanningScenarioForm scenarioForm() {
    return PlanningScenarioForm(
      editing: false,
      locked: false,
      saving: false,
      title: TextEditingController(),
      basePlan: TextEditingController(),
      notes: TextEditingController(),
      type: 'baseline',
      onType: (_) {},
      onUseLastPlan: () {},
      onSave: () {},
      onClear: () {},
    );
  }

  Future<void> pumpScenarios(
    WidgetTester tester, {
    required Size viewport,
    required double incomingWidth,
  }) async {
    await setPhone(tester, viewport);
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: Scaffold(
          body: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: incomingWidth,
                maxWidth: incomingWidth,
                maxHeight: viewport.height,
                child: PlanningScenariosLayout(
                  rows: const <PlanningScenarioRecord>[],
                  locked: false,
                  onRefresh: () {},
                  onEdit: (_) {},
                  onDelete: (_) {},
                  form: scenarioForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'inflated nested width still uses the phone viewport for Scenariji',
    (tester) async {
      await pumpScenarios(
        tester,
        viewport: const Size(360, 900),
        incomingWidth: 1400,
      );
      expect(tester.takeException(), isNull);
      final intro = tester.getTopLeft(
        find.text('Scenariji planiranja (F4)'),
      );
      final form = tester.getTopLeft(find.text('Novi scenarij'));
      expect(form.dx, lessThan(intro.dx + 24));
      expect(form.dy, greaterThan(intro.dy + 8));
      final save = tester.getRect(find.text('Spremljeni zapis'));
      expect(save.right, lessThanOrEqualTo(360));
    },
  );

  testWidgets('Planning route is one column at Samsung widths', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const tabs = ['Nalozi', 'Raspored', 'Provedba', 'Kapacitet', 'Scenariji'];
    for (final width in [360.0, 411.0]) {
      await setPhone(tester, Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: ProductionPlanningHomeScreen(
            key: ValueKey('planning-$width'),
            companyData: const {
              'companyId': 'co',
              'plantKey': 'pk',
              'role': 'admin',
            },
            scenarioLoader: () async => const <PlanningScenarioRecord>[],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'home $width');

      final poolCard = find.ancestor(
        of: find.text('Nalozi za planiranje'),
        matching: find.byType(Card),
      );
      expect(poolCard, findsOneWidget);
      final cardBox = tester.renderObject<RenderBox>(poolCard);
      expect(cardBox.size.height, lessThan(640), reason: 'empty pool $width');

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      for (var i = 0; i < tabs.length; i++) {
        tabBar.controller!.animateTo(i);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: '${tabs[i]} $width');
      }
      await tester.drag(find.byType(TabBar), const Offset(-640, 0));
      await tester.pump();
      await tester.tap(find.text('Scenariji'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final intro = tester.getTopLeft(
        find.text('Scenariji planiranja (F4)'),
      );
      final form = tester.getTopLeft(find.text('Novi scenarij'));
      expect(form.dx, lessThan(intro.dx + 24));
      expect(form.dy, greaterThan(intro.dy));
      expect(find.text('Naslov'), findsOneWidget);
      expect(find.text('Ubaci zadnje spremljeni plan iz sesije'), findsOneWidget);
      final save = tester.getRect(find.text('Spremljeni zapis'));
      expect(save.right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull, reason: 'scenarios $width');
    }
  });

  Future<void> pumpFilters(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
  }) async {
    await setPhone(tester, Size(width, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProcessEvidenceAnalyticsFiltersPanel(
                  key: ValueKey('filters-$width-$textScale'),
                  dateFrom: DateTime(2026, 9, 1),
                  dateTo: DateTime(2026, 10, 5),
                  plantKey: 'pk',
                  processProfileType: 'rework_and_painting',
                  stationConfigId: null,
                  operatorId: null,
                  plantOptions: const [
                    (plantKey: 'pk', label: 'Pogon proizvodnje'),
                  ],
                  stationOptions: const <ProductionStationConfig>[],
                  operatorOptions: const [
                    (id: 'op', label: 'Operater prve smjene'),
                  ],
                  canPickPlant: true,
                  fixedPlantLabel: null,
                  loading: false,
                  onPickDateFrom: () {},
                  onPickDateTo: () {},
                  onPlantChanged: (_) {},
                  onProfileChanged: (_) {},
                  onStationChanged: (_) {},
                  onOperatorChanged: (_) {},
                  onApply: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shared evidence filters collapse and fit on a phone', (
    tester,
  ) async {
    for (final width in [360.0, 411.0]) {
      for (final scale in [1.0, 1.3]) {
        await pumpFilters(tester, width: width, textScale: scale);
        expect(find.text('Period od'), findsNothing);
        expect(find.text('Filteri'), findsOneWidget);
        expect(find.textContaining('01.09.2026'), findsOneWidget);
        await tester.tap(find.text('Filteri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        for (final label in [
          'Period od',
          'Period do',
          'Pogon',
          'Profil evidencije',
          'Stanica',
          'Operater',
          'Primijeni',
        ]) {
          expect(find.text(label), findsWidgets, reason: '$label $width $scale');
        }
        await tester.fling(find.byType(ListView), const Offset(0, -400), 800);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'filters $width $scale');
      }
    }
  });

  testWidgets('Narudžbe keeps Premium Midnight contrast', (tester) async {
    await setPhone(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('orders-premium'),
        theme: OperonixVisualTheme.premiumMidnight(),
        home: const OrdersListScreen(companyData: {}),
      ),
    );
    await tester.pump();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF0A1020));
    final title = tester.widget<Text>(find.text('Narudžbe'));
    expect(title.style?.color, const Color(0xFFE6EDF3));
    expect(
      find.text('Nedostaje podatak o kompaniji. Obrati se administratoru.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('orders-classic'),
        theme: OperonixVisualTheme.classic(),
        home: const OrdersListScreen(companyData: {}),
      ),
    );
    await tester.pump();
    final classic = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(classic.backgroundColor, const Color(0xFFF5F6FA));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracking light theme does not recolor the next Premium screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const appearance = StationScreenAppearance(
      preset: StationScreenThemeId.cleanLight,
    );
    await StationScreenThemeStore.save(appearance);

    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: Builder(
          builder: (context) {
            final local = trackingPageTheme(
              parent: Theme.of(context),
              appearance: appearance,
              premium: true,
            );
            return Theme(
              data: local,
              child: Scaffold(
                body: Builder(
                  builder: (inner) {
                    final bg = Theme.of(inner).scaffoldBackgroundColor;
                    return Column(
                      children: [
                        Text('local:${bg.toARGB32()}'),
                        TextButton(
                          onPressed: () {
                            Navigator.of(inner).push(
                              MaterialPageRoute<void>(
                                builder: (routeContext) {
                                  final theme = Theme.of(routeContext);
                                  final tokens = OperonixVisualTokens.of(
                                    routeContext,
                                  );
                                  return Scaffold(
                                    body: Text(
                                      'global:${theme.scaffoldBackgroundColor.toARGB32()}:${tokens.pageBackground.toARGB32()}',
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          child: const Text('Otvori narudžbe'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('local:${const Color(0xFFF2F4F7).toARGB32()}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Otvori narudžbe'));
    await tester.pumpAndSettle();
    final midnight = const Color(0xFF0A1020).toARGB32();
    expect(find.text('global:$midnight:$midnight'), findsOneWidget);
    final stored = await StationScreenThemeStore.load();
    expect(stored.preset, StationScreenThemeId.cleanLight);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpWorkCenters(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await setPhone(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        key: ValueKey(theme.brightness),
        theme: theme,
        home: const WorkCentersListScreen(
          companyData: {
            'companyId': 'co',
            'plantKey': 'pk',
            'role': 'admin',
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Premium Radni centri uses the header action, Classic keeps FAB', (
    tester,
  ) async {
    await pumpWorkCenters(
      tester,
      theme: OperonixVisualTheme.premiumMidnight(),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Dodaj radni centar'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Pogon'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Filteri'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    expect(find.byType(PremiumEmptyState), findsOneWidget);
    final empty = tester.renderObject<RenderBox>(find.byType(PremiumEmptyState));
    expect(empty.size.height, lessThan(420));
    expect(tester.takeException(), isNull);

    await pumpWorkCenters(tester, theme: OperonixVisualTheme.classic());
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(PremiumContextCard), findsNothing);
    expect(find.byType(PremiumEmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
