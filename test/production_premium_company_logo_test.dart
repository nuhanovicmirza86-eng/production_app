import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/premium/premium_company_logo_plate.dart';
import 'package:production_app/core/visual/premium/premium_widgets.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_layout.dart';
import 'package:production_app/modules/production/dashboard/models/production_dashboard_module.dart';
import 'package:production_app/modules/production/dashboard/production_dashboard_access.dart';
import 'package:production_app/modules/production/dashboard/screens/production_dashboard_screen.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_attention.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const logoUrl = 'https://example.com/tenant-mark.png';

  Future<void> pumpHome(WidgetTester tester, VisualStyle style) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.forStyle(style),
        home: ProductionHomePage(
          companyData: const {
            'branding': {'autoLogoRasterUrl': logoUrl},
          },
          roleLabel: 'Administrator',
          companyId: '',
          plantKey: '',
          companyLine: 'Operonix',
          dashboardLayout: ProductionDashboardLayout.standard,
          onHomeLayoutChanged: (_) {},
          moduleSections: [
            ProductionDashboardModuleSection(
              id: 'production',
              title: 'Proizvodnja',
              subtitle: 'Moduli',
              icon: Icons.precision_manufacturing_outlined,
              entries: [
                ProductionDashboardModuleEntry(
                  id: 'orders',
                  icon: Icons.assignment_outlined,
                  title: 'Proizvodni nalozi',
                  subtitle: 'Nalozi',
                  onTap: () {},
                ),
              ],
            ),
          ],
          dashboardAccess: ProductionDashboardAccess(
            companyData: const {},
            role: 'admin',
            companyId: 'c',
            plantKey: 'p',
            enabledModules: const ['production'],
          ),
          attentionCounts: const MesInboxAttentionCounts(
            newCount: 0,
            waitingActionCount: 0,
          ),
          onOpenInbox: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Premium logo plate matches the Maintenance background', (
    tester,
  ) async {
    await pumpHome(tester, VisualStyle.premium);
    expect(find.byKey(PremiumCompanyLogoPlate.plateKey), findsOneWidget);
    final plate = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(PremiumCompanyLogoPlate.plateKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = plate.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFF7F8FA));
    expect(decoration.color, PremiumCompanyLogoPlate.plateColor);
    expect(decoration.border?.top.color, const Color(0xFFD8DEE6));
    expect(decoration.border?.top.width, 1);
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(
      tester.getSize(find.byKey(PremiumCompanyLogoPlate.plateKey)),
      const Size(52, 52),
    );
    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byKey(PremiumCompanyLogoPlate.plateKey),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, const EdgeInsets.all(52 * 0.12));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, logoUrl);
    expect(image.fit, BoxFit.contain);
    expect(find.byType(ColorFiltered), findsNothing);
    final card = tester.widget<PremiumSurfaceCard>(
      find.byType(PremiumSurfaceCard).first,
    );
    expect(card.padding, const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
    expect(card.level, 1);
    expect(find.text('Operonix'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
  });

  testWidgets('Classic logo keeps the existing edge and does not use the plate', (
    tester,
  ) async {
    await pumpHome(tester, VisualStyle.classic);
    expect(find.byKey(PremiumCompanyLogoPlate.plateKey), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, logoUrl);
    expect(image.fit, BoxFit.cover);
    expect(find.text('Uloga: Administrator'), findsOneWidget);
    expect(find.text('Kompanija: Operonix'), findsOneWidget);
  });
}
