import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_module.dart';
import 'package:production_app/modules/production/dashboard/production_dashboard_access.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_classic_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_icon_grid_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_web_premium_action_tile.dart';

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

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    required VisualStyle style,
    required bool web,
    ProductionDashboardLayout layout = ProductionDashboardLayout.standard,
    Map<String, int>? taps,
  }) async {
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
              sections: sections(taps ?? {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void expectAndroidClassic(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    expect(find.byType(ProductionDashboardActionTile), findsNWidgets(titles.length));
    expect(find.byType(ProductionClassicActionTile), findsNothing);
    expect(find.byType(ProductionWebPremiumActionTile), findsNothing);
    expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
    expect(find.text('Otvori'), findsNWidgets(titles.length));
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(titles.length));
    final tile = tester.getSize(find.byType(ProductionDashboardActionTile).first);
    expect(tile.width, greaterThan(ProductionClassicActionTile.maxCrossAxisExtent));
    expect(tile.height, lessThan(120));
  }

  void expectAndroidPremium(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    expect(find.byType(PremiumListCard), findsNWidgets(titles.length));
    expect(find.byType(PremiumResponsiveGrid), findsOneWidget);
    expect(find.byType(ProductionClassicActionTile), findsNothing);
    expect(find.byType(ProductionWebPremiumActionTile), findsNothing);
    expect(
      tester
          .widget<PremiumIconBadge>(
            find.descendant(
              of: find.byType(PremiumListCard).first,
              matching: find.byType(PremiumIconBadge),
            ),
          )
          .variant,
      PremiumBadgeVariant.large,
    );
  }

  void expectWebClassic(WidgetTester tester, Size size) {
    expect(tester.takeException(), isNull);
    expect(find.byType(ProductionClassicActionTile), findsNWidgets(titles.length));
    expect(find.byType(ProductionDashboardActionTile), findsNothing);
    expect(find.byType(ProductionWebPremiumActionTile), findsNothing);
    expect(find.text('Otvori'), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, 132);
    expect(delegate.childAspectRatio, 0.82);
    expect(delegate.mainAxisSpacing, 10);
    expect(delegate.crossAxisSpacing, 10);
    final tile = tester.getSize(find.byType(ProductionClassicActionTile).first);
    expect(tile.width, lessThanOrEqualTo(132));
    expect(tile.width, isNot(180));
    expect(tile.height, closeTo(tile.width / 0.82, 1));
    expect(tile.width, lessThan(size.width - 32));
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(ProductionClassicActionTile).first,
        matching: find.byIcon(Icons.precision_manufacturing_outlined),
      ),
    );
    expect(icon.size, 28);
    expect(icon.color, OperonixVisualTokens.classic().moduleAccent);
    final box = tester.getSize(
      find.descendant(
        of: find.byType(ProductionClassicActionTile).first,
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.child is Icon,
        ),
      ),
    );
    expect(box.width, 52);
    expect(box.height, 52);
    final text = tester.widget<Text>(find.text('Registracije'));
    expect(text.textAlign, TextAlign.center);
    expect(text.maxLines, 2);
    expect(text.style?.fontSize, 12);
    expect(text.style?.fontWeight, FontWeight.w800);
    expect(text.style?.height, 1.2);
    final iconRect = tester.getRect(
      find.descendant(
        of: find.byType(ProductionClassicActionTile).first,
        matching: find.byIcon(Icons.precision_manufacturing_outlined),
      ),
    );
    final titleRect = tester.getRect(find.text('Registracije'));
    expect(iconRect.bottom, lessThan(titleRect.top));
  }

  for (final size in const [Size(360, 800), Size(411, 900)]) {
    testWidgets('Android Classic ${size.width} uses the pre-hotfix row', (tester) async {
      final taps = <String, int>{};
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.classic,
        web: false,
        taps: taps,
      );
      expectAndroidClassic(tester);
      await tester.tap(find.text('Registracije'));
      await tester.pump();
      expect(taps['Registracije'], 1);
      expect(taps.containsKey('Proizvodi'), isFalse);
    });

    testWidgets('Android Premium ${size.width} uses the pre-hotfix cards', (tester) async {
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.premium,
        web: false,
      );
      expectAndroidPremium(tester);
    });

    testWidgets('Android Classic icon grid ${size.width} stays on the mobile grid', (
      tester,
    ) async {
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.classic,
        web: false,
        layout: ProductionDashboardLayout.iconGrid,
      );
      while (tester.takeException() != null) {}
      expect(find.byType(ProductionDashboardIconGridTile), findsNWidgets(titles.length));
      expect(find.byType(ProductionClassicActionTile), findsNothing);
      expect(find.byType(ProductionWebPremiumActionTile), findsNothing);
      final grid = tester.widget<GridView>(find.byType(GridView).first);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(
        delegate.crossAxisCount,
        ProductionDashboardHomeModulesView.classicIconGridColumnCount(size.width),
      );
      expect(delegate.childAspectRatio, 0.82);
    });
  }

  for (final size in const [
    Size(360, 800),
    Size(411, 900),
    Size(768, 1024),
    Size(1280, 800),
    Size(1600, 900),
  ]) {
    testWidgets('Web Classic ${size.width} uses the Maintenance tile grid', (tester) async {
      final taps = <String, int>{};
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.classic,
        web: true,
        taps: taps,
      );
      expectWebClassic(tester, size);
      await tester.tap(find.text('Proizvodni nalozi'));
      await tester.pump();
      expect(taps['Proizvodni nalozi'], 1);
      expect(taps['Registracije'], isNull);
    });

    testWidgets('Web Premium ${size.width} keeps the compact row', (tester) async {
      await pumpHome(
        tester,
        size: size,
        style: VisualStyle.premium,
        web: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductionWebPremiumActionTile), findsNWidgets(titles.length));
      expect(find.byType(ProductionClassicActionTile), findsNothing);
      expect(find.byType(ProductionDashboardActionTile), findsNothing);
      expect(find.byType(GridView), findsNothing);
      final tile = tester.getSize(find.byType(ProductionWebPremiumActionTile).first);
      expect(
        tile.width,
        ProductionDashboardHomeModulesView.tileWidthFor(size.width - 32),
      );
      expect(tile.height, lessThan(110));
      expect(find.text('Otvori'), findsWidgets);
    });
  }

  testWidgets('Web Classic long titles stay inside the Maintenance cell', (tester) async {
    await pumpHome(
      tester,
      size: const Size(1280, 900),
      style: VisualStyle.classic,
      web: true,
    );
    final exceeded = <String>[];
    for (final title in titles) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.size.width, lessThanOrEqualTo(132));
      if (paragraph.didExceedMaxLines) exceeded.add(title);
    }
    expect(tester.takeException(), isNull);
    expect(exceeded, [
      'Način rada na ovom uređaju',
      'Proizvodni nalozi',
      'Planiranje proizvodnje',
      'Praćenje proizvodnje',
    ]);
  });
}
