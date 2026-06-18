import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_context.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_edge_handle.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_assistant_hub_context.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_module_assistant_scope.dart';
import 'package:production_app/modules/finance/shared/finance_assistant/finance_module_assistant_session.dart';
import 'package:production_app/modules/finance/shared/finance_scaffold.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';

void main() {
  const companyData = <String, dynamic>{
    'companyId': 'test-co',
    'role': 'accounting_manager',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'finance_assistant_edge_side_v1': 'right',
      'finance_assistant_edge_top_ratio_v1': 0.65,
    });
    FinanceModuleAssistantSession.end();
  });
  tearDown(FinanceModuleAssistantSession.end);

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('bs'),
      home: FinanceModuleAssistantScope(child: child),
    );
  }

  FinanceAssistantContext hubContext(
    BuildContext context, {
    int tabIndex = 0,
  }) {
    return FinanceAssistantHubContext.forTab(
      context: context,
      companyData: companyData,
      tabIndex: tabIndex,
    );
  }

  testWidgets('M2-G: jedan rubni Finance asistent na FinanceScaffold', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => FinanceScaffold(
            appBar: AppBar(title: const Text('Hub')),
            assistantContext: hubContext(context, tabIndex: 7),
            body: const Center(child: Text('Cash Flow')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FinanceAssistantEdgeHandle), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forum_outlined), findsNothing);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
  });

  testWidgets('M2-G: kontekst hub taba se mijenja u sesiji', (tester) async {
    late FinanceModuleAssistantSession session;

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            session = FinanceModuleAssistantSession.ensure();
            return FinanceScaffold(
              appBar: AppBar(title: const Text('Hub')),
              assistantContext: hubContext(context, tabIndex: 7),
              body: const Text('Cash Flow tab'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      session.activeContext?.screenKey,
      FinanceAssistantScreens.hubCashFlow,
    );
    expect(session.activeContext?.tabKey, FinanceAssistantTabs.cashFlow);

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return FinanceScaffold(
              appBar: AppBar(title: const Text('Hub')),
              assistantContext: hubContext(context, tabIndex: 6),
              body: const Text('Budžeti tab'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      session.activeContext?.screenKey,
      FinanceAssistantScreens.hubBudgets,
    );
    expect(session.activeContext?.tabKey, FinanceAssistantTabs.budgets);
  });

  testWidgets('M2-G: razgovor ostaje pri prelasku na pod-ekran', (tester) async {
    late FinanceModuleAssistantSession session;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bs'),
        home: FinanceModuleAssistantScope(
          child: Builder(
            builder: (context) {
              session = FinanceModuleAssistantSession.ensure();
              session.conversationId = 'conv-m2g-test';
              return _M2gRouteToggle(
                hub: FinanceScaffold(
                  appBar: AppBar(title: const Text('Hub')),
                  assistantContext: hubContext(context, tabIndex: 7),
                  body: const Text('Hub body'),
                ),
                subScreen: FinanceScaffold(
                  appBar: AppBar(title: const Text('Transakcije')),
                  assistantContext: FinanceAssistantContext(
                    companyId: 'test-co',
                    screenKey: FinanceAssistantScreens.transactionsList,
                    tabKey: FinanceAssistantTabs.cashFlow,
                    role: 'accounting_manager',
                  ),
                  body: const Text('Transactions list'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open sub-screen'));
    await tester.pumpAndSettle();

    expect(session.conversationId, 'conv-m2g-test');
    expect(
      session.activeContext?.screenKey,
      FinanceAssistantScreens.transactionsList,
    );
  });

  testWidgets('M2-G: nova sesija nakon napuštanja Finance modula', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            final session = FinanceModuleAssistantSession.ensure();
            session.conversationId = 'old-conv';
            return FinanceScaffold(
              appBar: AppBar(title: const Text('Hub')),
              assistantContext: hubContext(context),
              body: const Text('Hub'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(FinanceModuleAssistantSession.currentOrNull?.conversationId, 'old-conv');

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Dashboard'))));
    await tester.pumpAndSettle();

    expect(FinanceModuleAssistantSession.currentOrNull, isNull);
  });

  testWidgets('M2-G: Finance AI analiza ikona nije chatbot', (tester) async {
    const tooltip = 'Finance AI analiza — uvidi i upozorenja';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('bs'),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Finance & Controlling'),
            actions: [
              IconButton(
                tooltip: tooltip,
                onPressed: () {},
                icon: const Icon(Icons.insights_outlined),
              ),
            ],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    expect(find.byTooltip(tooltip), findsOneWidget);
  });
}

class _M2gRouteToggle extends StatefulWidget {
  const _M2gRouteToggle({
    required this.hub,
    required this.subScreen,
  });

  final Widget hub;
  final Widget subScreen;

  @override
  State<_M2gRouteToggle> createState() => _M2gRouteToggleState();
}

class _M2gRouteToggleState extends State<_M2gRouteToggle> {
  bool _sub = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => setState(() => _sub = true),
          child: const Text('Open sub-screen'),
        ),
        Expanded(child: _sub ? widget.subScreen : widget.hub),
      ],
    );
  }
}
