import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/modules/production/tracking/config/station_screen_theme.dart';
import 'package:production_app/modules/production/tracking/widgets/production_tracking_hub_nav_strip.dart';
import 'package:production_app/modules/production/tracking/widgets/station_appearance_editor_dialog.dart';
import 'package:production_app/modules/production/tracking/widgets/tracking_workflow_chrome.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Praćenje Premium presentation', () {
    test('station theme does not replace the Premium page background', () {
      final midnight = OperonixVisualTheme.premiumMidnight();
      final kept = trackingPageTheme(
        parent: midnight,
        appearance: const StationScreenAppearance(
          preset: StationScreenThemeId.cleanLight,
        ),
        premium: true,
      );
      expect(kept.scaffoldBackgroundColor, midnight.scaffoldBackgroundColor);
      expect(kept.scaffoldBackgroundColor, const Color(0xFF0A1020));

      final custom = trackingPageTheme(
        parent: midnight,
        appearance: StationScreenAppearance(
          custom: StationScreenCustomColors(
            background: Colors.white,
            primaryAccent: Colors.purple,
            fieldOutline: Colors.grey,
          ),
        ),
        premium: true,
      );
      expect(custom.scaffoldBackgroundColor, const Color(0xFF0A1020));
      expect(custom.brightness, Brightness.dark);
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

    testWidgets('button theme stays out of the Premium workflow', (tester) async {
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

    testWidgets('Classic workflow still shows the button theme', (tester) async {
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

    testWidgets('palette dialog still exposes station theme and button colors', (
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
      expect(find.text('Operonix (brend)'), findsOneWidget);
      expect(find.text('Tema gumba'), findsOneWidget);
      expect(find.text('Zelena'), findsOneWidget);
      expect(find.text('Ljubičasta'), findsOneWidget);
    });

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
        find.descendant(
          of: find.byType(PremiumSurfaceCard),
          matching: find.byType(Material),
        ).first,
      );
      expect(surface.color, const Color(0xFF182338));
      expect(
        surface.color,
        isNot(OperonixVisualTokens.classic().pageBackground),
      );
    });

    testWidgets('Classic scan actions stay filled, not outlined', (tester) async {
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
  });
}

void _noop(int _) {}
