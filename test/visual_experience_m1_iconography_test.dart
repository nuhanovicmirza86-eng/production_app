import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/operonix_premium_icon.dart';
import 'package:production_app/core/visual/premium/operonix_premium_iconography.dart';
import 'package:production_app/core/visual/premium/premium_icon_accent.dart';
import 'package:production_app/core/visual/premium/premium_station_palette.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_action_tile.dart';
import 'package:production_app/modules/production/station_pages/screens/production_evidence_operator_hub_screen.dart';
import 'package:production_app/modules/production/tracking/config/station_screen_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Premium iconography', () {
    test('home, evidence, quality and KPI glyphs stay distinct', () {
      final home = [
        OperonixPremiumIconography.forTitle('Registracije'),
        OperonixPremiumIconography.forTitle('Proizvodnja'),
        OperonixPremiumIconography.forTitle('Proizvodni nalozi'),
        OperonixPremiumIconography.forTitle('Planiranje proizvodnje'),
        OperonixPremiumIconography.forTitle('Praćenje proizvodnje (tabovi)'),
        OperonixPremiumIconography.forTitle('Kvalitet'),
        OperonixPremiumIconography.forTitle('OperonixAI'),
      ];
      expect(home.toSet().length, home.length);
      expect(home[6], OperonixPremiumGlyph.aiInsight);

      final evidence = [
        'chemical_dosing',
        'production_counting',
        'in_process_quality_check',
        'material_preparation',
        'wastewater_treatment',
        'packaging_control',
        'first_piece_approval',
        'final_control',
        'line_clearance',
        'workspace_5s_cleaning',
      ].map(OperonixPremiumIconography.forProfile).toList();
      expect(evidence.toSet().length, evidence.length);
      expect(evidence.first, OperonixPremiumGlyph.chemicalDose);

      final quality = [
        'Moje otvorene akcije',
        'Metodologija · IATF',
        'Pregled kvaliteta',
        'Dokumentacija',
        'PFMEA (proces)',
        'Kontrolni planovi',
        'Planovi kontrole',
        'Izvještaj za vodstvo',
      ].map(OperonixPremiumIconography.forTitle).toList();
      expect(quality.toSet().length, quality.length);
      expect(quality[4], OperonixPremiumGlyph.pfmea);

      final kpis = ['Ukupno', 'Otvoreni', 'U toku', 'Završeni']
          .map(OperonixPremiumIconography.forKpi)
          .toList();
      expect(kpis.toSet().length, 4);
    });

    test('semantic families stay distinguishable', () {
      final colors = {
        for (final role in PremiumIconRole.values) PremiumIconAccent.of(role),
      };
      expect(colors.length, greaterThan(7));
      expect(
        OperonixPremiumIconography.roleFor(OperonixPremiumGlyph.productionCell),
        PremiumIconRole.success,
      );
      expect(
        OperonixPremiumIconography.roleFor(OperonixPremiumGlyph.pfmea),
        PremiumIconRole.critical,
      );
      expect(
        OperonixPremiumIconography.roleFor(OperonixPremiumGlyph.chemicalDose),
        PremiumIconRole.lab,
      );
      expect(
        PremiumIconAccent.of(PremiumIconRole.critical),
        isNot(PremiumIconAccent.of(PremiumIconRole.warning)),
      );
    });

    test('utility icons are not replaced by a domain glyph', () {
      expect(OperonixPremiumIconography.forIcon(Icons.close), isNull);
      expect(OperonixPremiumIconography.forIcon(Icons.search), isNull);
      expect(OperonixPremiumIconography.forIcon(Icons.refresh), isNull);
      expect(OperonixPremiumIconography.forIcon(Icons.arrow_back), isNull);
    });

    testWidgets('every glyph paints without an asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: Wrap(
              children: [
                for (final glyph in OperonixPremiumGlyph.values)
                  OperonixPremiumIcon(glyph: glyph, size: 24),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(OperonixPremiumIcon),
        findsNWidgets(OperonixPremiumGlyph.values.length),
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('badge variants change radius and honor disabled contrast', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(
            body: Column(
              children: [
                PremiumIconBadge(
                  glyph: OperonixPremiumGlyph.productionOrder,
                  role: PremiumIconRole.success,
                  variant: PremiumBadgeVariant.small,
                ),
                PremiumIconBadge(
                  glyph: OperonixPremiumGlyph.productionOrder,
                  role: PremiumIconRole.success,
                  variant: PremiumBadgeVariant.medium,
                ),
                PremiumIconBadge(
                  glyph: OperonixPremiumGlyph.productionOrder,
                  role: PremiumIconRole.success,
                  variant: PremiumBadgeVariant.large,
                ),
                PremiumIconBadge(
                  glyph: OperonixPremiumGlyph.qrScan,
                  role: PremiumIconRole.info,
                  disabled: true,
                ),
              ],
            ),
          ),
        ),
      );
      final badges = tester
          .widgetList<PremiumIconBadge>(find.byType(PremiumIconBadge))
          .toList();
      expect(badges[0].radius, 8);
      expect(badges[1].radius, 12);
      expect(badges[2].radius, 18);
      expect(badges[0].extent, isNot(badges[2].extent));
      final disabled = tester
          .widgetList<OperonixPremiumIcon>(find.byType(OperonixPremiumIcon))
          .last;
      expect(
        disabled.color,
        OperonixVisualTokens.midnight().disabledText,
      );
    });

    testWidgets('light tracking palette keeps a readable glyph', (tester) async {
      final theme = trackingPageTheme(
        parent: OperonixVisualTheme.premiumMidnight(),
        appearance: const StationScreenAppearance(
          preset: StationScreenThemeId.cleanLight,
        ),
        premium: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: PremiumIconBadge(
              glyph: OperonixPremiumGlyph.productionCell,
              role: PremiumIconRole.success,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final mark = tester.widget<OperonixPremiumIcon>(
        find.byType(OperonixPremiumIcon),
      );
      expect(mark.color, isNotNull);
      expect(mark.color!.computeLuminance(), lessThan(0.75));
    });

    testWidgets('classic home tile keeps the Material icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.classic(),
          home: Scaffold(
            body: ProductionDashboardActionTile(
              icon: Icons.assignment,
              title: 'Proizvodni nalozi',
              subtitle: 'Lista naloga',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.assignment), findsOneWidget);
      expect(find.byType(OperonixPremiumIcon), findsNothing);
    });

    testWidgets('premium home tile uses the domain glyph', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ProductionDashboardActionTile(
              icon: Icons.assignment,
              title: 'Proizvodni nalozi',
              subtitle: 'Lista naloga',
              onTap: () {},
            ),
          ),
        ),
      );
      final badge = tester.widget<PremiumIconBadge>(find.byType(PremiumIconBadge));
      expect(badge.variant, PremiumBadgeVariant.large);
      expect(
        tester.widget<OperonixPremiumIcon>(find.byType(OperonixPremiumIcon)).glyph,
        OperonixPremiumGlyph.productionOrder,
      );
      expect(find.byIcon(Icons.assignment), findsNothing);
    });

    testWidgets('classic evidence card is unchanged', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductionEvidenceListCard(
              title: 'Doziranje hemikalija',
              subtitle: 'Profil\nPogon: BR',
              icon: Icons.science_outlined,
              profileKey: 'chemical_dosing',
              infoAction: Icon(Icons.info_outline),
            ),
          ),
        ),
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);
      expect(find.byType(OperonixPremiumIcon), findsNothing);
    });
  });
}
