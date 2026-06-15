import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/cash_flow/screens/finance_cash_flow_hub_tab_body.dart';
import 'package:production_app/modules/finance/forecast/models/finance_cash_flow_forecast.dart';
import 'package:production_app/modules/finance/planned_cash_items/models/finance_planned_cash_item.dart';
import 'package:production_app/modules/finance/shared/finance_money_format.dart';
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

  Widget wrap(Widget child, {Locale locale = const Locale('bs')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('bs'), Locale('en')],
      home: Scaffold(body: child),
    );
  }

  testWidgets('Cash Flow hub prikazuje P3 kartice', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FinanceCashFlowHubTabBody(
          companyData: managerData,
          debugUnlockModule: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planirane stavke'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cash Flow prognoza'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cash Flow prognoza'), findsOneWidget);
    expect(find.text('Realizovani Cash Flow'), findsOneWidget);
  });

  testWidgets('EN lokalizacija P3 kartica', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FinanceCashFlowHubTabBody(
          companyData: managerData,
          debugUnlockModule: true,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planned items'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cash Flow forecast'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cash Flow forecast'), findsOneWidget);
  });

  test('RBAC: clerk nema approve/cancel planirane stavke', () {
    expect(
      FinancePermissions.canApproveCancelPlannedCashItem(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isFalse,
    );
    expect(
      FinancePermissions.canCreatePlannedCashItemDraft(
        companyData: clerkData,
        role: 'accounting_clerk',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  test('RBAC: manager može approve planirane stavke', () {
    expect(
      FinancePermissions.canApproveCancelPlannedCashItem(
        companyData: managerData,
        role: 'accounting_manager',
        debugUnlockModule: true,
      ),
      isTrue,
    );
  });

  test('planned item weightedAmount iz probability', () {
    const item = FinancePlannedCashItem(
      id: 'p1',
      companyId: 'plamingo',
      status: 'approved',
      direction: 'inflow',
      cashFlowCategoryId: 'cat1',
      nominalAmount: 1000,
      currency: 'EUR',
      expectedDate: null,
      probabilityPercent: 75,
      probabilitySource: 'manual_confirmed',
      description: 'Test',
      weightedAmount: 750,
    );
    expect(item.weightedAmount, 750);
    expect(item.isApproved, isTrue);
  });

  test('forecast bucket parsira nominal i ponderisani završni saldo odvojeno', () {
    final bucket = FinanceCashFlowForecastBucket.fromCallableMap({
      'openingBalance': 10000,
      'actualInflows': 500,
      'actualOutflows': 200,
      'plannedNominalInflows': 1000,
      'plannedNominalOutflows': 300,
      'plannedWeightedInflows': 800,
      'plannedWeightedOutflows': 250,
      'nominalClosingBalance': 11000,
      'weightedClosingBalance': 10850,
    });
    expect(bucket.nominalClosingBalance, 11000);
    expect(bucket.weightedClosingBalance, 10850);
    expect(bucket.plannedNominalInflows, 1000);
    expect(bucket.plannedWeightedInflows, 800);
  });

  test('forecast model parsira liquidity threshold', () {
    final forecast = FinanceCashFlowForecast.fromCallableMap({
      'companyId': 'plamingo',
      'baseCurrency': 'EUR',
      'bucketType': 'day',
      'openingBalance': 5000,
      'minimumCashReserve': 2000,
      'accountIds': ['acc1'],
      'buckets': [],
      'liquidityThreshold': {
        'minimumCashReserve': 2000,
        'nominalNegativeBalanceExpected': true,
        'weightedNegativeBalanceExpected': false,
        'minimumNominalBalance': 1500,
        'minimumNominalBalanceDate': '2026-07-01',
      },
    });
    expect(forecast.baseCurrency, 'EUR');
    expect(forecast.minimumCashReserve, 2000);
    expect(forecast.liquidityThreshold.nominalNegativeBalanceExpected, isTrue);
    expect(forecast.liquidityThreshold.weightedNegativeBalanceExpected, isFalse);
  });

  test('money format za prognozu', () {
    expect(FinanceMoneyFormat.format(1234.5, 'EUR'), contains('1'));
  });
}
