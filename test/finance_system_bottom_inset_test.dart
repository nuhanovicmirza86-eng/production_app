import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_context.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_edge_handle.dart';
import 'package:production_app/modules/finance/shared/finance_scaffold.dart';
import 'package:production_app/modules/finance/shared/finance_system_bottom_inset.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'finance_assistant_edge_side_v1': 'right',
      'finance_assistant_edge_top_ratio_v1': 0.65,
    });
  });

  group('FinanceSystemBottomInset', () {
    testWidgets('fabBottom uses navigation bar when keyboard is closed', (tester) async {
      await tester.pumpWidget(
        _InsetProbe(
          mediaQuery: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 34)),
          probe: (context) => FinanceSystemBottomInset.fabBottom(context),
          expected: 50,
        ),
      );
    });

    testWidgets('fabBottom lifts above keyboard when open', (tester) async {
      await tester.pumpWidget(
        _InsetProbe(
          mediaQuery: const MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 280),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          probe: (context) => FinanceSystemBottomInset.fabBottom(context),
          expected: 296,
        ),
      );
    });

    testWidgets('edgeHandleBottom includes navigation bar and bottom nav', (tester) async {
      await tester.pumpWidget(
        _InsetProbe(
          mediaQuery: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 34)),
          probe: (context) => FinanceSystemBottomInset.edgeHandleBottom(context),
          expected: 98,
        ),
      );
    });
  });

  group('FinanceAssistantEdgeHandle layout', () {
    testWidgets('exposes 56x56 touch target and premium chat bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
            child: FinanceScaffold(
              assistantContext: const FinanceAssistantContext(
                companyId: 'co1',
                screenKey: 'test',
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = find.byType(FinanceAssistantEdgeHandle);
      expect(handle, findsOneWidget);

      final touchBox = tester.getSize(
        find.descendant(
          of: handle,
          matching: find.byType(GestureDetector),
        ),
      );
      expect(touchBox.width, FinanceAssistantEdgeHandle.touchSize);
      expect(touchBox.height, FinanceAssistantEdgeHandle.touchSize);

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      final bubble = tester.widget<Container>(
        find.descendant(
          of: handle,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color ==
                    FinanceAssistantEdgeHandle.brandColor,
          ),
        ),
      );
      final decoration = bubble.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('body has no extra bottom clearance for assistant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FinanceScaffold(
            assistantContext: const FinanceAssistantContext(
              companyId: 'co1',
              screenKey: 'test',
            ),
            body: const Text('content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('content'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Padding &&
              w.padding == const EdgeInsets.only(bottom: 72),
        ),
        findsNothing,
      );
    });
  });
}

class _InsetProbe extends StatelessWidget {
  const _InsetProbe({
    required this.mediaQuery,
    required this.probe,
    required this.expected,
  });

  final MediaQueryData mediaQuery;
  final double Function(BuildContext context) probe;
  final double expected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: mediaQuery,
        child: Builder(
          builder: (context) {
            expect(probe(context), expected);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
