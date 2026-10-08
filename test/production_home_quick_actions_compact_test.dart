import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_module.dart';
import 'package:production_app/modules/production/dashboard/production_dashboard_access.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_action_tile.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_home_modules_view.dart';
import 'package:production_app/modules/production/dashboard/widgets/production_dashboard_icon_grid_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const productionTitles = [
    'Način rada na ovom uređaju',
    'Proizvodi',
    'Proizvodni nalozi',
    'Planiranje proizvodnje',
    'Praćenje proizvodnje',
    'Stanica: priprema',
  ];

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    required VisualStyle style,
    required ProductionDashboardLayout layout,
    required Map<String, int> taps,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ProductionDashboardModuleEntry entry(String id, String title) {
      return ProductionDashboardModuleEntry(
        id: id,
        icon: Icons.precision_manufacturing_outlined,
        title: title,
        subtitle: 'Otvori',
        onTap: () => taps[title] = (taps[title] ?? 0) + 1,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.forStyle(style),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProductionDashboardHomeModulesView(
                layout: layout,
                access: ProductionDashboardAccess(
                  companyData: const {'role': 'admin'},
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
                    entries: [
                      entry('users.registrations', 'Registracije'),
                    ],
                  ),
                  ProductionDashboardModuleSection(
                    id: 'production',
                    title: 'Proizvodnja',
                    subtitle: 'Moduli',
                    icon: Icons.precision_manufacturing_outlined,
                    entries: [
                      for (var i = 0; i < productionTitles.length; i++)
                        entry('production.$i', productionTitles[i]),
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
  }

  void expectCompact(WidgetTester tester, Size size, VisualStyle style) {
    expect(tester.takeException(), isNull, reason: '${size.width} $style');
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ProductionDashboardIconGridTile), findsNothing);
    final tiles = find.byType(ProductionDashboardActionTile);
    expect(tiles, findsNWidgets(1 + productionTitles.length));

    final registration = tester.getSize(tiles.at(0));
    final orders = tester.getSize(find.text('Proizvodni nalozi'));
    final registrationCard = tester.getSize(tiles.at(0));
    final ordersCard = tester.getSize(
      find.ancestor(
        of: find.text('Proizvodni nalozi'),
        matching: find.byType(ProductionDashboardActionTile),
      ),
    );
    expect(registrationCard.width, registration.width);
    expect(ordersCard.width, registrationCard.width);
    expect(registrationCard.height, inInclusiveRange(44, 110));
    expect(ordersCard.height, inInclusiveRange(44, 110));
    expect(
      registrationCard.width,
      ProductionDashboardHomeModulesView.tileWidthFor(size.width - 32),
    );
    if (size.width >= 1280) {
      expect(registrationCard.width, lessThan(size.width * 0.4));
    }

    final tokens = style == VisualStyle.premium
        ? OperonixVisualTokens.midnight()
        : OperonixVisualTokens.classic();
    final title = tester.widget<Text>(find.text('Registracije'));
    expect(title.style?.color, tokens.primaryText);
    expect(title.style?.color, isNot(const Color(0xFF000000)));

    final icon = tester.getSize(
      find.descendant(
        of: tiles.first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == ProductionDashboardActionTile.iconExtent &&
              widget.height == ProductionDashboardActionTile.iconExtent,
        ),
      ),
    );
    expect(icon.width, inInclusiveRange(44, 48));
    expect(icon.height, inInclusiveRange(44, 48));

    if (style == VisualStyle.premium) {
      expect(
        tester
            .widget<PremiumIconBadge>(
              find.descendant(
                of: tiles.first,
                matching: find.byType(PremiumIconBadge),
              ),
            )
            .extent,
        ProductionDashboardActionTile.iconExtent,
      );
    }

    expect(orders.width, lessThan(ordersCard.width));
  }

  for (final layout in ProductionDashboardLayout.values) {
    for (final style in [VisualStyle.classic, VisualStyle.premium]) {
      for (final size in const [
        Size(360, 800),
        Size(411, 900),
        Size(768, 1024),
        Size(1280, 800),
        Size(1600, 900),
      ]) {
        testWidgets(
          '${layout.name} ${style.name} ${size.width} stays a compact action row',
          (tester) async {
            final taps = <String, int>{};
            await pumpHome(
              tester,
              size: size,
              style: style,
              layout: layout,
              taps: taps,
            );
            expectCompact(tester, size, style);

            await tester.tap(find.text('Registracije'));
            await tester.pump();
            expect(taps['Registracije'], 1);
            expect(taps['Proizvodni nalozi'], isNull);

            await tester.ensureVisible(find.text('Proizvodni nalozi'));
            await tester.pump();
            await tester.tap(find.text('Proizvodni nalozi'));
            await tester.pump();
            expect(taps['Proizvodni nalozi'], 1);
            expect(taps['Registracije'], 1);
            expect(find.text('Skrivena akcija'), findsNothing);
          },
        );
      }
    }
  }
}
