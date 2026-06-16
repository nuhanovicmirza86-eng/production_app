import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/ai_advisory/models/finance_ai_outcome.dart';
import 'package:production_app/modules/finance/ai_advisory/models/finance_ai_outcome_evidence.dart';
import 'package:production_app/modules/finance/ai_advisory/models/finance_ai_recommendation_interaction.dart';
import 'package:production_app/modules/finance/ai_advisory/services/finance_ai_outcome_service.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_outcome_evidence_card.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_outcome_section.dart';
import 'package:production_app/modules/finance/ai_advisory/widgets/finance_ai_recommendation_decision_section.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';
import 'package:production_app/modules/finance_integrations/utils/finance_permissions.dart';

void main() {
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

  test('requestId helperi su stabilni po alert/preporuci', () {
    expect(
      FinanceAiInteractionRequestIds.shown('a1', 'r1'),
      'shown-a1-r1',
    );
    expect(
      FinanceAiInteractionRequestIds.rejected('a1', 'r1', 'not_relevant'),
      'rejected-a1-r1-not_relevant',
    );
    expect(
      FinanceAiInteractionRequestIds.actionCompleted('a1', 'r1'),
      'action-completed-a1-r1',
    );
  });

  test('RBAC: canRecordFinanceAiInteraction = canSubmitFinanceAiFeedback', () {
    const data = {
      'companyId': 'plamingo',
      'enabledModules': ['finance_controlling'],
    };
    expect(
      FinancePermissions.canRecordFinanceAiInteraction(
        companyData: data,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  testWidgets('outcome_pending prikazuje poruku posmatranja (BS/EN)', (tester) async {
    const detail = FinanceAiOutcomeDetail(
      outcome: FinanceAiOutcome(
        outcomeId: 'o1',
        companyId: 'c1',
        recommendationId: 'r1',
        alertId: 'a1',
        outcomeStatus: 'outcome_pending',
      ),
    );

    await tester.pumpWidget(wrap(FinanceAiOutcomeSection(detail: detail)));
    expect(find.textContaining('posmatra'), findsWidgets);

    await tester.pumpWidget(
      wrap(FinanceAiOutcomeSection(detail: detail), locale: const Locale('en')),
    );
    expect(find.textContaining('observation'), findsWidgets);
  });

  testWidgets('outcome_confirmed prikazuje evidence i potvrđeni iznos', (tester) async {
    final detail = FinanceAiOutcomeDetail(
      outcome: FinanceAiOutcome(
        outcomeId: 'o1',
        companyId: 'c1',
        recommendationId: 'r1',
        alertId: 'a1',
        outcomeStatus: 'outcome_confirmed',
        confirmedImpact: const FinanceAiConfirmedImpact(
          confirmedImpactAmount: 1250.5,
          impactCurrency: 'EUR',
          confirmationMethod: 'overdue_amount_reduction',
        ),
      ),
      evidence: const [
        FinanceAiOutcomeEvidence(
          evidenceId: 'e1',
          companyId: 'c1',
          outcomeId: 'o1',
          recommendationId: 'r1',
          evidenceType: 'overdue_amount',
          sourceFieldPath: 'openAmount',
          observedBefore: 5000,
          observedAfter: 3750,
          currency: 'EUR',
        ),
      ],
    );

    await tester.pumpWidget(wrap(FinanceAiOutcomeSection(detail: detail)));
    final ctx = tester.element(find.byType(FinanceAiOutcomeSection));
    expect(
      find.text(FinanceStrings.t(ctx, 'advisory_outcome_confirmed_impact')),
      findsOneWidget,
    );
    expect(find.byType(FinanceAiOutcomeEvidenceCard), findsOneWidget);
    expect(find.textContaining('evidenceHash'), findsNothing);
  });

  testWidgets('null confirmedImpactAmount se ne prikazuje kao nula', (tester) async {
    const detail = FinanceAiOutcomeDetail(
      outcome: FinanceAiOutcome(
        outcomeId: 'o1',
        companyId: 'c1',
        recommendationId: 'r1',
        alertId: 'a1',
        outcomeStatus: 'outcome_unknown',
        confirmedImpact: FinanceAiConfirmedImpact(
          confirmedImpactAmount: null,
          impactCurrency: 'EUR',
        ),
      ),
    );

    await tester.pumpWidget(wrap(FinanceAiOutcomeSection(detail: detail)));
    expect(find.textContaining('0,00'), findsNothing);
    expect(find.textContaining('0.00'), findsNothing);
  });

  testWidgets('accepted/rejected su međusobno isključivi u UI', (tester) async {
    await tester.pumpWidget(
      wrap(
        FinanceAiRecommendationDecisionSection(
          canInteract: true,
          actionInProgress: false,
          interactionSummary: const FinanceAiInteractionSummary(accepted: true),
          onAccept: () {},
          onReject: (_, __) async {},
        ),
      ),
    );
    expect(find.textContaining('prihvaćena'), findsOneWidget);
    expect(find.textContaining('Prihvati preporuku'), findsNothing);
    expect(find.textContaining('Odbij preporuku'), findsNothing);
  });

  testWidgets('outcome_unknown jasno kaže nedovoljno dokaza', (tester) async {
    const detail = FinanceAiOutcomeDetail(
      outcome: FinanceAiOutcome(
        outcomeId: 'o1',
        companyId: 'c1',
        recommendationId: 'r1',
        alertId: 'a1',
        outcomeStatus: 'outcome_unknown',
      ),
    );
    await tester.pumpWidget(wrap(FinanceAiOutcomeSection(detail: detail)));
    expect(find.textContaining('dovoljno dokaza'), findsWidgets);
  });
}
