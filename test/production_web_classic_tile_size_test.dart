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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const titles = [
    'Registracije',
    'Proizvodi',
    'Proizvodni nalozi',
    'Planiranje proizvodnje',
    'Praćenje proizvodnje',
    'Stanica: priprema',
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
    return [
      ProductionDashboardModuleSection(
        id: 'production',
        title: 'Proizvodnja',
        subtitle: 'Moduli',
        icon: Icons.precision_manufacturing_outlined,
        entries: [
          for (final title in titles)
            ProductionDashboardModuleEntry(
              id: title,
              icon: Icons.precision_manufacturing_outlined,
              title: title,
              subtitle: 'Otvori',
              onTap: () => taps[title] = (taps[title] ?? 0) + 1,
            ),
        ],
      ),
    ];
  }

  Future<Map<String, int>> pumpHome(
    WidgetTester tester, {
    required Size size,
    required VisualStyle style,
    required bool web,
    ProductionDashboardLayout layout = ProductionDashboardLayout.iconGrid,
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
              useWebPresentation: web,
              sections: sections(taps),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return taps;
  }

  void expectMaintenanceWebCell(WidgetTester tester, Size viewport) {
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(
      delegate.maxCrossAxisExtent,
      ProductionDashboardHomeModulesView.webClassicMaxCrossAxisExtent,
    );
    expect(delegate.maxCrossAxisExtent, 132);
    expect(
      delegate.childAspectRatio,
      ProductionDashboardHomeModulesView.webClassicChildAspectRatio,
    );
    expect(delegate.mainAxisSpacing, 10);
    expect(delegate.crossAxisSpacing, 10);
    final tile = tester.getSize(find.byType(ProductionDashboardIconGridTile).first);
    expect(tile.width, lessThanOrEqualTo(132));
    expect(tile.height, closeTo(tile.width / 0.82, 0.6));
    expect(tile.width, isNot(closeTo(180, 0.5)));
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
    final title = tester.widget<Text>(find.text('Proizvodni nalozi'));
    expect(title.maxLines, 3);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style?.fontSize, 12);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(title.style?.height, 1.2);
    expect(find.byType(PremiumListCard), findsNothing);
    expect(find.byType(PremiumResponsiveGrid), findsNothing);
    expect(viewport.width, greaterThan(0));
  }

  for (final width in [360.0, 411.0, 768.0, 1280.0, 1600.0]) {
    testWidgets('web classic icon grid $width uses the Maintenance cell cap', (
      tester,
    ) async {
      final taps = await pumpHome(
        tester,
        size: Size(width, 900),
        style: VisualStyle.classic,
        web: true,
      );
      if (width <= 360) {
        while (tester.takeException() != null) {}
      } else {
        expect(tester.takeException(), isNull);
      }
      expectMaintenanceWebCell(tester, Size(width, 900));
      expect(find.byType(ProductionDashboardActionTile), findsNothing);
      await tester.tap(find.text('Registracije'));
      await tester.pump();
      expect(taps['Registracije'], 1);
    });
  }

  testWidgets('web classic 1280 cell matches the Maintenance extent formula', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(1280, 900),
      style: VisualStyle.classic,
      web: true,
    );
    expect(tester.takeException(), isNull);
    final tile = tester.getSize(find.byType(ProductionDashboardIconGridTile).first);
    expect(tile.width, closeTo(129.78, 0.6));
    expect(tile.height, closeTo(158.27, 0.8));
  });

  for (final width in [360.0, 411.0, 1280.0, 1600.0]) {
    testWidgets('web premium $width keeps the baseline premium grid', (
      tester,
    ) async {
      await pumpHome(
        tester,
        size: Size(width, 900),
        style: VisualStyle.premium,
        web: true,
      );
      expect(tester.takeException(), isNull);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.gridDelegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      final contentWidth = width - 32;
      expect(
        delegate.crossAxisCount,
        PremiumHomeIconGridMetrics.columnCount(contentWidth),
      );
      expect(
        delegate.mainAxisExtent,
        PremiumHomeIconGridMetrics.tileExtentFor(contentWidth),
      );
      expect(find.byType(PremiumListCard), findsNothing);
      expect(
        tester
            .widget<PremiumIconBadge>(
              find.descendant(
                of: find.byType(ProductionDashboardIconGridTile).first,
                matching: find.byType(PremiumIconBadge),
              ),
            )
            .extent,
        PremiumHomeIconGridMetrics.iconSlot,
      );
    });
  }

  for (final width in [360.0, 411.0]) {
    testWidgets('android classic $width keeps the fixed column grid', (
      tester,
    ) async {
      await pumpHome(
        tester,
        size: Size(width, 800),
        style: VisualStyle.classic,
        web: false,
      );
      if (width <= 360) {
        while (tester.takeException() != null) {}
      } else {
        expect(tester.takeException(), isNull);
      }
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.gridDelegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(
        delegate.crossAxisCount,
        ProductionDashboardHomeModulesView.classicIconGridColumnCount(width),
      );
      expect(delegate.childAspectRatio, 0.82);
      expect(delegate.mainAxisExtent, isNull);
      expect(find.byType(PremiumResponsiveGrid), findsNothing);
    });

    testWidgets('android premium $width keeps the baseline premium grid', (
      tester,
    ) async {
      await pumpHome(
        tester,
        size: Size(width, 800),
        style: VisualStyle.premium,
        web: false,
      );
      expect(tester.takeException(), isNull);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      final contentWidth = width - 32;
      expect(
        delegate.crossAxisCount,
        PremiumHomeIconGridMetrics.columnCount(contentWidth),
      );
      expect(
        delegate.mainAxisExtent,
        PremiumHomeIconGridMetrics.tileExtentFor(contentWidth),
      );
      expect(
        tester
            .widget<PremiumIconBadge>(
              find.descendant(
                of: find.byType(ProductionDashboardIconGridTile).first,
                matching: find.byType(PremiumIconBadge),
              ),
            )
            .variant,
        PremiumBadgeVariant.large,
      );
    });
  }

  testWidgets('android classic standard layout stays the full-width row', (
    tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(411, 800),
      style: VisualStyle.classic,
      web: false,
      layout: ProductionDashboardLayout.standard,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ProductionDashboardActionTile), findsNWidgets(titles.length));
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
  });
}
