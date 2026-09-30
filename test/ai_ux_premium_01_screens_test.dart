import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/ui/standard_list_components.dart';
import 'package:production_app/modules/production/ai/operonix_ai_ux_copy.dart';
import 'package:production_app/modules/production/ai/widgets/operonix_ai_chat_composer.dart';
import 'package:production_app/modules/production/ai/widgets/operonix_ai_filter_result_page.dart';
import 'package:production_app/modules/production/ai/widgets/operonix_ai_inline_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('composer', () {
    testWidgets('compact send arrow on the right, no full-width Pošalji', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var sent = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperonixAiChatComposer(
              controller: controller,
              onSend: () => sent++,
            ),
          ),
        ),
      );

      expect(find.text('Pošalji'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);

      final field = tester.getRect(find.byType(TextField));
      final send = tester.getRect(find.byType(IconButton));
      expect(send.left, greaterThan(field.right));
      expect(send.width, greaterThanOrEqualTo(48));
      expect(send.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(sent, 0);

      await tester.enterText(find.byType(TextField), 'Koje odgovore nudiš?');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(sent, 1);
    });

    testWidgets('loading disables double-send', (tester) async {
      final controller = TextEditingController(text: 'test');
      addTearDown(controller.dispose);
      var sent = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperonixAiChatComposer(
              controller: controller,
              loading: true,
              onSend: () => sent++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(sent, 0);
    });
  });

  group('filters', () {
    testWidgets('collapse/expand and summary text', (tester) async {
      var expanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StandardFilterPanel(
                  expanded: expanded,
                  activeCount: 0,
                  summary: 'Brizganje · 24.09–30.09',
                  onToggle: () => setState(() => expanded = !expanded),
                  child: const Text('Od: kalendar'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Filteri'), findsOneWidget);
      expect(find.text('Brizganje · 24.09–30.09'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await tester.tap(find.text('Filteri'));
      await tester.pumpAndSettle();
      expect(find.text('Od: kalendar'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    });

    test('date summary uses dd.MM–dd.MM', () {
      expect(
        formatOperonixFilterDateRange(
          DateTime(2026, 9, 24),
          DateTime(2026, 9, 30),
        ),
        '24.09–30.09',
      );
    });
  });

  group('error and empty', () {
    testWidgets('inline error retry stays compact', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperonixAiInlineError(
              message: kOperonixAiTransientReplyUnavailable,
              onRetry: () => retries++,
            ),
          ),
        ),
      );

      expect(find.text(kOperonixAiTransientReplyUnavailable), findsOneWidget);
      expect(find.text(kOperonixAiRetryActionLabel), findsOneWidget);
      await tester.tap(find.text(kOperonixAiRetryActionLabel));
      expect(retries, 1);
    });

    testWidgets('empty period notice is business-safe', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OperonixAiEmptyPeriodNotice(
              message: kOperonixAiEmptyAnalysisPeriod,
            ),
          ),
        ),
      );
      expect(find.text(kOperonixAiEmptyAnalysisPeriod), findsOneWidget);
    });

    test('empty payload detection after business reset', () {
      expect(
        isStructuredAnalysisPayloadEmpty(<String, dynamic>{
          'losses': <String, dynamic>{
            'entryCount': 0,
            'totalGoodQty': 0,
            'totalScrapQty': 0,
          },
        }),
        isTrue,
      );
      expect(
        isStructuredAnalysisPayloadEmpty(<String, dynamic>{
          'telemetryPoints': <Map<String, dynamic>>[],
        }),
        isTrue,
      );
      expect(
        isStructuredAnalysisPayloadEmpty(<String, dynamic>{
          'orders': <Map<String, dynamic>>[],
          'totals': <String, dynamic>{'ordersInPeriod': 0},
        }),
        isTrue,
      );
      expect(
        isStructuredAnalysisPayloadEmpty(<String, dynamic>{
          'losses': <String, dynamic>{
            'entryCount': 3,
            'totalGoodQty': 12,
            'totalScrapQty': 1,
          },
        }),
        isFalse,
      );
    });

    test('demo actions stay off in production/release', () {
      expect(showOperonixAiDemoActions(isRelease: true), isFalse);
      expect(kOperonixAiAllowDemoPayload, isFalse);
    });
  });

  group('screens C/D', () {
    testWidgets('analysis layout: collapsible filters, action, page scroll', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return OperonixAiFilterResultPage(
                  filtersExpanded: expanded,
                  filterSummary: 'Svi pogoni · 24.09–30.09 · OEE/KPI',
                  onToggleFilters: () => setState(() => expanded = !expanded),
                  filterControls: const Text('Domena'),
                  action: FilledButton(
                    onPressed: () {},
                    child: const Text('Pokreni analizu'),
                  ),
                  bodyBelowAction: const OperonixAiEmptyPeriodNotice(
                    message: kOperonixAiEmptyAnalysisPeriod,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(StandardFilterPanel), findsOneWidget);
      expect(find.text('Filteri'), findsOneWidget);
      expect(find.text('Svi pogoni · 24.09–30.09 · OEE/KPI'), findsOneWidget);
      expect(find.text('Pokreni analizu'), findsOneWidget);
      expect(find.text('Učitaj demo podatke'), findsNothing);
      expect(find.textContaining('JSON'), findsNothing);
      expect(find.textContaining('runAiAnalysis'), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text(kOperonixAiEmptyAnalysisPeriod), findsOneWidget);

      await tester.tap(find.text('Filteri'));
      await tester.pumpAndSettle();
      expect(find.text('Domena'), findsOneWidget);
    });

    testWidgets('report layout: collapsible filters and generate action', (
      tester,
    ) async {
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return OperonixAiFilterResultPage(
                  filtersExpanded: expanded,
                  filterSummary: 'Brizganje · 24.09–30.09',
                  onToggleFilters: () => setState(() => expanded = !expanded),
                  filterControls: const Text('Od: kalendar'),
                  action: FilledButton(
                    onPressed: () {},
                    child: const Text('Generiraj izvještaj'),
                  ),
                  bodyBelowAction: const OperonixAiEmptyPeriodNotice(
                    message: kOperonixAiEmptyReportPeriod,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Brizganje · 24.09–30.09'), findsOneWidget);
      expect(find.text('Generiraj izvještaj'), findsOneWidget);
      expect(find.textContaining('workDate'), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await tester.tap(find.text('Filteri'));
      await tester.pumpAndSettle();
      expect(find.text('Od: kalendar'), findsOneWidget);
    });

    test('production-facing analysis/report copy stays non-technical', () {
      final analysis = File(
        'lib/modules/production/ai_analysis/screens/ai_analysis_screen.dart',
      ).readAsStringSync();
      final report = File(
        'lib/modules/production/reports/screens/production_ai_report_screen.dart',
      ).readAsStringSync();
      expect(analysis.contains('Šalje se JSON'), isFalse);
      expect(analysis.contains('runAiAnalysis'), isFalse);
      expect(analysis.contains('ili koristi demo podatke'), isFalse);
      expect(report.contains('workDate'), isFalse);
      expect(report.contains('createdAt'), isFalse);
    });

    testWidgets('long analysis result stays on the same page scroll', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const StandardFilterPanel(
                      expanded: false,
                      activeCount: 0,
                      summary: 'Svi pogoni · 24.09–30.09 · OEE/KPI',
                      onToggle: _noop,
                      child: SizedBox.shrink(),
                    ),
                    Text('x\n' * 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsWidgets);
      await tester.drag(scrollable.first, const Offset(0, -400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
