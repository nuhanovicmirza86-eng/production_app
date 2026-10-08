import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_application_frame.dart';
import 'package:production_app/core/visual/operonix_desktop_shell.dart';
import 'package:production_app/core/visual/operonix_shell_metrics.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/premium/premium_icon_accent.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/core/visual/visual_experience_controller.dart';
import 'package:production_app/core/visual/visual_experience_scope.dart';
import 'package:production_app/core/visual/visual_experience_store.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_module.dart';
import 'package:production_app/modules/production/dashboard/production_dashboard_access.dart';
import 'package:production_app/modules/production/dashboard/screens/production_dashboard_screen.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_attention.dart';
import 'package:production_app/modules/production/station_pages/screens/production_evidence_operator_hub_screen.dart';
import 'package:production_app/modules/production/tracking/widgets/tracking_workflow_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const desktopWidths = <double>[1280, 1366, 1440, 1536, 1920];

  group('Production web shell', () {
    test('application frame does not declare a 1280 shell cap', () {
      expect(OperonixShellMetrics.railMinWidth, 80);
      expect(OperonixShellMetrics.railDividerWidth, 1);
      expect(OperonixShellMetrics.wideBreakpoint, 900);
    });

    for (final width in desktopWidths) {
      testWidgets('desktop $width keeps a full-width rail shell', (tester) async {
        await _setSurface(tester, Size(width, 900));
        Rect? classicRail;
        Rect? premiumRail;

        for (final style in VisualStyle.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: OperonixVisualTheme.forStyle(style),
              home: OperonixApplicationFrame(
                useWebShell: true,
                child: OperonixDesktopShell(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  leading: const Icon(Icons.menu),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      label: Text('Početna'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      label: Text('Nalozi'),
                    ),
                  ],
                  child: const SizedBox.expand(key: Key('page')),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          final frame = tester.getRect(find.byType(OperonixApplicationFrame));
          final rail = tester.getRect(find.byType(NavigationRail));
          final page = tester.getRect(find.byKey(const Key('page')));
          expect(frame.left, 0);
          expect(frame.width, width);
          expect(rail.left, 0);
          expect(rail.width, greaterThanOrEqualTo(OperonixShellMetrics.railMinWidth));
          expect(
            page.left,
            closeTo(rail.right + OperonixShellMetrics.railDividerWidth, 1),
          );
          expect(page.right, lessThanOrEqualTo(width + 0.5));
          expect(page.width, greaterThan(width * 0.75));
          expect(find.byType(NavigationBar), findsNothing);
          expect(_shellCaps(tester), isEmpty);
          if (style == VisualStyle.classic) {
            classicRail = rail;
          } else {
            premiumRail = rail;
          }
        }

        expect(classicRail!.left, premiumRail!.left);
        expect(classicRail.width, premiumRail.width);
      });
    }
  });

  group('Premium desktop composition', () {
    testWidgets('Home icon grid uses several columns and short tiles', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1920, 1080));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ProductionDashboardHomeModulesView(
              layout: ProductionDashboardLayout.iconGrid,
              access: _access(),
              sections: [
                ProductionDashboardModuleSection(
                  id: 'production',
                  title: 'Proizvodnja',
                  subtitle: 'Moduli',
                  icon: Icons.precision_manufacturing_outlined,
                  entries: [
                    for (final title in [
                      'Proizvodni nalozi',
                      'Planiranje proizvodnje',
                      'Praćenje proizvodnje (tabovi)',
                      'Operativne evidencije procesa i kontrola kvaliteta',
                      'Radni centri',
                      'Procesi',
                      'Registracije',
                      'Izvještaji',
                    ])
                      ProductionDashboardModuleEntry(
                        id: title,
                        icon: Icons.apps_outlined,
                        title: title,
                        subtitle: 'Modul',
                        onTap: () {},
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final grids = tester.widgetList<GridView>(find.byType(GridView));
      expect(grids, isNotEmpty);
      for (final grid in grids) {
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, greaterThanOrEqualTo(6));
        expect(delegate.mainAxisExtent, isNotNull);
        expect(delegate.mainAxisExtent!, lessThanOrEqualTo(140));
      }
      expect(
        find.text('Operativne evidencije procesa i kontrola kvaliteta'),
        findsOneWidget,
      );
    });

    testWidgets('order KPIs share one row on desktop and wrap on a phone', (
      tester,
    ) async {
      const grid = PremiumKpiGrid(
        cards: [
          PremiumKpiCard(
            label: 'Ukupno',
            value: '12',
            icon: Icons.assignment_outlined,
            role: PremiumIconRole.info,
          ),
          PremiumKpiCard(
            label: 'Otvoreni',
            value: '3',
            icon: Icons.pending_actions_outlined,
            role: PremiumIconRole.warning,
          ),
          PremiumKpiCard(
            label: 'U toku',
            value: '4',
            icon: Icons.play_circle_outline,
            role: PremiumIconRole.active,
          ),
          PremiumKpiCard(
            label: 'Završeni',
            value: '5',
            icon: Icons.task_alt_rounded,
            role: PremiumIconRole.success,
          ),
        ],
      );

      Future<void> pump(Size size) async {
        await _setSurface(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            theme: OperonixVisualTheme.premiumMidnight(),
            home: const Scaffold(body: grid),
          ),
        );
        await tester.pump();
      }

      await pump(const Size(1366, 800));
      expect(tester.takeException(), isNull);
      final desktopTops = [
        tester.getTopLeft(find.text('Ukupno')).dy,
        tester.getTopLeft(find.text('Otvoreni')).dy,
        tester.getTopLeft(find.text('U toku')).dy,
        tester.getTopLeft(find.text('Završeni')).dy,
      ];
      expect(
        desktopTops.reduce((a, b) => a > b ? a : b) -
            desktopTops.reduce((a, b) => a < b ? a : b),
        lessThan(8),
      );

      await pump(const Size(480, 900));
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('U toku')).dy -
            tester.getTopLeft(find.text('Ukupno')).dy,
        greaterThan(20),
      );
    });

    testWidgets('processes composition uses the desktop width', (tester) async {
      await _setSurface(tester, const Size(1536, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const PremiumContextCard(
                  icon: Icons.factory_outlined,
                  role: PremiumIconRole.info,
                  label: 'Pogon',
                  value: 'Brizganje (BR)',
                ),
                const SizedBox(height: 10),
                PremiumFilterCard(
                  title: 'Filteri',
                  summary: 'Tip, status, IATF',
                  expanded: false,
                  onToggle: () {},
                  child: const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                const PremiumEmptyState(
                  icon: Icons.account_tree_outlined,
                  role: PremiumIconRole.active,
                  title: 'Nema procesa na ovom pogonu.',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PremiumContextCard)).width, greaterThan(1000));
      expect(tester.getSize(find.byType(PremiumEmptyState)).width, greaterThan(1000));
      expect(tester.getTopLeft(find.text('Pogon')).dx, lessThan(80));
    });

    testWidgets('operational evidence list uses the desktop width', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                ProductionEvidenceListCard(
                  title: 'Kontrola pakovanja',
                  subtitle: 'Pogon: Brčko · Proces: Pakovanje',
                  icon: Icons.inventory_2_outlined,
                  infoAction: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ProductionEvidenceListCard)).width,
        greaterThan(1000),
      );
    });

    testWidgets('tracking context band shares one desktop row', (tester) async {
      await _setSurface(tester, const Size(1920, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(
            body: TrackingContextBand(
              workDay: 'ponedjeljak, 5. oktobar',
              entryDate: '2026-10-05',
              plant: 'Brizganje (BR)',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TrackingContextBand)).width, greaterThan(1400));
      expect(
        (tester.getTopLeft(find.text('Radni dan')).dy -
                tester.getTopLeft(find.text('Pogon')).dy)
            .abs(),
        lessThan(8),
      );
    });

    testWidgets('quality groups use three columns on a wide desktop', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1536, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PremiumSectionHeader(title: 'Prioritet'),
                const SizedBox(height: 8),
                PremiumResponsiveGrid(
                  children: [
                    for (final title in [
                      'Moje otvorene akcije',
                      'Kontrolne evidencije',
                      'NCR - Neusklađenosti',
                    ])
                      PremiumListCard(
                        icon: Icons.fact_check_outlined,
                        role: PremiumIconRole.quality,
                        title: title,
                        subtitle: 'Kvalitet',
                        onTap: () {},
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.text('Moje otvorene akcije'));
      final second = tester.getRect(find.text('Kontrolne evidencije'));
      final third = tester.getRect(find.text('NCR - Neusklađenosti'));
      expect((first.top - second.top).abs(), lessThan(8));
      expect((first.top - third.top).abs(), lessThan(8));
      expect(second.left, greaterThan(first.right - 40));
      expect(third.left, greaterThan(second.right - 40));
    });
  });

  group('web appearance settings', () {
    testWidgets('desktop settings stay out of Home and open from tune', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      final controller = VisualExperienceController(
        store: MemoryVisualExperienceStore(initial: VisualStyle.premium),
      );
      await controller.load();
      var layout = ProductionDashboardLayout.standard;
      await tester.pumpWidget(
        VisualExperienceScope(
          controller: controller,
          child: MaterialApp(
            theme: OperonixVisualTheme.premiumMidnight(),
            home: ProductionHomePage(
              companyData: const {},
              roleLabel: 'Administrator',
              companyId: '',
              plantKey: '',
              companyLine: 'Operonix',
              dashboardLayout: layout,
              onHomeLayoutChanged: (next) => layout = next,
              moduleSections: const [],
              dashboardAccess: _access(),
              attentionCounts: const MesInboxAttentionCounts(
                newCount: 0,
                waitingActionCount: 0,
              ),
              onOpenInbox: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Raspored:'), findsNothing);
      expect(find.text('Prikaz:'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Izgled aplikacije'));
      await tester.pumpAndSettle();
      expect(find.text('Prikaz:'), findsOneWidget);
      expect(find.text('Tema: Midnight'), findsOneWidget);
      expect(find.text('Raspored:'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ikone'));
      await tester.pump();
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(controller.style, VisualStyle.premium);
    });
  });
}

List<ConstrainedBox> _shellCaps(WidgetTester tester) {
  return tester
      .widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(OperonixApplicationFrame),
          matching: find.byType(ConstrainedBox),
        ),
      )
      .where((box) => box.constraints.maxWidth == 1280)
      .toList();
}

ProductionDashboardAccess _access() {
  return ProductionDashboardAccess(
    companyData: const {},
    role: 'admin',
    companyId: 'c',
    plantKey: 'p',
    enabledModules: const ['production'],
  );
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
