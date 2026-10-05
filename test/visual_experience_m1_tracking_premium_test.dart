import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/premium_icon_accent.dart';
import 'package:production_app/core/visual/premium/premium_station_palette.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/tracking/config/preparation_station_ui_prefs.dart';
import 'package:production_app/modules/production/tracking/config/station_screen_theme.dart';
import 'package:production_app/modules/production/tracking/config/station_screen_theme_store.dart';
import 'package:production_app/modules/quality/quality_premium_sections.dart';
import 'package:production_app/modules/production/tracking/widgets/production_tracking_hub_nav_strip.dart';
import 'package:production_app/modules/production/tracking/widgets/station_appearance_editor_dialog.dart';
import 'package:production_app/modules/production/tracking/widgets/tracking_workflow_chrome.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Praćenje Premium presentation', () {
    test('each station theme drives a distinct Premium workspace palette', () {
      final midnight = OperonixVisualTheme.premiumMidnight();
      final themes = <StationScreenThemeId, ThemeData>{
        for (final id in StationScreenThemeId.values)
          id: trackingPageTheme(
            parent: midnight,
            appearance: StationScreenAppearance(preset: id),
            premium: true,
          ),
      };
      final operonix = themes[StationScreenThemeId.operonix]!;
      final night = themes[StationScreenThemeId.industrialDark]!;
      final light = themes[StationScreenThemeId.cleanLight]!;

      expect(operonix.scaffoldBackgroundColor, const Color(0xFF0A1020));
      expect(operonix.brightness, Brightness.dark);
      expect(
        operonix.extension<OperonixVisualTokens>()!.style,
        VisualStyle.premium,
      );

      expect(night.scaffoldBackgroundColor, const Color(0xFF05080C));
      expect(night.brightness, Brightness.dark);
      expect(night.appBarTheme.backgroundColor, const Color(0xFF0C1218));
      expect(night.colorScheme.primary, const Color(0xFF3EC6D6));

      expect(light.scaffoldBackgroundColor, const Color(0xFFF2F4F7));
      expect(light.brightness, Brightness.light);
      expect(light.appBarTheme.backgroundColor, Colors.white);
      expect(
        light.extension<OperonixVisualTokens>()!.primaryText,
        const Color(0xFF1B2430),
      );
      expect(
        light.extension<OperonixVisualTokens>()!.style,
        VisualStyle.premium,
      );

      final canvases = themes.values
          .map((t) => t.scaffoldBackgroundColor)
          .toSet();
      final surfaces = themes.values
          .map((t) => t.appBarTheme.backgroundColor)
          .toSet();
      final accents = themes.values
          .map((t) => t.tabBarTheme.labelColor)
          .toSet();
      expect(canvases, hasLength(3));
      expect(surfaces, hasLength(3));
      expect(accents, hasLength(3));
      for (final theme in themes.values) {
        expect(theme.tabBarTheme.labelColor, theme.colorScheme.primary);
        expect(theme.tabBarTheme.indicatorColor, theme.colorScheme.primary);
      }
    });

    test('custom light workspace stays light and Premium', () {
      final custom = trackingPageTheme(
        parent: OperonixVisualTheme.premiumMidnight(),
        appearance: StationScreenAppearance(
          custom: StationScreenCustomColors(
            background: Colors.white,
            primaryAccent: Colors.purple,
            fieldOutline: Colors.grey,
          ),
        ),
        premium: true,
      );
      expect(custom.brightness, Brightness.light);
      expect(
        custom.scaffoldBackgroundColor.computeLuminance(),
        greaterThan(0.7),
      );
      expect(custom.colorScheme.primary, Colors.purple);
      expect(
        custom
            .extension<OperonixVisualTokens>()!
            .primaryText
            .computeLuminance(),
        lessThan(0.2),
      );
      expect(
        custom.extension<OperonixVisualTokens>()!.style,
        VisualStyle.premium,
      );
    });

    test('palette tokens apply immediately from the station appearance', () {
      final midnight = PremiumStationPalette.tokensFor(
        const StationScreenAppearance(),
      );
      final cobalt = PremiumStationPalette.tokensFor(
        const StationScreenAppearance(
          preset: StationScreenThemeId.industrialDark,
        ),
      );
      expect(midnight.pageBackground, const Color(0xFF0A1020));
      expect(cobalt.pageBackground, isNot(midnight.pageBackground));
      expect(cobalt.primaryAccent, isNot(midnight.primaryAccent));
      expect(cobalt.style, VisualStyle.premium);
    });

    test('palette persists through the station preference', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const saved = StationScreenAppearance(
        preset: StationScreenThemeId.cleanLight,
      );
      await StationScreenThemeStore.save(saved);
      final loaded = await StationScreenThemeStore.load();
      expect(loaded.preset, StationScreenThemeId.cleanLight);
      final theme = trackingPageTheme(
        parent: OperonixVisualTheme.premiumMidnight(),
        appearance: loaded,
        premium: true,
      );
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F4F7));
      expect(theme.brightness, Brightness.light);
      expect(
        OperonixVisualTheme.premiumMidnight().scaffoldBackgroundColor,
        const Color(0xFF0A1020),
      );
    });

    test('Classic still receives the full station theme', () {
      final classic = OperonixVisualTheme.classic();
      final station = trackingPageTheme(
        parent: classic,
        appearance: const StationScreenAppearance(),
        premium: false,
      );
      expect(station.brightness, Brightness.light);
      expect(station.scaffoldBackgroundColor, isNot(const Color(0xFF0A1020)));
      expect(station.scaffoldBackgroundColor, const Color(0xFFF5F8FB));
    });

    testWidgets('button theme stays out of the Premium workflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(
            body: TrackingButtonAccentChoices(
              selectedIndex: 0,
              onSelected: _noop,
            ),
          ),
        ),
      );
      expect(find.text('Tema gumba'), findsNothing);
      expect(find.text('Zelena'), findsNothing);
    });

    testWidgets('Classic workflow still shows the button theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.classic(),
          home: const Scaffold(
            body: TrackingButtonAccentChoices(
              selectedIndex: 0,
              onSelected: _noop,
            ),
          ),
        ),
      );
      expect(find.text('Tema gumba'), findsOneWidget);
      expect(find.text('Zelena'), findsOneWidget);
      expect(find.text('Plava'), findsOneWidget);
    });

    testWidgets(
      'palette dialog still exposes station theme and button colors',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await tester.pumpWidget(
          MaterialApp(
            theme: OperonixVisualTheme.premiumMidnight(),
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      showStationAppearanceEditorDialog(
                        context: context,
                        current: const StationScreenAppearance(),
                        showButtonAccent: true,
                      );
                    },
                    child: const Text('Otvori paletu'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Otvori paletu'));
        await tester.pumpAndSettle();
        expect(find.text('Operonix (brend)'), findsOneWidget);
        expect(find.text('Tema radnog prostora'), findsOneWidget);
        expect(find.text('Boja operativnih akcija'), findsOneWidget);
        expect(find.text('Tema gumba'), findsNothing);
        expect(find.text('Zelena'), findsOneWidget);
        expect(find.text('Ljubičasta'), findsOneWidget);
      },
    );

    testWidgets('entry mode and scan actions keep their callbacks', (
      tester,
    ) async {
      var quick = true;
      var scans = 0;
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: Column(
              children: [
                TrackingEntryModeControl(
                  quickMode: quick,
                  onChanged: (value) => quick = value,
                ),
                TrackingScanActions(
                  accent: const Color(0xFF2E7D32),
                  onScan: () => scans++,
                  onSecondary: () => closed++,
                  showSecondary: true,
                  secondaryLabel: 'Zatvori kutiju',
                  secondaryIcon: Icons.inventory_2_outlined,
                ),
                const TrackingWorkContextCard(
                  entryDate: '04.10.2026',
                  actions: [],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Brzi unos'), findsOneWidget);
      expect(find.text('Ručni unos'), findsOneWidget);
      expect(find.text('Vanjski QR skener'), findsNothing);
      expect(find.text('Datum unosa'), findsOneWidget);
      expect(find.text('04.10.2026'), findsOneWidget);

      await tester.tap(find.text('Ručni unos'));
      await tester.pump();
      expect(quick, isFalse);

      await tester.tap(find.text('Skeniraj QR'));
      await tester.tap(find.text('Zatvori kutiju'));
      await tester.pump();
      expect(scans, 1);
      expect(closed, 1);
      expect(find.byType(OutlinedButton), findsOneWidget);

      final surface = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PremiumSurfaceCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(surface.color, const Color(0xFF182338));
      expect(
        surface.color,
        isNot(OperonixVisualTokens.classic().pageBackground),
      );
    });

    testWidgets('Classic scan actions stay filled, not outlined', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.classic(),
          home: Scaffold(
            body: TrackingScanActions(
              accent: Colors.green,
              onScan: () {},
              onSecondary: () {},
              showSecondary: true,
              secondaryLabel: 'Zatvori kutiju',
              secondaryIcon: Icons.inventory_2_outlined,
            ),
          ),
        ),
      );
      expect(find.text('Skeniraj QR'), findsOneWidget);
      expect(find.text('Zatvori kutiju'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('hub destinations stay Pregled, Proizvodnja and Kvaliteta', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ProductionTrackingHubNavStrip(
              productionTabIndex: 1,
              onSelectPregled: () {},
              onSelectProizvodnjaFaze: () {},
              onSelectPlaceholder: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Pregled'), findsOneWidget);
      expect(find.text('Proizvodnja'), findsOneWidget);
      expect(find.text('Kvaliteta'), findsOneWidget);
      expect(find.text('Pripremna'), findsNothing);
      expect(find.text('Prva kontrola'), findsNothing);
      expect(find.text('Završna kontrola'), findsNothing);
    });

    test('quality premium groups the named areas', () {
      expect(
        qualityPremiumSectionForTitle('Moje otvorene akcije'),
        'Prioritet',
      );
      expect(qualityPremiumSectionForTitle('Metodologija · IATF'), 'Sistem');
      expect(qualityPremiumSectionForTitle('PFMEA (proces)'), 'Planiranje');
      expect(
        qualityPremiumSectionForTitle('Izvještaj za vodstvo'),
        'Izvještavanje',
      );
      expect(qualityPremiumSectionForTitle('NCR'), 'Operativa');
      expect(qualityPremiumSectionOrder.first, 'Prioritet');
    });

    testWidgets('tracking context band stays inside a narrow width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(
            body: TrackingContextBand(
              workDay: 'nedjelja, 4. oktobar',
              entryDate: '2026-10-04',
              plant: 'Brizganje (BR)',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Kontekst unosa'), findsOneWidget);
      expect(find.textContaining('2026-10-04'), findsWidgets);
      expect(find.textContaining('Brizganje (BR)'), findsOneWidget);
      expect(find.text('Radni dan'), findsNothing);

      await tester.tap(find.text('Kontekst unosa'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Radni dan'), findsOneWidget);
      expect(find.text('Datum unosa'), findsOneWidget);
      expect(find.text('Pogon'), findsOneWidget);
    });

    testWidgets('premium kpi panel is one surface and widens on desktop', (
      tester,
    ) async {
      const grid = PremiumKpiGrid(
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
        ],
      );
      await tester.binding.setSurfaceSize(const Size(1000, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(body: grid),
        ),
      );
      expect(find.byType(PremiumSurfaceCard), findsOneWidget);
      expect(find.text('Ukupno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a station palette changes the preview immediately', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showStationAppearanceEditorDialog(
                      context: context,
                      current: const StationScreenAppearance(),
                      showButtonAccent: true,
                    );
                  },
                  child: const Text('Otvori paletu'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Otvori paletu'));
      await tester.pumpAndSettle();

      BoxDecoration previewOf() {
        final box = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.text('Gumb'),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        return box.decoration! as BoxDecoration;
      }

      expect(previewOf().color, const Color(0xFF0A1020));
      await tester.tap(find.text('Industrijska noć'));
      await tester.pumpAndSettle();
      expect(previewOf().color, const Color(0xFF05080C));
      await tester.tap(find.text('Svijetla proizvodnja'));
      await tester.pumpAndSettle();
      final next = previewOf().color;
      expect(next, const Color(0xFFF2F4F7));
      expect(next!.computeLuminance(), greaterThan(0.7));
    });

    test('action color overrides buttons and leaves the canvas', () {
      final workspace = trackingPageTheme(
        parent: OperonixVisualTheme.premiumMidnight(),
        appearance: const StationScreenAppearance(
          preset: StationScreenThemeId.industrialDark,
        ),
        premium: true,
      );
      for (final action in PreparationStationUiPrefs.accentColors) {
        final themed = premiumTrackingActionTheme(workspace, action);
        expect(
          themed.scaffoldBackgroundColor,
          workspace.scaffoldBackgroundColor,
        );
        expect(
          themed.appBarTheme.backgroundColor,
          workspace.appBarTheme.backgroundColor,
        );
        expect(themed.tabBarTheme.labelColor, workspace.tabBarTheme.labelColor);
        final bg = themed.filledButtonTheme.style!.backgroundColor!.resolve(
          const <WidgetState>{},
        );
        final fg = themed.filledButtonTheme.style!.foregroundColor!.resolve(
          const <WidgetState>{},
        );
        expect(bg, action);
        expect(premiumContrast(bg!, fg!), greaterThanOrEqualTo(3));
      }
    });

    testWidgets('every saved action color recolors Skeniraj QR', (
      tester,
    ) async {
      for (final action in PreparationStationUiPrefs.accentColors) {
        await tester.pumpWidget(
          MaterialApp(
            theme: OperonixVisualTheme.premiumMidnight(),
            home: Scaffold(
              body: TrackingScanActions(
                accent: action,
                onScan: () {},
                onSecondary: () {},
                showSecondary: true,
                secondaryLabel: 'Zatvori kutiju',
                secondaryIcon: Icons.inventory_2_outlined,
              ),
            ),
          ),
        );
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Skeniraj QR'),
        );
        final bg = button.style!.backgroundColor!.resolve(
          const <WidgetState>{},
        );
        final fg = button.style!.foregroundColor!.resolve(
          const <WidgetState>{},
        );
        expect(bg, action);
        expect(premiumContrast(bg!, fg!), greaterThanOrEqualTo(3));
      }
    });

    test('saved action color and workspace theme reload together', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StationScreenThemeStore.save(
        const StationScreenAppearance(preset: StationScreenThemeId.cleanLight),
      );
      await PreparationStationUiPrefs.saveAccentIndex(2);
      final appearance = await StationScreenThemeStore.load();
      final accent = await PreparationStationUiPrefs.loadAccentIndex();
      expect(appearance.preset, StationScreenThemeId.cleanLight);
      expect(accent, 2);
      expect(
        PreparationStationUiPrefs.accentColors[accent],
        const Color(0xFFEF6C00),
      );
      final theme = trackingPageTheme(
        parent: OperonixVisualTheme.premiumMidnight(),
        appearance: appearance,
        premium: true,
      );
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F4F7));
      final actions = premiumTrackingActionTheme(
        theme,
        PreparationStationUiPrefs.accentColors[accent],
      );
      expect(
        actions.filledButtonTheme.style!.backgroundColor!.resolve(
          const <WidgetState>{},
        ),
        const Color(0xFFEF6C00),
      );
      expect(actions.scaffoldBackgroundColor, const Color(0xFFF2F4F7));
    });
  });
}

void _noop(int _) {}
