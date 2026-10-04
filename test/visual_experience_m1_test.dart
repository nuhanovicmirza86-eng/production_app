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
import 'package:production_app/core/visual/visual_experience_controller.dart';
import 'package:production_app/core/visual/visual_experience_scope.dart';
import 'package:production_app/core/visual/visual_experience_store.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_layout_selector.dart';
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
      expect(tokens.background, const Color(0xFF070A0F));
      expect(tokens.surface, const Color(0xFF12151C));
      expect(tokens.surfaceElevated, const Color(0xFF1C232E));
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
        const Color(0xFF070A0F),
      );
      expect(premium.scaffoldBackgroundColor, const Color(0xFF070A0F));
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
        const Color(0xFF070A0F),
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
      const AppAppearanceSelector(),
      ProductionDashboardLayoutSelector(value: layout, onChanged: onLayout),
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
