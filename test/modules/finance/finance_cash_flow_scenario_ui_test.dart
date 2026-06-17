import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/advanced_cash_flow/models/finance_cash_flow_scenario.dart';
import 'package:production_app/modules/finance/shared/finance_display_labels.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';

void main() {
  testWidgets('scenario labels hide technical codes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(
              FinanceDisplayLabels.scenarioType(context, 'optimistic'),
              FinanceStrings.t(context, 'scenario_type_optimistic'),
            );
            expect(
              FinanceDisplayLabels.scenarioType(context, 'what_if'),
              FinanceStrings.t(context, 'scenario_type_what_if'),
            );
            expect(
              FinanceDisplayLabels.scenarioStatus(context, 'calculated'),
              FinanceStrings.t(context, 'scenario_status_calculated'),
            );
            return const SizedBox();
          },
        ),
      ),
    );
  });

  test('parses scenario callable map with snapshots', () {
    final scenario = FinanceCashFlowScenario.fromCallableMap({
      'scenarioId': 'abc',
      'companyId': 'co1',
      'name': 'Test',
      'scenarioType': 'base',
      'status': 'calculated',
      'revision': 1,
      'assumptions': {
        'receivableDelayDays': {
          'value': -2,
          'unit': 'days',
          'source': 'preset',
          'labelBa': 'L',
          'labelEn': 'L',
        },
      },
      'baseForecastSnapshot': {
        'baseCurrency': 'EUR',
        'bucketType': 'day',
        'openingBalance': 1000,
        'minimumCashReserve': 500,
        'buckets': [
          {
            'actualInflows': 100,
            'actualOutflows': 50,
            'plannedNominalInflows': 200,
            'plannedNominalOutflows': 80,
            'plannedWeightedInflows': 160,
            'plannedWeightedOutflows': 64,
            'nominalClosingBalance': 1070,
            'weightedClosingBalance': 1050,
            'openingBalance': 1000,
          },
        ],
        'liquidityThreshold': {
          'minimumCashReserve': 500,
          'minimumNominalBalance': 1070,
          'nominalNegativeBalanceExpected': false,
          'weightedNegativeBalanceExpected': false,
        },
      },
      'calculatedSnapshot': {
        'baseCurrency': 'EUR',
        'bucketType': 'day',
        'openingBalance': 1000,
        'minimumCashReserve': 500,
        'buckets': [
          {
            'actualInflows': 100,
            'actualOutflows': 50,
            'plannedNominalInflows': 220,
            'plannedNominalOutflows': 80,
            'plannedWeightedInflows': 180,
            'plannedWeightedOutflows': 64,
            'nominalClosingBalance': 1090,
            'weightedClosingBalance': 1070,
            'openingBalance': 1000,
          },
        ],
        'liquidityThreshold': {
          'minimumCashReserve': 500,
          'minimumNominalBalance': 1090,
          'nominalNegativeBalanceExpected': false,
          'weightedNegativeBalanceExpected': false,
        },
      },
    });
    expect(scenario.scenarioId, 'abc');
    expect(scenario.calculatedSnapshot?.nominalClosingBalance, 1090);
    expect(scenario.baseForecastSnapshot.totalActualInflows, 100);
  });
}
