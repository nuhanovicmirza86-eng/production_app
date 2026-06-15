import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/ai_advisory/models/finance_ai_alert.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_alert_card.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_facts_section.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_severity_chip.dart';
import 'package:production_app/modules/finance/shared/finance_display_labels.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';
import 'package:production_app/modules/finance_integrations/utils/finance_permissions.dart';

void main() {
  const managerData = {
    'companyId': 'plamingo',
    'role': 'accounting_manager',
    'userId': 'mgr-1',
    'enabledModules': ['finance_controlling'],
  };

  const clerkData = {
    'companyId': 'plamingo',
    'role': 'accounting_clerk',
    'userId': 'clerk-1',
    'enabledModules': ['finance_controlling'],
  };

  const aiClerkData = {
    'companyId': 'plamingo',
    'role': 'accounting_clerk',
    'userId': 'clerk-1',
    'enabledModules': ['finance_controlling', 'ai_assistant_production'],
  };

  Widget wrap(Widget child, {Locale locale = const Locale('bs')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('bs'), Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  final sampleAlert = FinanceAiAlert.fromCallableMap({
    'alertId': 'a1',
    'companyId': 'plamingo',
    'ruleId': 'receivables.overdue_material',
    'status': 'open',
    'severity': 'high',
    'headline': 'Dospjela potraživanja',
    'summary': 'Ukupno preko praga.',
    'confidenceScore': 82,
    'confidenceOrigin': 'deterministic_only',
    'confidenceFactors': {'factCount': 2},
    'factsUsed': [
      {
        'factType': 'sales_invoice_open',
        'label': 'Faktura INV-001',
        'snapshot': {'amount': 4200},
      },
    ],
    'primaryRecommendation': {
      'actionType': 'view_receivables',
      'title': 'Otvorena potraživanja',
      'detail': 'Pregledajte listu.',
    },
    'contractVersion': '2026-06-finance-ai-p1-v1',
  });

  test('RBAC: clerk može pregledati i acknowledge, ne dismiss ni run', () {
    expect(
      FinancePermissions.canViewFinanceAiAdvisory(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
    expect(
      FinancePermissions.canAcknowledgeFinanceAiAlert(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
    expect(
      FinancePermissions.canDismissFinanceAiAlert(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isFalse,
    );
    expect(
      FinancePermissions.canRunFinanceAiAdvisoryAnalysis(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: false,
      ),
      isFalse,
    );
  });

  test('RBAC: manager može dismiss i run s AI entitlementom', () {
    expect(
      FinancePermissions.canDismissFinanceAiAlert(
        companyData: managerData,
        role: 'accounting_manager',
        debugUnlockModule: true,
      ),
      isTrue,
    );
    expect(
      FinancePermissions.canRunFinanceAiAdvisoryAnalysis(
        companyData: {
          ...managerData,
          'enabledModules': ['finance_controlling', 'ai_assistant_production'],
        },
        role: 'accounting_manager',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  test('RBAC: clerk s AI entitlementom može run analizu', () {
    expect(
      FinancePermissions.canRunFinanceAiAdvisoryAnalysis(
        companyData: aiClerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  testWidgets('alert card prikazuje severity i confidence s backenda', (tester) async {
    await tester.pumpWidget(
      wrap(
        FinanceAiAlertCard(
          alert: sampleAlert,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FinanceAiSeverityChip), findsOneWidget);
    expect(find.textContaining('82'), findsOneWidget);
    expect(find.text('Otvorena potraživanja'), findsOneWidget);
  });

  testWidgets('facts sekcija prikazuje factsUsed poslovnim nazivom', (tester) async {
    await tester.pumpWidget(
      wrap(
        FinanceAiFactsSection(facts: sampleAlert.factsUsed),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Faktura INV-001'), findsOneWidget);
    expect(find.textContaining('Otvorena izlazna faktura'), findsOneWidget);
  });

  testWidgets('EN lokalizacija advisory stringova', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Text(
            FinanceStrings.t(context, 'advisory_section_title'),
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proactive financial monitoring'), findsOneWidget);
  });

  testWidgets('display labels prevode ruleId i severity', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            expect(
              FinanceDisplayLabels.advisoryRuleId(
                context,
                'payables.due_soon_cluster',
              ),
              'Skup obaveza uskoro dospijeva',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            expect(
              FinanceDisplayLabels.advisorySeverity(context, 'critical'),
              'Critical',
            );
            return const SizedBox.shrink();
          },
        ),
        locale: const Locale('en'),
      ),
    );
  });

  test('alert model ne mutira severity/confidence lokalno', () {
    expect(sampleAlert.severity, 'high');
    expect(sampleAlert.confidenceScore, 82);
    expect(sampleAlert.factsUsed, isNotEmpty);
    expect(sampleAlert.primaryRecommendation.actionType, 'view_receivables');
  });
}
