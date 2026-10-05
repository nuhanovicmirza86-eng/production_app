import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/visual/operonix_visual_theme.dart';
import 'package:production_app/core/visual/operonix_visual_tokens.dart';
import 'package:production_app/core/visual/premium/premium_company_logo_plate.dart';
import 'package:production_app/core/visual/visual_style.dart';
import 'package:production_app/modules/production/dashboard/screens/production_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setSurface(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final width in <double>[360, 411, 1280, 1920]) {
    testWidgets('Premium company logo uses the neutral plate at $width', (
      tester,
    ) async {
      await setSurface(tester, Size(width, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: OperonixVisualTheme.forStyle(VisualStyle.premium),
          home: const Scaffold(
            body: ProductionCompanyHeaderLogo(candidates: []),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(PremiumCompanyLogoPlate.plateKey), findsOneWidget);
      final plate = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(PremiumCompanyLogoPlate.plateKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = plate.decoration as BoxDecoration;
      expect(decoration.color, PremiumCompanyLogoPlate.plateColor);
      expect(
        decoration.border?.top.color,
        isNot(OperonixVisualTokens.classic().moduleAccent),
      );
      expect(find.byType(ColorFiltered), findsNothing);
    });
  }

  testWidgets('Premium logo image stays contain and untinted', (tester) async {
    await setSurface(tester, const Size(411, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.premiumMidnight(),
        home: const Scaffold(
          body: ProductionCompanyHeaderLogo(
            candidates: ['https://example.invalid/logo.png'],
          ),
        ),
      ),
    );
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byKey(PremiumCompanyLogoPlate.plateKey), findsOneWidget);
  });

  testWidgets('Classic company logo keeps the existing frame', (tester) async {
    await setSurface(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: OperonixVisualTheme.forStyle(VisualStyle.classic),
        home: const Scaffold(
          body: ProductionCompanyHeaderLogo(candidates: []),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(PremiumCompanyLogoPlate.plateKey), findsNothing);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
