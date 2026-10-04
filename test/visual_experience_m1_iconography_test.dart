import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/operonix_premium_icon.dart';
import 'package:production_app/core/visual/premium/operonix_premium_iconography.dart';
import 'package:production_app/core/visual/premium/premium_icon_accent.dart';
import 'package:production_app/core/visual/premium/premium_station_palette.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_module.dart';
import 'package:production_app/modules/production/dashboard/production_dashboard_access.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_icon_grid_tile.dart';
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

    test('station business glyphs stay distinct from each other', () {
      final glyphs = [
        OperonixPremiumIconography.forTitle('Način rada na ovom uređaju'),
        OperonixPremiumIconography.forTitle('Stanica: pripremna'),
        OperonixPremiumIconography.forTitle('Stanica: prva kontrola'),
        OperonixPremiumIconography.forTitle('Stanica: završna kontrola'),
        OperonixPremiumIconography.forTitle('Operativne stanice (profil)'),
      ];
      expect(glyphs.toSet().length, glyphs.length);
      expect(glyphs, isNot(contains(OperonixPremiumGlyph.station)));
      expect(
        OperonixPremiumIconography.forTitle('Proizvodi'),
        OperonixPremiumGlyph.products,
      );
      expect(
        OperonixPremiumIconography.forTitle('Proizvodni nalozi'),
        OperonixPremiumGlyph.productionOrder,
      );
      expect(
        OperonixPremiumIconography.forTitle('Planiranje proizvodnje'),
        OperonixPremiumGlyph.planningFlow,
      );
      expect(
        OperonixPremiumIconography.forTitle('Praćenje proizvodnje (tabovi)'),
        OperonixPremiumGlyph.liveTracking,
      );
      expect(
        OperonixPremiumIconography.forTitle('Moje otvorene akcije'),
        OperonixPremiumGlyph.openActions,
      );
      expect(
        OperonixPremiumIconography.forTitle('Evidencije procesa'),
        OperonixPremiumGlyph.processCheck,
      );
    });

    test('Premium phone grid uses width, Classic keeps three columns', () {
      const phoneContent = 360 - 32.0;
      expect(PremiumHomeIconGridMetrics.columnCount(phoneContent), 2);
      expect(PremiumHomeIconGridMetrics.columnCount(411 - 32), 2);
      expect(
        PremiumHomeIconGridMetrics.tileWidth(phoneContent),
        greaterThanOrEqualTo(PremiumHomeIconGridMetrics.minTileWidth),
      );
      expect(PremiumHomeIconGridMetrics.columnCount(568), greaterThanOrEqualTo(3));
      expect(PremiumHomeIconGridMetrics.columnCount(1100), greaterThanOrEqualTo(4));
      expect(
        ProductionDashboardHomeModulesView.classicIconGridColumnCount(360),
        3,
      );
      expect(
        ProductionDashboardHomeModulesView.classicIconGridColumnCount(400),
        3,
      );
      expect(
        ProductionDashboardHomeModulesView.classicIconGridColumnCount(900),
        5,
      );
    });

    testWidgets('phone Premium icon grid fits long module names', (tester) async {
      await _pumpIconHome(tester, width: 360, premium: true);
      expect(tester.takeException(), isNull);
      final tile = tester.getSize(find.byType(ProductionDashboardIconGridTile).first);
      expect(tile.width, greaterThanOrEqualTo(150));
      expect(tile.height, PremiumHomeIconGridMetrics.tileExtent);
      expect(find.byType(GridView), findsOneWidget);
      for (final label in _longHomeLabels) {
        final text = tester.widget<Text>(find.text(label));
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
        expect(text.maxLines, 3);
        expect(text.style?.fontSize, 14);
        expect(paragraph.size.height, lessThan(tile.height * 0.55));
      }
      final glyphs = tester
          .widgetList<OperonixPremiumIcon>(find.byType(OperonixPremiumIcon))
          .map((icon) => icon.glyph)
          .toList();
      expect(glyphs.toSet().length, glyphs.length);
      expect(glyphs, contains(OperonixPremiumGlyph.deviceWorkMode));
      expect(glyphs, contains(OperonixPremiumGlyph.stationPreparation));
      expect(glyphs, contains(OperonixPremiumGlyph.stationFirstControl));
      expect(glyphs, contains(OperonixPremiumGlyph.stationFinalControl));
      expect(glyphs, contains(OperonixPremiumGlyph.stationNetwork));
      expect(glyphs, isNot(contains(OperonixPremiumGlyph.station)));
    });

    testWidgets('large phone and tablet Premium grids stay inside the tile', (
      tester,
    ) async {
      for (final width in [411.0, 800.0]) {
        await _pumpIconHome(tester, width: width, premium: true);
        expect(tester.takeException(), isNull, reason: 'width $width');
        final tile = tester.getSize(find.byType(ProductionDashboardIconGridTile).first);
        expect(tile.width, greaterThanOrEqualTo(150), reason: 'width $width');
        for (final label in _longHomeLabels) {
          final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
          expect(paragraph.size.height, lessThan(tile.height * 0.55));
        }
      }
    });

    testWidgets('Classic icon grid stays on Material icons', (tester) async {
      await _pumpIconHome(tester, width: 400, premium: false);
      expect(tester.takeException(), isNull);
      expect(find.byType(OperonixPremiumIcon), findsNothing);
      expect(find.byIcon(Icons.display_settings_outlined), findsWidgets);
      expect(
        ProductionDashboardHomeModulesView.classicIconGridColumnCount(400),
        3,
      );
    });

    testWidgets('Standardno stays a list when Premium is on', (tester) async {
      await _pumpIconHome(
        tester,
        width: 360,
        premium: true,
        layout: ProductionDashboardLayout.standard,
      );
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ProductionDashboardActionTile), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

const _longHomeLabels = [
  'Način rada na ovom uređaju',
  'Praćenje proizvodnje (tabovi)',
  'Stanica: pripremna',
  'Stanica: prva kontrola',
  'Stanica: završna kontrola',
  'Operativne stanice (profil)',
  'Operativne evidencije',
];

Future<void> _pumpIconHome(
  WidgetTester tester, {
  required double width,
  required bool premium,
  ProductionDashboardLayout layout = ProductionDashboardLayout.iconGrid,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final entries = [
    for (var i = 0; i < _longHomeLabels.length; i++)
      ProductionDashboardModuleEntry(
        id: 'home.$i',
        icon: Icons.display_settings_outlined,
        title: _longHomeLabels[i],
        subtitle: 'Opis',
        onTap: () {},
      ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      theme: premium
          ? OperonixVisualTheme.premiumMidnight()
          : OperonixVisualTheme.classic(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProductionDashboardHomeModulesView(
              layout: layout,
              access: ProductionDashboardAccess(
                companyData: const {},
                role: 'admin',
                companyId: 'c',
                plantKey: 'p',
                enabledModules: const ['production'],
              ),
              sections: [
                ProductionDashboardModuleSection(
                  id: 'production',
                  title: 'Proizvodnja',
                  subtitle: 'Moduli',
                  icon: Icons.precision_manufacturing_outlined,
                  entries: entries,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}
