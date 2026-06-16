import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/ai_advisory/models/finance_ai_alert.dart';
import 'package:production_app/modules/finance/ai_advisory/services/finance_ai_advisory_navigation.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_alert_card.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_facts_section.dart';
import 'package:production_app/modules/finance/shared/finance_display_labels.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';
import 'package:production_app/modules/finance_integrations/utils/finance_permissions.dart';

/// Integracijski QA — koristi stvarni backend payload iz smoke fixturea.
///
/// Pokrenuti nakon:
///   node maintenance_app/scripts/smoke-p1-finance-ai-advisory-ui.mjs
void main() {
  const managerData = {
    'companyId': 'plamingo',
    'role': 'accounting_manager',
    'userId': 'mgr-1',
    'enabledModules': ['finance_controlling', 'ai_assistant_production'],
  };

  const clerkData = {
    'companyId': 'plamingo',
    'role': 'accounting_clerk',
    'userId': 'clerk-1',
    'enabledModules': ['finance_controlling'],
  };

  const clerkWithAi = {
    'companyId': 'plamingo',
    'role': 'accounting_clerk',
    'userId': 'clerk-1',
    'enabledModules': ['finance_controlling', 'ai_assistant_production'],
  };

  final fixtureFile = File(
    'test/fixtures/finance_p1_ai_advisory_integration_payload.json',
  );

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

  Map<String, dynamic> loadFixture() {
    if (!fixtureFile.existsSync()) {
      fail(
        'Nedostaje ${fixtureFile.path}. '
        'Prvo pokreni: node maintenance_app/scripts/smoke-p1-finance-ai-advisory-ui.mjs',
      );
    }
    return jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
  }

  group('Finance AI P1 integration (backend fixture)', () {
    late Map<String, dynamic> fixture;
    late FinanceAiAlert alertOpen;
    late FinanceAiAlert alertAck;
    late FinanceAiAlert alertDismissed;

    setUpAll(() {
      fixture = loadFixture();
      alertOpen = FinanceAiAlert.fromCallableMap(
        Map<String, dynamic>.from(fixture['alertOpen'] as Map),
      );
      alertAck = FinanceAiAlert.fromCallableMap(
        Map<String, dynamic>.from(fixture['alertAck'] as Map),
      );
      alertDismissed = FinanceAiAlert.fromCallableMap(
        Map<String, dynamic>.from(fixture['alertDismissed'] as Map),
      );
    });

    test('fixture sadrži stvarni backend alert s factsUsed i preporukom', () {
      expect(alertOpen.severity, isNotEmpty);
      expect(alertOpen.confidenceScore, greaterThan(0));
      expect(alertOpen.confidenceOrigin, isNotEmpty);
      expect(alertOpen.factsUsed, isNotEmpty);
      expect(alertOpen.primaryRecommendation.actionType, isNotEmpty);
      expect(alertOpen.primaryRecommendation.title, isNotEmpty);
    });

    test('actionType mapira se na postojeći P1–P3 ekran', () {
      final action = alertOpen.primaryRecommendation.actionType;
      final screen = FinanceAiAdvisoryNavigation.screenTypeForAction(action);
      expect(screen, isNotNull);

      final smokeMap = Map<String, dynamic>.from(
        fixture['p13ActionScreens'] as Map,
      );
      expect(smokeMap[action], screen);
    });

    test('acknowledge i dismiss statusi iz backenda', () {
      expect(alertAck.status, 'acknowledged');
      expect(alertDismissed.status, 'dismissed');
      expect(alertDismissed.dismissReason, isNotEmpty);
    });

    test('dismissed alert ostaje u historiji (fixture)', () {
      final ids = (fixture['historyAlertIds'] as List).cast<String>();
      expect(ids, contains(alertDismissed.alertId));
    });

    test('controlling insights nisu promijenjeni tokom acceptancea', () {
      expect(fixture['insightsCountBefore'], fixture['insightsCountAfter']);
    });

    test('feedback je sačuvan (fixture)', () {
      expect(fixture['feedbackId'], isNotEmpty);
    });

    testWidgets('BA prikaz stvarnog backend payloada', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              FinanceAiAlertCard(alert: alertOpen, onTap: () {}),
              FinanceAiFactsSection(facts: alertOpen.factsUsed),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Pouzdanost'), findsWidgets);
      expect(
        find.text(
          FinanceDisplayLabels.advisoryRuleId(
            tester.element(find.byType(FinanceAiAlertCard)),
            alertOpen.ruleId,
          ),
        ),
        findsWidgets,
      );
    });

    testWidgets('EN prikaz stvarnog backend payloada', (tester) async {
      await tester.pumpWidget(
        wrap(
          FinanceAiAlertCard(alert: alertOpen, onTap: () {}),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Confidence'), findsOneWidget);
      expect(
        find.text(FinanceStrings.t(
          tester.element(find.byType(FinanceAiAlertCard)),
          'advisory_section_title',
        )),
        findsNothing,
      );
    });
  });

  group('Finance AI P1 integration RBAC (Flutter sloj)', () {
    test('clerk: ack/feedback da, dismiss ne', () {
      expect(
        FinancePermissions.canAcknowledgeFinanceAiAlert(
          companyData: clerkData,
          role: 'accounting_clerk',
          debugUnlockModule: true,
        ),
        isTrue,
      );
      expect(
        FinancePermissions.canSubmitFinanceAiFeedback(
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
    });

    test('clerk bez AI ne može manual run; s AI može', () {
      expect(
        FinancePermissions.canRunFinanceAiAdvisoryAnalysis(
          companyData: clerkData,
          role: 'accounting_clerk',
          debugUnlockModule: false,
        ),
        isFalse,
      );
      expect(
        FinancePermissions.canRunFinanceAiAdvisoryAnalysis(
          companyData: clerkWithAi,
          role: 'accounting_clerk',
          debugUnlockModule: false,
        ),
        isTrue,
      );
    });

    test('manager može dismiss', () {
      expect(
        FinancePermissions.canDismissFinanceAiAlert(
          companyData: managerData,
          role: 'accounting_manager',
          debugUnlockModule: true,
        ),
        isTrue,
      );
    });
  });
}
