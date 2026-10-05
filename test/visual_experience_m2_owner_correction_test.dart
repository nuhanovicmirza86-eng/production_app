import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/ui/date_range_filter_controls.dart';
import 'package:production_app/core/visual/operonix_collapsible_section.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/premium/operonix_premium_icon.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/modules/production/planning/planning_session_controller.dart';
import 'package:production_app/modules/production/planning/planning_workflow_scope.dart';
import 'package:production_app/modules/production/planning/screens/planning_scenarios_tab.dart';
import 'package:production_app/modules/production/planning/screens/production_planning_home_screen.dart';
import 'package:production_app/modules/production/planning/screens/production_planning_screen.dart';
import 'package:production_app/modules/production/production_orders/screens/production_orders_list_screen.dart';
import 'package:production_app/modules/production/products/screens/products_list_screen.dart';
import 'package:production_app/modules/production/tracking/widgets/tracking_workflow_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setPhone(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('Premium product actions sit in the header and keep callbacks', (
    tester,
  ) async {
    await setPhone(tester, const Size(360, 780));
    var scanned = 0;
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Proizvodi'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Align(
                alignment: Alignment.centerRight,
                child: ProductsPageActions(
                  enabled: true,
                  onScan: () => scanned++,
                  onCreate: () => created++,
                ),
              ),
            ),
          ),
          body: const Align(
            alignment: Alignment.topLeft,
            child: Text('Tabela proizvoda'),
          ),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Novi proizvod'), findsNothing);
    expect(find.byType(OperonixPremiumIcon), findsNWidgets(2));
    expect(find.byTooltip(ProductsPageActions.scanTooltip), findsOneWidget);
    expect(find.byTooltip(ProductsPageActions.createTooltip), findsOneWidget);

    final actions = tester.getRect(find.byType(ProductsPageActions));
    final table = tester.getRect(find.text('Tabela proizvoda'));
    expect(actions.bottom, lessThanOrEqualTo(table.top + 1));
    expect(actions.width, greaterThanOrEqualTo(48));
    expect(actions.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip(ProductsPageActions.scanTooltip));
    await tester.tap(find.byTooltip(ProductsPageActions.createTooltip));
    expect(scanned, 1);
    expect(created, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded order filters scroll at phone widths', (tester) async {
    for (final width in [360.0, 411.0]) {
      await setPhone(tester, Size(width, 640));
      var toggles = 0;
      final expanded = ValueNotifier<bool>(true);
      addTearDown(expanded.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: expanded,
              builder: (context, isExpanded, _) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: OperonixCollapsibleSection(
                        title: 'Pretraga i filteri',
                        summary: 'Status, datum, proces',
                        expanded: isExpanded,
                        glyph: OperonixPremiumGlyph.tableColumns,
                        onToggle: () {
                          toggles++;
                          expanded.value = !expanded.value;
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status'),
                            Wrap(
                              children: [
                                for (final status
                                    in ProductionOrderStatusFilter.values)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: 8,
                                      bottom: 8,
                                    ),
                                    child: ChoiceChip(
                                      label: Text(status.label),
                                      selected: false,
                                      onSelected: (_) {},
                                    ),
                                  ),
                              ],
                            ),
                            DateRangeFilterControls(
                              sectionTitle: 'Datum kreiranja naloga',
                              helpText: 'Od–do po danu kreiranja naloga.',
                              from: null,
                              to: null,
                              onPickFrom: () {},
                              onPickTo: () {},
                              onClear: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byType(Wrap), findsWidgets);
      expect(find.text('Otkazan'), findsOneWidget);
      expect(find.text('Datum kreiranja naloga'), findsOneWidget);
      await tester.tap(find.text('Pretraga i filteri'));
      await tester.pumpAndSettle();
      expect(toggles, greaterThan(0));
      expect(find.text('Status'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'collapsed $width');
    }
  });

  testWidgets('planning settings start collapsed on a phone', (tester) async {
    await setPhone(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: const ProductionPlanningHomeScreen(companyData: {}),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Postavke plana'), findsOneWidget);
    expect(find.textContaining('14 dana'), findsOneWidget);
    expect(find.textContaining('Dan'), findsWidgets);
    expect(find.textContaining('Nacrt'), findsOneWidget);
    expect(find.text('Generiši plan'), findsNothing);
    expect(find.text('Nalozi'), findsOneWidget);

    final section = tester.getSize(find.byType(OperonixCollapsibleSection));
    expect(section.height, lessThan(160));

    await tester.tap(find.text('Postavke plana'));
    await tester.pumpAndSettle();
    expect(find.text('Generiši plan'), findsOneWidget);
    expect(find.text('Preračunaj'), findsOneWidget);
    expect(find.text('Simuliraj'), findsOneWidget);
    expect(find.text('Otpusti plan (detalji)'), findsOneWidget);
    expect(find.text('Horizont (d):'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Generiši plan'));
    await tester.tap(find.text('Generiši plan'));
    await tester.pump();
    expect(
      find.text('Odaberite barem jedan nalog (tab Nalozi).'),
      findsOneWidget,
    );
  });

  testWidgets('tracking context stays collapsed with date and plant', (
    tester,
  ) async {
    await setPhone(tester, const Size(411, 780));
    var focused = 0;
    var dated = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: Scaffold(
          body: Column(
            children: [
              TrackingContextBand(
                workDay: 'ponedjeljak, 5. oktobar',
                entryDate: '5.10.2026',
                plant: 'Brizganje (BR)',
                onPlant: () {},
                actions: [
                  IconButton(
                    tooltip: 'Fokus na pločice količina (Alt+Shift+P)',
                    onPressed: () => focused++,
                    icon: const Icon(Icons.keyboard_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Promijeni datum',
                    onPressed: () => dated++,
                    icon: const Icon(Icons.edit_calendar_outlined),
                  ),
                ],
              ),
              const Text('Spremno za unos'),
              const Text('Brzi unos'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Kontekst unosa'), findsOneWidget);
    expect(find.textContaining('5.10.2026'), findsWidgets);
    expect(find.textContaining('Brizganje (BR)'), findsOneWidget);
    expect(find.text('Radni dan'), findsNothing);
    expect(find.text('Spremno za unos'), findsOneWidget);

    final contextTop = tester.getTopLeft(find.text('Kontekst unosa')).dy;
    final readyTop = tester.getTopLeft(find.text('Spremno za unos')).dy;
    expect(readyTop, greaterThan(contextTop));
    expect(readyTop - contextTop, lessThan(120));

    await tester.tap(find.text('Kontekst unosa'));
    await tester.pumpAndSettle();
    expect(find.text('Radni dan'), findsOneWidget);
    expect(find.text('Datum unosa'), findsOneWidget);
    expect(find.text('Pogon'), findsOneWidget);
    await tester.tap(find.byTooltip('Promijeni datum'));
    await tester.tap(find.byTooltip('Fokus na pločice količina (Alt+Shift+P)'));
    expect(dated, 1);
    expect(focused, 1);
    expect(tester.takeException(), isNull);
  });

  const emptyOrders =
      'Nema naloga u statusima „Pušten” i „U toku” za ovaj pogon.';

  Future<PlanningSessionController> emptySession() async {
    final session = PlanningSessionController('', '');
    session.loadingPool = false;
    session.poolError = null;
    session.pool = [];
    return session;
  }

  testWidgets('planning orders empty state stays compact on a phone', (
    tester,
  ) async {
    for (final width in [360.0, 411.0]) {
      await setPhone(tester, Size(width, 800));
      final session = await emptySession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: PlanningWorkflowScope(
              session: session,
              child: const ProductionPlanningScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'orders $width');
      expect(find.text(emptyOrders), findsOneWidget);
      final empty = tester.getSize(find.byType(PremiumEmptyState));
      expect(empty.height, lessThan(220));
      expect(empty.width, lessThanOrEqualTo(width));

      expect(find.text('Filtri liste naloga'), findsOneWidget);
      final emptyRect = tester.getRect(find.text(emptyOrders));
      final filters = tester.getRect(find.text('Filtri liste naloga'));
      expect(filters.top, greaterThan(emptyRect.bottom));
      expect(filters.top - emptyRect.bottom, lessThan(160));
      expect(find.text('Pre-check (stalno)'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'filters $width');
    }
  });

  testWidgets('classic planning empty state keeps classic text', (
    tester,
  ) async {
    await setPhone(tester, const Size(360, 800));
    final session = await emptySession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.classic(),
        home: Scaffold(
          body: PlanningWorkflowScope(
            session: session,
            child: const ProductionPlanningScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(emptyOrders), findsOneWidget);
    expect(find.byType(PremiumEmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpScenarios(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
  }) async {
    await setPhone(tester, size);
    final title = TextEditingController();
    final base = TextEditingController();
    final notes = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(base.dispose);
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: PlanningScenariosLayout(
            rows: const [],
            locked: false,
            onRefresh: () {},
            onEdit: (_) {},
            onDelete: (_) {},
            form: PlanningScenarioForm(
              editing: false,
              locked: false,
              saving: false,
              title: title,
              basePlan: base,
              notes: notes,
              type: 'baseline',
              onType: (_) {},
              onUseLastPlan: () {},
              onSave: () {},
              onClear: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('planning scenarios are a single column on a phone', (
    tester,
  ) async {
    for (final width in [360.0, 411.0]) {
      await pumpScenarios(
        tester,
        size: Size(width, 800),
        theme: OperonixVisualTheme.premiumMidnight(),
      );
      expect(tester.takeException(), isNull, reason: 'scenarios $width');
      final intro = tester.getRect(
        find.text(PlanningScenariosLayout.introText),
      );
      expect(intro.width, greaterThan(width - 80));
      expect(intro.left, lessThan(40));

      await tester.ensureVisible(find.text('Novi scenarij'));
      final formTitle = tester.getRect(find.text('Novi scenarij'));
      expect(formTitle.top, greaterThan(intro.bottom));
      expect(formTitle.left, lessThan(40));

      await tester.ensureVisible(find.text('Naslov'));
      final field = tester.getSize(find.byType(TextField).first);
      expect(field.width, greaterThan(width - 80));

      await tester.ensureVisible(find.text('Spremljeni zapis'));
      final save = tester.getRect(find.text('Spremljeni zapis'));
      expect(save.right, lessThanOrEqualTo(width));
      expect(save.left, greaterThanOrEqualTo(0));
      expect(save.width, greaterThan(48));
      expect(tester.takeException(), isNull, reason: 'form $width');
    }
  });

  testWidgets('planning scenarios stay two columns on a wide screen', (
    tester,
  ) async {
    await pumpScenarios(
      tester,
      size: const Size(1440, 900),
      theme: OperonixVisualTheme.premiumMidnight(),
    );
    expect(tester.takeException(), isNull);
    final intro = tester.getRect(find.text(PlanningScenariosLayout.introText));
    final formTitle = tester.getRect(find.text('Novi scenarij'));
    expect(formTitle.left, greaterThan(intro.right - 8));
    expect((formTitle.top - intro.top).abs(), lessThan(80));
    final save = tester.getRect(find.text('Spremljeni zapis'));
    expect(save.right, lessThanOrEqualTo(1440));
  });

  testWidgets('all planning tabs render on phone widths', (tester) async {
    const tabs = ['Nalozi', 'Raspored', 'Provedba', 'Kapacitet', 'Scenariji'];
    for (final width in [360.0, 411.0]) {
      await setPhone(tester, Size(width, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const ProductionPlanningHomeScreen(companyData: {}),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'home $width');
      for (final label in tabs) {
        expect(find.text(label), findsWidgets);
        await tester.ensureVisible(find.text(label).first);
        await tester.tap(find.text(label).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: '$label $width');
      }
    }
  });
}
