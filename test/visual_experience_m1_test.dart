import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/ui/standard_list_components.dart';
import 'package:production_app/core/visual/app_appearance_selector.dart';
import 'package:production_app/core/visual/operonix_application_frame.dart';
import 'package:production_app/core/visual/operonix_desktop_shell.dart';
import 'package:production_app/core/visual/operonix_empty_state.dart';
import 'package:production_app/core/visual/operonix_shell_metrics.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/operonix_premium_icon.dart';
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
import 'package:production_app/modules/production/dashboard/widgets/production_classic_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_icon_grid_tile.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_attention.dart';
import 'package:production_app/modules/production/station_pages/screens/production_evidence_operator_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisualStyle preference', () {
    test('no saved preference resolves Classic', () {
      expect(VisualStyle.fromStorage(null), VisualStyle.classic);
      expect(VisualStyle.fromStorage(''), VisualStyle.classic);
      expect(VisualStyle.fromStorage('unknown'), VisualStyle.classic);
    });

    test('Classic and Premium round-trip and stay local', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesVisualExperienceStore(preferences: prefs);
      final controller = VisualExperienceController(store: store);

      await controller.load();
      expect(controller.style, VisualStyle.classic);

      await controller.setStyle(VisualStyle.premium);
      expect(controller.style, VisualStyle.premium);
      expect(prefs.getString(SharedPreferencesVisualExperienceStore.storageKey), 'premium');

      final restored = VisualExperienceController(
        store: SharedPreferencesVisualExperienceStore(preferences: prefs),
      );
      await restored.load();
      expect(restored.style, VisualStyle.premium);

      await restored.setStyle(VisualStyle.classic);
      final classicAgain = VisualExperienceController(
        store: SharedPreferencesVisualExperienceStore(preferences: prefs),
      );
      await classicAgain.load();
      expect(classicAgain.style, VisualStyle.classic);
    });

    test('Standardno / Ikone key is independent of visual style', () async {
      expect(
        SharedPreferencesVisualExperienceStore.storageKey,
        isNot(ProductionDashboardLayout.preferenceKey),
      );
      final layout = ProductionDashboardLayout.iconGrid;
      final controller = VisualExperienceController(
        store: MemoryVisualExperienceStore(),
      );
      await controller.setStyle(VisualStyle.premium);
      await controller.setStyle(VisualStyle.classic);
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(controller.style, VisualStyle.classic);
    });
  });

  group('Premium Midnight tokens', () {
    test('midnight palette resolves semantic colors', () {
      final tokens = OperonixVisualTokens.midnight();
      expect(tokens.style, VisualStyle.premium);
      expect(tokens.background, const Color(0xFF0A1020));
      expect(tokens.surface, const Color(0xFF121A2B));
      expect(tokens.surfaceElevated, const Color(0xFF182338));
      expect(tokens.surfaceInteractive, const Color(0xFF223049));
      expect(tokens.kpiActive, const Color(0xFFFF7043));
      expect(tokens.primaryText, const Color(0xFFE6EDF3));
      expect(tokens.secondaryText, const Color(0xFF8B949E));
      expect(tokens.primaryAccent, const Color(0xFF3D9A94));
      expect(tokens.success, const Color(0xFF3DCF8C));
      expect(tokens.warning, const Color(0xFFE0A106));
      expect(tokens.danger, const Color(0xFFE35D5D));
      expect(tokens.info, const Color(0xFF58A6FF));
      expect(tokens.border, isNot(tokens.primaryAccent));
    });

    test('classic tokens keep the accepted KPI colors', () {
      final tokens = OperonixVisualTokens.classic();
      expect(tokens.style, VisualStyle.classic);
      expect(tokens.info, Colors.blue);
      expect(tokens.warning, Colors.orange);
      expect(tokens.kpiActive, Colors.deepOrange);
      expect(tokens.success, Colors.green);
      expect(tokens.pageBackground, const Color(0xFFF5F6FA));
      expect(tokens.kpiSurface, Colors.white);
      expect(tokens.cardBorderWidth, 1.5);
    });

    test('themes expose the matching extension', () {
      expect(
        OperonixVisualTheme.classic().extension<OperonixVisualTokens>()!.style,
        VisualStyle.classic,
      );
      final premium = OperonixVisualTheme.premiumMidnight();
      expect(premium.brightness, Brightness.dark);
      expect(
        premium.extension<OperonixVisualTokens>()!.background,
        const Color(0xFF0A1020),
      );
      expect(premium.scaffoldBackgroundColor, const Color(0xFF0A1020));
      expect(
        premium.navigationRailTheme.minWidth,
        isNull,
        reason: 'Tema ne smije mijenjati širinu raila.',
      );
    });
  });

  group('shell geometry', () {
    test('wide breakpoint matches Maintenance 900', () {
      expect(OperonixShellMetrics.wideBreakpoint, 900);
      expect(OperonixShellMetrics.railMinWidth, 80);
      expect(OperonixShellMetrics.railDividerWidth, 1);
      expect(
        OperonixShellMetrics.isWide(width: 899, windowsNative: false),
        isFalse,
      );
      expect(
        OperonixShellMetrics.isWide(width: 900, windowsNative: false),
        isTrue,
      );
      expect(
        OperonixShellMetrics.isWide(width: 360, windowsNative: true),
        isTrue,
      );
      expect(OperonixShellMetrics.pagePaddingFor(web: true), 12);
      expect(OperonixShellMetrics.pagePaddingFor(web: false), 16);
    });

    testWidgets('web shell is full viewport, not centered 1280', (tester) async {
      await _setSurface(tester, const Size(1920, 1080));
      await tester.pumpWidget(
        MaterialApp(
          home: OperonixApplicationFrame(
            useWebShell: true,
            child: const SizedBox.expand(key: Key('viewport')),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('viewport'))).width, 1920);
      expect(
        tester.getSize(find.byKey(const Key('viewport'))).width,
        greaterThan(1280),
      );
    });

    testWidgets('content constraint stays inside the full shell', (tester) async {
      await _setSurface(tester, const Size(1600, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: OperonixApplicationFrame(
            useWebShell: true,
            child: OperonixContentConstraint(
              maxWidth: 720,
              child: SizedBox(key: Key('form'), width: 2000, height: 40),
            ),
          ),
        ),
      );
      final shell = tester.getSize(find.byType(OperonixApplicationFrame));
      final form = tester.getSize(find.byKey(const Key('form')));
      expect(shell.width, 1600);
      expect(form.width, 720);
    });

    testWidgets('desktop rail keeps Maintenance width at several viewports', (
      tester,
    ) async {
      for (final width in <double>[900, 1280, 1440, 1920]) {
        await _setSurface(tester, Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(
            home: OperonixDesktopShell(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  label: Text('Početna'),
                ),
              ],
              child: const Text('sadržaj'),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final rail = tester.getRect(find.byType(NavigationRail));
        expect(rail.left, 0);
        expect(rail.width, greaterThanOrEqualTo(OperonixShellMetrics.railMinWidth));
        final content = tester.getTopLeft(find.text('sadržaj'));
        expect(
          content.dx,
          rail.width + OperonixShellMetrics.railDividerWidth,
        );
        expect(find.byType(NavigationBar), findsNothing);
      }
    });

    testWidgets('Classic and Premium use the same rail geometry', (tester) async {
      Rect railFor(VisualStyle style) {
        return tester.getRect(find.byType(NavigationRail));
      }

      Future<Rect> pumpStyle(VisualStyle style) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: OperonixVisualTheme.forStyle(style),
            home: OperonixDesktopShell(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  label: Text('Početna'),
                ),
              ],
              child: const Text('sadržaj'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return railFor(style);
      }

      await _setSurface(tester, const Size(1440, 900));
      final classic = await pumpStyle(VisualStyle.classic);
      final premium = await pumpStyle(VisualStyle.premium);
      expect(classic.left, premium.left);
      expect(classic.width, premium.width);
      expect(classic.left, 0);
    });
  });

  group('pilot presentation', () {
    testWidgets('immediate Classic to Premium to Classic', (tester) async {
      final controller = VisualExperienceController(
        store: MemoryVisualExperienceStore(),
      );
      var layout = ProductionDashboardLayout.standard;

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return VisualExperienceScope(
              controller: controller,
              child: MaterialApp(
                theme: OperonixVisualTheme.forStyle(controller.style),
                home: Scaffold(body: _pilotChrome(
                  layout: layout,
                  onLayout: (next) => layout = next,
                )),
              ),
            );
          },
        ),
      );

      expect(find.text('Izgled aplikacije'), findsOneWidget);
      expect(find.text('Prikaz:'), findsOneWidget);
      expect(find.text('Raspored:'), findsOneWidget);
      expect(find.text('Tema: Midnight'), findsNothing);
      expect(find.text('Standardno'), findsOneWidget);
      expect(find.text('Proizvodni nalozi'), findsOneWidget);
      expect(find.text('Ukupno'), findsOneWidget);
      expect(find.text('Pretraga i filteri'), findsOneWidget);
      expect(find.text('Kontrola pakovanja'), findsOneWidget);
      expect(controller.style, VisualStyle.classic);

      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();

      expect(controller.style, VisualStyle.premium);
      expect(find.text('Tema: Midnight'), findsOneWidget);
      expect(layout, ProductionDashboardLayout.standard);
      expect(
        OperonixVisualTokens.of(
          tester.element(find.text('Tema: Midnight')),
        ).background,
        const Color(0xFF0A1020),
      );
      expect(find.text('Kontrola pakovanja'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ikone'));
      await tester.pumpAndSettle();
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(controller.style, VisualStyle.premium);

      await tester.tap(find.text('Classic'));
      await tester.pumpAndSettle();
      expect(controller.style, VisualStyle.classic);
      expect(find.text('Tema: Midnight'), findsNothing);
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(find.text('Procesi (master-data)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('appearance settings', () {
    test('home layout persistence contract is unchanged', () {
      expect(
        ProductionDashboardLayout.preferenceKey,
        'productionDashboardLayout',
      );
      expect(ProductionDashboardLayout.standard.storageValue, 'standard');
      expect(ProductionDashboardLayout.iconGrid.storageValue, 'icon_grid');
      expect(
        SharedPreferencesVisualExperienceStore.storageKey,
        isNot('productionDashboardLayout'),
      );
    });

    testWidgets('settings show style, Midnight and home layout', (tester) async {
      final controller = VisualExperienceController(
        store: MemoryVisualExperienceStore(),
      );
      var layout = ProductionDashboardLayout.standard;

      Future<void> pump() {
        return tester.pumpWidget(
          VisualExperienceScope(
            controller: controller,
            child: MaterialApp(
              theme: OperonixVisualTheme.forStyle(controller.style),
              home: AppAppearanceScreen(
                homeLayout: layout,
                onHomeLayoutChanged: (next) => layout = next,
              ),
            ),
          ),
        );
      }

      await pump();
      expect(find.text('Prikaz:'), findsOneWidget);
      expect(find.text('Classic'), findsWidgets);
      expect(find.text('Premium'), findsWidgets);
      expect(find.text('Raspored:'), findsOneWidget);
      expect(find.text('Standardno'), findsOneWidget);
      expect(find.text('Ikone'), findsOneWidget);
      expect(find.text('Tema: Midnight'), findsNothing);

      await tester.tap(find.text('Premium'));
      await tester.pump();
      await pump();
      expect(controller.style, VisualStyle.premium);
      expect(layout, ProductionDashboardLayout.standard);
      expect(find.text('Tema: Midnight'), findsOneWidget);

      await tester.tap(find.text('Ikone'));
      await tester.pump();
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(controller.style, VisualStyle.premium);

      await tester.tap(find.text('Classic'));
      await tester.pump();
      await pump();
      expect(controller.style, VisualStyle.classic);
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(find.text('Tema: Midnight'), findsNothing);
    });

    testWidgets('Classic and Premium Home have no layout selector', (
      tester,
    ) async {
      for (final style in VisualStyle.values) {
        final controller = VisualExperienceController(
          store: MemoryVisualExperienceStore(initial: style),
        );
        await controller.load();
        await tester.pumpWidget(
          VisualExperienceScope(
            key: ValueKey(style),
            controller: controller,
            child: MaterialApp(
              key: ValueKey(style),
              theme: OperonixVisualTheme.forStyle(style),
              home: ProductionHomePage(
                companyData: const {},
                roleLabel: 'Administrator',
                companyId: '',
                plantKey: '',
                companyLine: 'Operonix',
                dashboardLayout: ProductionDashboardLayout.iconGrid,
                onHomeLayoutChanged: (_) {},
                moduleSections: const <ProductionDashboardModuleSection>[],
                dashboardAccess: _appearanceAccess(),
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
        expect(find.text('Brze akcije'), findsOneWidget);
        expect(find.text('Početna'), findsOneWidget);
        expect(find.text('Raspored:'), findsNothing);
        expect(find.text('Standardno'), findsNothing);
        expect(find.text('Ikone'), findsNothing);
        expect(find.text('Prikaz:'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('tune opens appearance settings without touching layout', (
      tester,
    ) async {
      for (final style in VisualStyle.values) {
        final controller = VisualExperienceController(
          store: MemoryVisualExperienceStore(initial: style),
        );
        await controller.load();
        var layout = ProductionDashboardLayout.iconGrid;
        await tester.pumpWidget(
          VisualExperienceScope(
            key: ValueKey(style),
            controller: controller,
            child: MaterialApp(
              key: ValueKey(style),
              theme: OperonixVisualTheme.forStyle(style),
              home: ProductionHomePage(
                companyData: const {},
                roleLabel: 'Administrator',
                companyId: '',
                plantKey: '',
                companyLine: 'Operonix',
                dashboardLayout: layout,
                onHomeLayoutChanged: (next) => layout = next,
                moduleSections: const <ProductionDashboardModuleSection>[],
                dashboardAccess: _appearanceAccess(),
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
        await tester.tap(find.byTooltip('Izgled aplikacije'));
        await tester.pumpAndSettle();
        expect(find.text('Prikaz:'), findsOneWidget);
        expect(find.text('Raspored:'), findsOneWidget);
        expect(find.text('Standardno'), findsOneWidget);
        expect(find.text('Ikone'), findsOneWidget);
        if (style == VisualStyle.premium) {
          expect(find.text('Tema: Midnight'), findsOneWidget);
        } else {
          expect(find.text('Tema: Midnight'), findsNothing);
        }
        expect(layout, ProductionDashboardLayout.iconGrid);
        expect(controller.style, style);
      }
    });

    testWidgets('mobile Više shows appearance controls', (tester) async {
      final controller = VisualExperienceController(
        store: MemoryVisualExperienceStore(),
      );
      var layout = ProductionDashboardLayout.standard;
      await tester.pumpWidget(
        VisualExperienceScope(
          controller: controller,
          child: MaterialApp(
            theme: OperonixVisualTheme.forStyle(VisualStyle.classic),
            home: Scaffold(
              appBar: AppBar(title: const Text('Više')),
              body: AppAppearanceSelector(
                homeLayout: layout,
                onHomeLayoutChanged: (next) => layout = next,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Više'), findsOneWidget);
      expect(find.text('Izgled aplikacije'), findsOneWidget);
      expect(find.text('Prikaz:'), findsOneWidget);
      expect(find.text('Raspored:'), findsOneWidget);
      expect(find.text('Tema: Midnight'), findsNothing);

      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();
      expect(controller.style, VisualStyle.premium);
      expect(layout, ProductionDashboardLayout.standard);
    });

    testWidgets('web menu opens the same appearance settings', (tester) async {
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
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ProductionDashboardActionTile(
                    icon: Icons.tune,
                    title: 'Izgled aplikacije',
                    subtitle: 'Classic, Premium i raspored početne',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AppAppearanceScreen(
                            homeLayout: layout,
                            onHomeLayoutChanged: (next) => layout = next,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Classic, Premium i raspored početne'),
        findsOneWidget,
      );
      await tester.tap(find.text('Izgled aplikacije'));
      await tester.pumpAndSettle();
      expect(find.text('Prikaz:'), findsOneWidget);
      expect(find.text('Tema: Midnight'), findsOneWidget);
      expect(find.text('Raspored:'), findsOneWidget);
      await tester.tap(find.text('Ikone'));
      await tester.pump();
      expect(layout, ProductionDashboardLayout.iconGrid);
      expect(controller.style, VisualStyle.premium);
    });

    testWidgets('changing layout from settings updates Home immediately', (
      tester,
    ) async {
      final controller = VisualExperienceController(
        store: MemoryVisualExperienceStore(initial: VisualStyle.classic),
      );
      await controller.load();
      await tester.pumpWidget(
        VisualExperienceScope(
          controller: controller,
          child: MaterialApp(
            theme: OperonixVisualTheme.forStyle(VisualStyle.classic),
            home: const _ImmediateLayoutHost(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ProductionClassicActionTile), findsOneWidget);
      expect(find.byType(ProductionDashboardActionTile), findsNothing);
      expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
      expect(find.text('Raspored:'), findsNothing);

      await tester.tap(find.byTooltip('Izgled aplikacije'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ikone'));
      await tester.pump();
      expect(controller.style, VisualStyle.classic);
      expect(find.text('Tema: Midnight'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProductionClassicActionTile), findsOneWidget);
      expect(find.byType(ProductionDashboardActionTile), findsNothing);
      expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
      expect(
        tester.getSize(find.byType(ProductionClassicActionTile)).width,
        ProductionClassicActionTile.maxTileWidth,
      );
      expect(
        tester.getSize(find.byType(ProductionClassicActionTile)).height,
        ProductionClassicActionTile.tileHeight,
      );
      expect(find.text('Brze akcije'), findsOneWidget);
      expect(find.text('Raspored:'), findsNothing);
      expect(find.text('Prikaz:'), findsNothing);
      expect(controller.style, VisualStyle.classic);
      expect(tester.takeException(), isNull);
    });
  });

  group('Premium presentation', () {
    test('semantic accents stay distinct', () {
      expect(
        PremiumIconAccent.forProfile('chemical_dosing'),
        PremiumIconRole.lab,
      );
      expect(
        PremiumIconAccent.forProfile('production_counting'),
        PremiumIconRole.success,
      );
      expect(
        PremiumIconAccent.forProfile('in_process_quality_check'),
        PremiumIconRole.quality,
      );
      expect(
        PremiumIconAccent.forProfile('operation_material_preparation'),
        PremiumIconRole.material,
      );
      final colors = {
        PremiumIconAccent.of(PremiumIconRole.info),
        PremiumIconAccent.of(PremiumIconRole.success),
        PremiumIconAccent.of(PremiumIconRole.warning),
        PremiumIconAccent.of(PremiumIconRole.active),
        PremiumIconAccent.of(PremiumIconRole.quality),
        PremiumIconAccent.of(PremiumIconRole.lab),
      };
      expect(colors.length, greaterThan(3));
      expect(
        PremiumIconAccent.of(PremiumIconRole.lab),
        isNot(PremiumIconAccent.of(PremiumIconRole.info)),
      );
    });

    testWidgets('premium evidence card keeps title and drops the extra line', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ProductionEvidenceListCard(
              title: 'Doziranje hemikalija',
              subtitle: 'Doziranje\nPogon: BR · Proces: MIX · Faza: 1',
              icon: Icons.science_outlined,
              profileKey: 'chemical_dosing',
              infoAction: const Icon(Icons.info_outline),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Doziranje hemikalija'), findsOneWidget);
      expect(find.text('Pogon: BR · Proces: MIX · Faza: 1'), findsOneWidget);
      expect(find.text('Doziranje'), findsNothing);
      expect(find.byType(PremiumListCard), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      final mark = tester.widget<OperonixPremiumIcon>(
        find.byType(OperonixPremiumIcon),
      );
      expect(mark.glyph, OperonixPremiumGlyph.chemicalDose);
      expect(mark.color, PremiumIconAccent.of(PremiumIconRole.lab));
    });

    testWidgets('classic evidence card stays a list tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.classic(),
          home: const Scaffold(
            body: ProductionEvidenceListCard(
              title: 'Kontrola pakovanja',
              subtitle: 'Profil\nPogon: BR',
              icon: Icons.inventory_2_outlined,
              infoAction: Icon(Icons.info_outline),
            ),
          ),
        ),
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(PremiumListCard), findsNothing);
    });

    testWidgets('premium empty panel contains the add action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: PremiumEmptyState(
              icon: Icons.account_tree_outlined,
              role: PremiumIconRole.active,
              title: 'Nema procesa na ovom pogonu.',
              support: 'Dodajte prvi zapis za početak.',
              actionLabel: 'Dodaj',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.text('Nema procesa na ovom pogonu.'), findsOneWidget);
      expect(find.text('Dodajte prvi zapis za početak.'), findsOneWidget);
      expect(find.text('Dodaj'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('premium kpi cards keep semantic icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(
            body: PremiumKpiGrid(
              cards: [
                PremiumKpiCard(
                  label: 'Ukupno',
                  value: '4',
                  icon: Icons.assignment_outlined,
                  role: PremiumIconRole.info,
                ),
                PremiumKpiCard(
                  label: 'Otvoreni',
                  value: '1',
                  icon: Icons.pending_actions_outlined,
                  role: PremiumIconRole.warning,
                ),
                PremiumKpiCard(
                  label: 'U toku',
                  value: '2',
                  icon: Icons.play_circle_outline,
                  role: PremiumIconRole.active,
                ),
                PremiumKpiCard(
                  label: 'Završeni',
                  value: '3',
                  icon: Icons.task_alt_rounded,
                  role: PremiumIconRole.success,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Ukupno'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      final marks = tester
          .widgetList<OperonixPremiumIcon>(find.byType(OperonixPremiumIcon))
          .toList();
      expect(marks.map((mark) => mark.glyph).toList(), [
        OperonixPremiumGlyph.kpiTotal,
        OperonixPremiumGlyph.kpiOpen,
        OperonixPremiumGlyph.kpiRunning,
        OperonixPremiumGlyph.kpiDone,
      ]);
      expect(marks[0].color, PremiumIconAccent.info);
      expect(marks[2].color, PremiumIconAccent.active);
      expect(marks[3].color, PremiumIconAccent.success);
    });
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _pilotChrome({
  required ProductionDashboardLayout layout,
  required ValueChanged<ProductionDashboardLayout> onLayout,
}) {
  return ListView(
    children: [
      AppAppearanceSelector(
        homeLayout: layout,
        onHomeLayoutChanged: onLayout,
      ),
      const StandardScreenHeader(title: 'Proizvodni nalozi'),
      const StandardKpiGrid(
        metrics: [
          KpiMetric(
            label: 'Ukupno',
            value: 0,
            color: Colors.blue,
            icon: Icons.assignment_outlined,
          ),
          KpiMetric(
            label: 'Otvoreni',
            value: 0,
            color: Colors.orange,
            icon: Icons.pending_actions_outlined,
          ),
          KpiMetric(
            label: 'U toku',
            value: 0,
            color: Colors.deepOrange,
            icon: Icons.play_circle_outline,
          ),
          KpiMetric(
            label: 'Završeni',
            value: 0,
            color: Colors.green,
            icon: Icons.task_alt_rounded,
          ),
        ],
      ),
      StandardFilterPanel(
        title: 'Pretraga i filteri',
        expanded: false,
        activeCount: 0,
        onToggle: () {},
        child: const SizedBox.shrink(),
      ),
      const Text('Procesi (master-data)'),
      const OperonixEmptyState(
        message: 'Nema procesa na ovom pogonu.',
      ),
      ProductionEvidenceListCard(
        title: 'Kontrola pakovanja',
        subtitle: 'Pogon: Brčko · Proces: Pakovanje · Faza: Završna',
        icon: Icons.inventory_2_outlined,
        infoAction: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.info_outline),
        ),
        onTap: () {},
      ),
    ],
  );
}

ProductionDashboardAccess _appearanceAccess() {
  return ProductionDashboardAccess(
    companyData: const {},
    role: 'admin',
    companyId: 'c',
    plantKey: 'p',
    enabledModules: const ['production'],
  );
}

class _ImmediateLayoutHost extends StatefulWidget {
  const _ImmediateLayoutHost();

  @override
  State<_ImmediateLayoutHost> createState() => _ImmediateLayoutHostState();
}

class _ImmediateLayoutHostState extends State<_ImmediateLayoutHost> {
  var _layout = ProductionDashboardLayout.standard;

  @override
  Widget build(BuildContext context) {
    return ProductionHomePage(
      companyData: const {},
      roleLabel: 'Administrator',
      companyId: '',
      plantKey: '',
      companyLine: 'Operonix',
      dashboardLayout: _layout,
      onHomeLayoutChanged: (next) => setState(() => _layout = next),
      moduleSections: [
        ProductionDashboardModuleSection(
          id: 'production',
          title: 'Proizvodnja',
          subtitle: 'Moduli',
          icon: Icons.precision_manufacturing_outlined,
          entries: [
            ProductionDashboardModuleEntry(
              id: 'orders',
              icon: Icons.assignment_outlined,
              title: 'Proizvodni nalozi',
              subtitle: 'Nalozi',
              onTap: () {},
            ),
          ],
        ),
      ],
      dashboardAccess: _appearanceAccess(),
      attentionCounts: const MesInboxAttentionCounts(
        newCount: 0,
        waitingActionCount: 0,
      ),
      onOpenInbox: () {},
    );
  }
}
