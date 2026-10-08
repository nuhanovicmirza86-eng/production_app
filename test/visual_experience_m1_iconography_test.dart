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
import 'package:production_app/modules/production/dashboard/widgets/premium_home_icon_grid_metrics.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart';
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
      expect(badge.variant, PremiumBadgeVariant.medium);
      expect(badge.extent, ProductionDashboardActionTile.iconExtent);
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
        PremiumHomeIconGridMetrics.gap,
        ProductionDashboardHomeModulesView.tileGap,
      );
      expect(PremiumHomeIconGridMetrics.iconSlot, 60);
      expect(PremiumHomeIconGridMetrics.tileExtentFor(phoneContent), lessThan(152));
      expect(PremiumHomeIconGridMetrics.titleMaxLines(phoneContent), 3);
      expect(PremiumHomeIconGridMetrics.titleMaxLines(411 - 32), 2);
      expect(
        PremiumHomeIconGridMetrics.tileExtentFor(411 - 32),
        lessThan(PremiumHomeIconGridMetrics.tileExtentFor(phoneContent)),
      );
      expect(PremiumHomeIconGridMetrics.tileExtentFor(1100), lessThanOrEqualTo(140));
      expect(ProductionDashboardHomeModulesView.tileWidthFor(300), 300);
      expect(ProductionDashboardHomeModulesView.tileWidthFor(360), 320);
      expect(ProductionDashboardHomeModulesView.tileWidthFor(1280), 320);
      expect(ProductionDashboardHomeModulesView.maxTileWidth, 320);
    });

    testWidgets('phone Premium icon grid fits long module names', (tester) async {
      await _pumpIconHome(tester, width: 360, premium: true);
      expect(tester.takeException(), isNull);
      final tile = tester.getSize(find.byType(ProductionDashboardActionTile).first);
      expect(tile.width, ProductionDashboardHomeModulesView.tileWidthFor(360 - 32));
      expect(tile.height, lessThan(110));
      expect(find.byType(GridView), findsNothing);
      final badge = tester.widget<PremiumIconBadge>(
        find.descendant(
          of: find.byType(ProductionDashboardActionTile).first,
          matching: find.byType(PremiumIconBadge),
        ),
      );
      expect(badge.extent, ProductionDashboardActionTile.iconExtent);
      for (final label in _longHomeLabels) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.maxLines, 2);
        expect(text.style?.fontSize, 15);
        expect(text.style?.color, OperonixVisualTokens.midnight().primaryText);
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
        final tile = tester.getSize(find.byType(ProductionDashboardActionTile).first);
        expect(
          tile.width,
          ProductionDashboardHomeModulesView.tileWidthFor(width - 32),
          reason: 'width $width',
        );
        expect(tile.height, lessThan(110), reason: 'width $width');
        expect(find.byType(GridView), findsNothing, reason: 'width $width');
        for (final label in _longHomeLabels) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 2, reason: 'width $width');
          expect(text.style?.fontSize, 15, reason: 'width $width');
        }
      }
    });

    testWidgets('Classic icon grid stays on Material icons', (tester) async {
      await _pumpIconHome(tester, width: 400, premium: false);
      expect(tester.takeException(), isNull);
      expect(find.byType(OperonixPremiumIcon), findsNothing);
      expect(find.byIcon(Icons.display_settings_outlined), findsWidgets);
      final card = tester.widget<Card>(find.byType(Card).first);
      final side = (card.shape! as RoundedRectangleBorder).side;
      expect(side.width, greaterThan(1));
      expect(
        tester.getSize(find.byType(ProductionDashboardActionTile).first).width,
        ProductionDashboardHomeModulesView.tileWidthFor(400 - 32),
      );
      expect(
        tester.getSize(find.byType(ProductionDashboardActionTile).first).height,
        lessThan(110),
      );
    });

    test('home business concepts map to distinct pictograms', () {
      final glyphs = [
        for (final title in _homePictogramTitles)
          OperonixPremiumIconography.forTitle(title),
      ];
      expect(glyphs, everyElement(isNotNull));
      expect(glyphs.toSet().length, _homePictogramTitles.length);
      expect(glyphs, isNot(contains(OperonixPremiumGlyph.station)));
    });

    testWidgets('premium icon spot has no outline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: const Scaffold(
            body: PremiumIconBadge(
              glyph: OperonixPremiumGlyph.products,
              role: PremiumIconRole.success,
              variant: PremiumBadgeVariant.large,
            ),
          ),
        ),
      );
      final badge = tester.widget<PremiumIconBadge>(find.byType(PremiumIconBadge));
      expect(badge.extent, inInclusiveRange(48, 64));
      final spot = tester.widget<Container>(
        find.descendant(
          of: find.byType(PremiumIconBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = spot.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      final mark = tester.widget<OperonixPremiumIcon>(find.byType(OperonixPremiumIcon));
      expect(mark.size, greaterThanOrEqualTo(46));
      expect(tester.takeException(), isNull);
    });

    testWidgets('premium home tile drops the double box', (tester) async {
      await _pumpIconHome(tester, width: 360, premium: true);
      final card = tester.widget<Card>(find.byType(Card).first);
      expect(
        (card.shape! as RoundedRectangleBorder).side.width,
        OperonixVisualTokens.midnight().cardBorderWidth,
      );
      final spot = tester.widget<Container>(
        find.descendant(
          of: find.byType(PremiumIconBadge).first,
          matching: find.byType(Container),
        ).first,
      );
      expect((spot.decoration! as BoxDecoration).border, isNull);
      final text = tester.widget<Text>(find.text('Način rada na ovom uređaju'));
      expect(text.textAlign, anyOf(isNull, TextAlign.start));
      expect(text.style?.color, OperonixVisualTokens.midnight().primaryText);
    });

    testWidgets('home pictograms differ by shape in one color', (tester) async {
      final glyphs = [
        for (final title in _homePictogramTitles)
          OperonixPremiumIconography.forTitle(title)!,
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Wrap(
            children: [
              for (final glyph in glyphs)
                RepaintBoundary(
                  key: ValueKey(glyph),
                  child: OperonixPremiumIcon(
                    glyph: glyph,
                    size: 48,
                    color: const Color(0xFF222222),
                  ),
                ),
            ],
          ),
        ),
      );
      final signatures = <int>{};
      await tester.runAsync(() async {
        for (final glyph in glyphs) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(ValueKey(glyph)),
          );
          final image = await boundary.toImage();
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          var hash = 0;
          for (final byte in bytes) {
            hash = (hash * 31 + byte) & 0x7fffffff;
          }
          signatures.add(hash);
        }
      });
      expect(signatures.length, glyphs.length);
    });

    testWidgets('Registracije uses the same compact Premium card', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ProductionDashboardModuleEntry entry(String id, String title) {
        return ProductionDashboardModuleEntry(
          id: id,
          icon: Icons.person_add_alt_1,
          title: title,
          subtitle: 'Opis',
          onTap: () {},
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.premiumMidnight(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProductionDashboardHomeModulesView(
                  layout: ProductionDashboardLayout.iconGrid,
                  access: ProductionDashboardAccess(
                    companyData: const {},
                    role: 'admin',
                    companyId: 'c',
                    plantKey: 'p',
                    enabledModules: const ['production'],
                  ),
                  sections: [
                    ProductionDashboardModuleSection(
                      id: 'users',
                      title: 'Korisnici',
                      subtitle: 'Računi',
                      icon: Icons.manage_accounts_outlined,
                      entries: [entry('users.registrations', 'Registracije')],
                    ),
                    ProductionDashboardModuleSection(
                      id: 'production',
                      title: 'Proizvodnja',
                      subtitle: 'Moduli',
                      icon: Icons.precision_manufacturing_outlined,
                      entries: [
                        entry('production.orders', 'Proizvodni nalozi'),
                      ],
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
      final tiles = tester.getSize(find.byType(ProductionDashboardActionTile).at(0));
      final orders = tester.getSize(find.byType(ProductionDashboardActionTile).at(1));
      expect(tiles.width, orders.width);
      expect(tiles.height, lessThan(110));
      expect(orders.height, lessThan(110));
      expect(tiles.width, ProductionDashboardHomeModulesView.maxTileWidth);
      expect(tiles.width, lessThan(411 - 32));
      expect(tiles.height, lessThan(110));
      expect(find.text('Registracije'), findsOneWidget);
      expect(
        tester
            .widget<PremiumIconBadge>(
              find.descendant(
                of: find.byType(ProductionDashboardActionTile).first,
                matching: find.byType(PremiumIconBadge),
              ),
            )
            .extent,
        ProductionDashboardActionTile.iconExtent,
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

const _homePictogramTitles = [
  'Način rada na ovom uređaju',
  'Proizvodi',
  'Proizvodni nalozi',
  'Planiranje proizvodnje',
  'Praćenje proizvodnje (tabovi)',
  'Stanica: pripremna',
  'Stanica: prva kontrola',
  'Stanica: završna kontrola',
  'Operativne stanice (profil)',
  'Operativne evidencije',
  'Moje otvorene akcije',
  'Evidencije procesa',
];

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
