import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/advanced_cash_flow/models/finance_budget_actual_working_capital_snapshot.dart';
import 'package:production_app/modules/finance/advanced_cash_flow/widgets/finance_bawc_display_widgets.dart';
import 'package:production_app/modules/finance/shared/finance_operating_currencies.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';

Widget _wrapLocale(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [
      Locale('hr', 'BA'),
      Locale('bs', 'BA'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  group('FinanceBudgetActualWorkingCapitalSnapshot', () {
    test('parses backend snapshot without local recalculation', () {
      final snap = FinanceBudgetActualWorkingCapitalSnapshot.fromCallableMap({
        'success': true,
        'companyId': 'co1',
        'period': {'from': '2026-06-01', 'to': '2026-06-30'},
        'scope': {'plantKey': null, 'mode': 'all'},
        'currency': 'EUR',
        'budgetActual': {
          'plannedInflow': 10000,
          'actualInflow': 8300,
          'inflowVarianceAmount': -1700,
          'inflowVariancePercent': -17,
          'plannedOutflow': 6000,
          'actualOutflow': 5500,
          'outflowVarianceAmount': -500,
          'outflowVariancePercent': -8.33,
          'plannedNetCashFlow': 4000,
          'actualNetCashFlow': 2800,
          'netVarianceAmount': -1200,
          'netVariancePercent': -30,
        },
        'workingCapital': {
          'dsoPeriodEnd': 4.55,
          'dsoCollectionDaysAverage': 14,
          'dpoPeriodEnd': 6.67,
          'dpoPaymentDaysAverage': 20,
          'dio': null,
          'ccc': null,
          'dioAvailability': 'unavailable_missing_inventory_cost',
          'cccAvailability': 'unavailable_missing_dio',
          'dsoCollectionDaysAverageReason': null,
          'dpoPaymentDaysAverageReason': null,
        },
        'breakdowns': {
          'byPeriod': [
            {
              'key': '2026-06',
              'plannedInflow': 10000,
              'actualInflow': 8300,
              'plannedOutflow': 6000,
              'actualOutflow': 5500,
            },
          ],
          'byCategory': [],
          'byPlant': [],
        },
        'sourceCoverage': {
          'budgetLinesIncluded': 2,
          'budgetLinesExcluded': 0,
          'cashTransactionsIncluded': 5,
          'salesInvoicesIncluded': 5,
          'purchaseInvoicesIncluded': 2,
          'allocationsIncluded': 3,
        },
        'warnings': [],
        'calculationVersion': 'finance-p5-m3-v1',
        'generatedAt': '2026-06-18T10:00:00.000Z',
      });

      expect(snap.calculationVersion, 'finance-p5-m3-v1');
      expect(snap.currency, 'EUR');
      expect(snap.budgetActual.inflowVariancePercent, -17);
      expect(snap.workingCapital.ccc, isNull);
      expect(snap.workingCapital.cccAvailability, 'unavailable_missing_dio');
      expect(snap.breakdownByPeriod, hasLength(1));
    });

    test('parses DIO and CCC when backend marks them available', () {
      final snap = FinanceBudgetActualWorkingCapitalSnapshot.fromCallableMap({
        'success': true,
        'companyId': 'co1',
        'period': {'from': '2026-06-01', 'to': '2026-06-30'},
        'scope': {'plantKey': null, 'mode': 'all'},
        'currency': 'EUR',
        'budgetActual': {
          'plannedInflow': 0,
          'actualInflow': 0,
          'inflowVarianceAmount': 0,
          'inflowVariancePercent': null,
          'plannedOutflow': 0,
          'actualOutflow': 0,
          'outflowVarianceAmount': 0,
          'outflowVariancePercent': null,
          'plannedNetCashFlow': 0,
          'actualNetCashFlow': 0,
          'netVarianceAmount': 0,
          'netVariancePercent': null,
        },
        'workingCapital': {
          'dsoPeriodEnd': 40,
          'dsoCollectionDaysAverage': 14,
          'dpoPeriodEnd': 25,
          'dpoPaymentDaysAverage': 20,
          'dio': 37.89,
          'ccc': 53.13,
          'dioAvailability': 'available',
          'cccAvailability': 'available',
        },
        'breakdowns': {'byPeriod': [], 'byCategory': [], 'byPlant': []},
        'sourceCoverage': {
          'budgetLinesIncluded': 1,
          'budgetLinesExcluded': 0,
          'cashTransactionsIncluded': 0,
          'salesInvoicesIncluded': 0,
          'purchaseInvoicesIncluded': 0,
          'allocationsIncluded': 0,
        },
        'warnings': [
          {
            'code': 'inventory_source_erp_preferred_over_wms',
            'message': 'ERP',
            'severity': 'info',
          },
        ],
        'calculationVersion': 'finance-p5-m3-v1',
      });

      expect(snap.workingCapital.dio, closeTo(37.89, 0.001));
      expect(snap.workingCapital.ccc, closeTo(53.13, 0.001));
      expect(snap.workingCapital.dioAvailability, 'available');
      expect(snap.workingCapital.cccAvailability, 'available');
    });
  });

  group('FinanceOperatingCurrencies', () {
    test('allows only EUR and BAM', () {
      expect(FinanceOperatingCurrencies.codes, ['EUR', 'BAM']);
      expect(FinanceOperatingCurrencies.isAllowed('EUR'), isTrue);
      expect(FinanceOperatingCurrencies.isAllowed('BAM'), isTrue);
      expect(FinanceOperatingCurrencies.isAllowed('USD'), isFalse);
    });
  });

  group('FinanceBawcDisplay', () {
    testWidgets('null variance percent shows Nije primjenjivo', (tester) async {
      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              final text = FinanceBawcDisplay.formatPercent(context, null);
              expect(text, FinanceStrings.t(context, 'bawc_variance_not_applicable'));
              return const SizedBox.shrink();
            },
          ),
          const Locale('hr', 'BA'),
        ),
      );
    });

    testWidgets('does not show 0% for null variance', (tester) async {
      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              final text = FinanceBawcDisplay.formatPercent(context, null);
              expect(text.contains('0%'), isFalse);
              return const SizedBox.shrink();
            },
          ),
          const Locale('hr', 'BA'),
        ),
      );
    });

    testWidgets('formatDays rounds without decimals for users', (tester) async {
      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              expect(
                FinanceBawcDisplay.formatDays(context, 29.4),
                'oko 29 dana',
              );
              expect(
                FinanceBawcDisplay.formatDays(context, 30),
                '30 dana',
              );
              expect(
                FinanceBawcDisplay.formatDays(context, 1),
                '1 dan',
              );
              expect(
                FinanceBawcDisplay.formatDays(context, null),
                FinanceStrings.t(context, 'bawc_metric_unavailable'),
              );
              return const SizedBox.shrink();
            },
          ),
          const Locale('hr', 'BA'),
        ),
      );
    });

    testWidgets('formatDays English uses about prefix for fractions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              expect(
                FinanceBawcDisplay.formatDays(context, 29.4),
                'about 29 days',
              );
              expect(
                FinanceBawcDisplay.formatDays(context, 30),
                '30 days',
              );
              return const SizedBox.shrink();
            },
          ),
          const Locale('en'),
        ),
      );
    });

    testWidgets('formatDioValue and formatCccValue use backend availability', (
      tester,
    ) async {
      const unavailableWc = FinanceWorkingCapitalMetrics(
        dsoPeriodEnd: 40,
        dsoCollectionDaysAverage: 14,
        dpoPeriodEnd: 25,
        dpoPaymentDaysAverage: 20,
        dio: null,
        ccc: null,
        dioAvailability: 'unavailable_missing_inventory_cost',
        cccAvailability: 'unavailable_missing_dio',
      );
      const availableWc = FinanceWorkingCapitalMetrics(
        dsoPeriodEnd: 40,
        dsoCollectionDaysAverage: 14,
        dpoPeriodEnd: 25,
        dpoPaymentDaysAverage: 20,
        dio: 37.89,
        ccc: 53.13,
        dioAvailability: 'available',
        cccAvailability: 'available',
      );

      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              expect(
                FinanceBawcDisplay.formatDioValue(context, unavailableWc),
                FinanceStrings.t(context, 'bawc_dio_unavailable_cogs'),
              );
              expect(
                FinanceBawcDisplay.formatCccValue(context, unavailableWc),
                FinanceStrings.t(context, 'bawc_metric_unavailable'),
              );
              expect(
                FinanceBawcDisplay.formatDioValue(context, availableWc),
                'oko 38 dana',
              );
              expect(
                FinanceBawcDisplay.formatCccValue(context, availableWc),
                'oko 53 dana',
              );
              expect(
                FinanceBawcDisplay.formatDioValue(context, availableWc),
                isNot(contains('.')),
              );
              return const SizedBox.shrink();
            },
          ),
          const Locale('hr', 'BA'),
        ),
      );
    });

    testWidgets('coverageMessages shows ERP preference without DIO unavailable', (
      tester,
    ) async {
      const snap = FinanceBudgetActualWorkingCapitalSnapshot(
        success: true,
        companyId: 'co1',
        periodFrom: '2026-06-01',
        periodTo: '2026-06-30',
        scopePlantKey: null,
        scopeMode: 'all',
        currency: 'EUR',
        budgetActual: FinanceBudgetActualTotals(
          plannedInflow: 100,
          actualInflow: 100,
          inflowVarianceAmount: 0,
          inflowVariancePercent: null,
          plannedOutflow: 0,
          actualOutflow: 0,
          outflowVarianceAmount: 0,
          outflowVariancePercent: null,
          plannedNetCashFlow: 100,
          actualNetCashFlow: 100,
          netVarianceAmount: 0,
          netVariancePercent: null,
        ),
        workingCapital: FinanceWorkingCapitalMetrics(
          dsoPeriodEnd: 40,
          dsoCollectionDaysAverage: 14,
          dpoPeriodEnd: 25,
          dpoPaymentDaysAverage: 20,
          dio: 38,
          ccc: 53,
          dioAvailability: 'available',
          cccAvailability: 'available',
        ),
        breakdownByPeriod: const [],
        breakdownByCategory: const [],
        breakdownByPlant: const [],
        sourceCoverage: FinanceBawcSourceCoverage(
          budgetLinesIncluded: 1,
          budgetLinesExcluded: 0,
          cashTransactionsIncluded: 0,
          salesInvoicesIncluded: 0,
          purchaseInvoicesIncluded: 0,
          allocationsIncluded: 0,
        ),
        warnings: const [
          FinanceBawcWarning(
            code: 'inventory_source_erp_preferred_over_wms',
            message: 'ERP',
            severity: 'info',
          ),
        ],
        calculationVersion: 'finance-p5-m3-v1',
      );

      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              final messages = FinanceBawcDisplay.coverageMessages(context, snap);
              expect(messages, hasLength(1));
              expect(
                messages.single,
                FinanceStrings.t(context, 'bawc_warn_inventory_erp_preferred'),
              );
              expect(
                messages,
                isNot(contains(
                  FinanceStrings.t(context, 'bawc_warn_dio_ccc_unavailable'),
                )),
              );
              return const SizedBox.shrink();
            },
          ),
          const Locale('hr', 'BA'),
        ),
      );
    });

    test('category breakdown hides internal record ids', () {
      expect(
        FinanceBawcDisplay.looksLikeInternalRecordId('xClaWt3tvUTlkmoh1rYe'),
        isTrue,
      );
      expect(FinanceBawcDisplay.looksLikeInternalRecordId('2026-06'), isFalse);
    });

    testWidgets('category breakdown label uses name or Nekategorizirano', (
      tester,
    ) async {
      const totals = FinanceBudgetActualTotals(
        plannedInflow: 0,
        actualInflow: 100,
        inflowVarianceAmount: 100,
        inflowVariancePercent: null,
        plannedOutflow: 0,
        actualOutflow: 0,
        outflowVarianceAmount: 0,
        outflowVariancePercent: null,
        plannedNetCashFlow: 0,
        actualNetCashFlow: 100,
        netVarianceAmount: 100,
        netVariancePercent: null,
      );

      await tester.pumpWidget(
        _wrapLocale(
          Builder(
            builder: (context) {
              final named = FinanceBudgetActualBreakdownRow(
                key: 'cat1',
                categoryName: 'Operativni priliv',
                totals: totals,
              );
              expect(
                FinanceBawcDisplay.categoryBreakdownLabel(context, named),
                'Operativni priliv',
              );

              final idOnly = FinanceBudgetActualBreakdownRow(
                key: 'xClaWt3tvUTlkmoh1rYe',
                totals: totals,
              );
              expect(
                FinanceBawcDisplay.categoryBreakdownLabel(context, idOnly),
                FinanceStrings.t(context, 'bawc_uncategorized'),
              );
              expect(
                FinanceBawcDisplay.categoryBreakdownLabel(context, idOnly),
                isNot(contains('xClaWt')),
              );

              return const SizedBox.shrink();
            },
          ),
          const Locale('hr', 'BA'),
        ),
      );
    });
  });
}
