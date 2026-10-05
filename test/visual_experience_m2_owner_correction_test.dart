import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/ui/date_range_filter_controls.dart';
import 'package:production_app/core/visual/operonix_collapsible_section.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/premium/operonix_premium_icon.dart';
import 'package:production_app/modules/production/planning/screens/production_planning_home_screen.dart';
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
}
