import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_module.dart';
import 'package:production_app/modules/production/dashboard/production_dashboard_access.dart';
import 'package:production_app/modules/production/dashboard/widgets/premium_home_icon_grid_metrics.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_icon_grid_tile.dart';

/// Locks Production Home to the accepted presentation at 6dde899.
/// The same widgets render on web, Android, and iOS. Width only changes
/// the baseline column counts that already existed then.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const titles = [
    'Registracije',
    'Način rada na ovom uređaju',
    'Proizvodi',
    'Proizvodni nalozi',
    'Planiranje proizvodnje',
    'Praćenje proizvodnje',
    'Stanica: priprema',
  ];

  const viewports = <Size>[
    Size(360, 800),
    Size(411, 800),
    Size(768, 1024),
    Size(1280, 800),
    Size(1600, 900),
  ];

  ProductionDashboardAccess access() {
    return ProductionDashboardAccess(
      companyData: const {'role': 'admin'},
      role: 'admin',
      companyId: 'c',
      plantKey: 'p',
      enabledModules: const ['production'],
    );
  }

  List<ProductionDashboardModuleSection> sections(Map<String, int> taps) {
    ProductionDashboardModuleEntry entry(String id, String title) {
      return ProductionDashboardModuleEntry(
        id: id,
        icon: Icons.precision_manufacturing_outlined,
        title: title,
        subtitle: 'Otvori',
        onTap: () => taps[title] = (taps[title] ?? 0) + 1,
      );
    }

    return [
      ProductionDashboardModuleSection(
        id: 'users',
        title: 'Korisnici',
        subtitle: 'Računi',
        icon: Icons.manage_accounts_outlined,
        entries: [entry('users.registrations', titles.first)],
      ),
      ProductionDashboardModuleSection(
        id: 'production',
        title: 'Proizvodnja',
        subtitle: 'Moduli',
        icon: Icons.precision_manufacturing_outlined,
        entries: [
          for (var i = 1; i < titles.length; i++) entry('production.$i', titles[i]),
        ],
      ),
    ];
  }

  Future<Map<String, int>> pumpHome(
    WidgetTester tester, {
    required Size size,
    required VisualStyle style,
    required ProductionDashboardLayout layout,
  }) async {
    final taps = <String, int>{};
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.forStyle(style),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ProductionDashboardHomeModulesView(
              layout: layout,
              access: access(),
              sections: sections(taps),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return taps;
  }

  test('experimental quick-action presentation is absent', () {
    final widgets = Directory(
      'lib/modules/production/dashboard/widgets',
    ).listSync().map((entity) => entity.uri.pathSegments.last).toList();
    expect(widgets, isNot(contains('production_classic_action_tile.dart')));
    expect(widgets, isNot(contains('production_web_premium_action_tile.dart')));
    final home = File(
      'lib/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart',
    ).readAsStringSync();
    expect(home.contains('kIsWeb'), isFalse);
    expect(home.contains('useWebPresentation'), isFalse);
    expect(home.contains('maxTileWidth'), isFalse);
    expect(home.contains('tileWidthFor'), isFalse);
    expect(home.contains('maxCrossAxisExtent'), isFalse);
    expect(home.contains('_WebClassicView'), isFalse);
    expect(home.contains('_WebPremiumView'), isFalse);
    expect(ProductionDashboardHomeModulesView.tileGap, 10);
    expect(ProductionDashboardHomeModulesView.sectionGap, 18);
    expect(ProductionDashboardHomeModulesView.afterHeader, 8);
  });

  for (final size in viewports) {
    final label = size.width.toInt();

    testWidgets('classic standard $label uses the full-width action row', (
      tester,
    ) async {
      final taps = await pumpHome(
        tester,
        size: size,
        style: VisualStyle.classic,
        layout: ProductionDashboardLayout.standard,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProductionDashboardActionTile),
        findsNWidgets(titles.length),
      );
      expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
      expect(find.byType(PremiumListCard), findsNothing);
      expect(find.byType(PremiumResponsiveGrid), findsNothing);
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(Wrap), findsNothing);
      final tile = tester.getSize(find.byType(ProductionDashboardActionTile).first);
      expect(tile.width, closeTo(size.width - 32, 1));
      expect(tile.height, lessThan(160));
      final box = tester.getSize(
        find.descendant(
          of: find.byType(ProductionDashboardActionTile).first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 46 &&
                widget.constraints?.maxHeight == 46,
          ),
        ),
      );
      expect(box, const Size(46, 46));
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(ProductionDashboardActionTile).first,
          matching: find.byIcon(Icons.precision_manufacturing_outlined),
        ),
      );
      expect(icon.size, isNull);
      final title = tester.widget<Text>(find.text('Registracije').first);
      expect(title.style?.fontSize, 15);
      expect(title.style?.fontWeight, FontWeight.w900);
      expect(title.maxLines, isNull);
      expect(find.text('Otvori'), findsNWidgets(titles.length));
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(titles.length));
      await tester.tap(find.text('Registracije'));
      await tester.pump();
      expect(taps['Registracije'], 1);
    });

    testWidgets('premium standard $label uses PremiumListCard geometry', (
      tester,
    ) async {
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.premium,
        layout: ProductionDashboardLayout.standard,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PremiumListCard), findsNWidgets(titles.length));
      expect(find.byType(PremiumResponsiveGrid), findsOneWidget);
      expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
      expect(find.byType(GridView), findsNothing);
      final contentWidth = size.width - 32;
      final single = tester.getSize(find.byType(PremiumListCard).first);
      expect(single.width, closeTo(contentWidth, 1));
      final badge = tester.widget<PremiumIconBadge>(
        find.descendant(
          of: find.byType(PremiumListCard).first,
          matching: find.byType(PremiumIconBadge),
        ),
      );
      expect(badge.variant, PremiumBadgeVariant.large);
      expect(badge.extent, 60);
      final grouped = tester.getSize(find.byType(PremiumListCard).at(1));
      if (contentWidth < 720) {
        expect(grouped.width, closeTo(contentWidth, 1));
      } else {
        final cols = contentWidth >= 1100 ? 3 : 2;
        final width = (contentWidth - 12 * (cols - 1)) / cols;
        expect(grouped.width, closeTo(width, 1));
      }
      expect(find.text('Otvori'), findsWidgets);
    });

    testWidgets('classic icon grid $label keeps the baseline columns', (
      tester,
    ) async {
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.classic,
        layout: ProductionDashboardLayout.iconGrid,
      );
      if (size.width <= 360) {
        while (tester.takeException() != null) {}
      } else {
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byType(ProductionDashboardIconGridTile),
        findsNWidgets(titles.length),
      );
      expect(find.byType(ProductionDashboardActionTile), findsNothing);
      expect(find.byType(PremiumListCard), findsNothing);
      expect(find.byType(PremiumResponsiveGrid), findsNothing);
      final grids = tester.widgetList<GridView>(find.byType(GridView));
      expect(grids.length, 2);
      for (final grid in grids) {
        final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          ProductionDashboardHomeModulesView.classicIconGridColumnCount(size.width),
        );
        expect(delegate.childAspectRatio, 0.82);
        expect(delegate.mainAxisExtent, isNull);
        expect(delegate.mainAxisSpacing, 10);
        expect(delegate.crossAxisSpacing, 10);
      }
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(ProductionDashboardIconGridTile).first,
          matching: find.byType(Icon),
        ),
      );
      expect(icon.size, 28);
      final box = tester.getSize(
        find.descendant(
          of: find.byType(ProductionDashboardIconGridTile).first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxWidth == 52 &&
                widget.constraints?.maxHeight == 52,
          ),
        ),
      );
      expect(box, const Size(52, 52));
      final title = tester.widget<Text>(find.text('Registracije').first);
      expect(title.textAlign, TextAlign.center);
      expect(title.maxLines, 3);
      expect(title.style?.fontSize, 12);
      expect(title.style?.fontWeight, FontWeight.w800);
      expect(title.style?.height, 1.2);
    });

    testWidgets('premium icon grid $label keeps baseline metrics', (tester) async {
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.premium,
        layout: ProductionDashboardLayout.iconGrid,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ProductionDashboardIconGridTile),
        findsNWidgets(titles.length),
      );
      expect(find.byType(ProductionDashboardActionTile), findsNothing);
      expect(find.byType(PremiumListCard), findsNothing);
      final contentWidth = size.width - 32;
      final grids = tester.widgetList<GridView>(find.byType(GridView));
      expect(grids.length, 2);
      for (final grid in grids) {
        final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          PremiumHomeIconGridMetrics.columnCount(contentWidth),
        );
        expect(
          delegate.mainAxisExtent,
          PremiumHomeIconGridMetrics.tileExtentFor(contentWidth),
        );
        expect(delegate.mainAxisSpacing, PremiumHomeIconGridMetrics.gap);
        expect(delegate.crossAxisSpacing, PremiumHomeIconGridMetrics.gap);
      }
      final tile = tester.getSize(find.byType(ProductionDashboardIconGridTile).first);
      expect(tile.width, greaterThanOrEqualTo(PremiumHomeIconGridMetrics.minTileWidth));
      expect(tile.height, PremiumHomeIconGridMetrics.tileExtentFor(contentWidth));
      final badge = tester.widget<PremiumIconBadge>(
        find.descendant(
          of: find.byType(ProductionDashboardIconGridTile).first,
          matching: find.byType(PremiumIconBadge),
        ),
      );
      expect(badge.variant, PremiumBadgeVariant.large);
      expect(badge.extent, PremiumHomeIconGridMetrics.iconSlot);
    });
  }
}
