import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../cash_flow/screens/finance_cash_flow_hub_tab_body.dart';
import '../../cash_transactions/screens/finance_cash_transactions_screen.dart';
import '../../forecast/screens/finance_cash_flow_forecast_screen.dart';
import '../../payables/screens/finance_payables_screen.dart';
import '../../planned_cash_items/screens/finance_planned_cash_items_screen.dart';
import '../../receivables/screens/finance_receivables_screen.dart';
import '../../accounts/screens/finance_accounts_screen.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_ai_alert.dart';
import '../models/finance_ai_interaction_types.dart';
import '../services/finance_ai_advisory_action_bridge.dart';
import '../services/finance_ai_outcome_service.dart';

/// Navigacija preporučene akcije — P1–P3 ekrani + telemetry `action_started`.
class FinanceAiAdvisoryNavigation {
  FinanceAiAdvisoryNavigation._();

  static Future<void> openRecommendation(
    BuildContext context, {
    required Map<String, dynamic> companyData,
    required FinanceAiPrimaryRecommendation recommendation,
    required String alertId,
    required String recommendationId,
    required String companyId,
    FinanceAiOutcomeService? outcomeService,
    bool debugUnlockModule = false,
    void Function(String message)? onTelemetryError,
  }) async {
    final action = recommendation.actionType.trim().toLowerCase();
    if (action == 'no_action') return;

    final route = _routeForAction(
      action: action,
      companyData: companyData,
      debugUnlockModule: debugUnlockModule,
    );
    if (route == null) return;

    final svc = outcomeService ?? FinanceAiOutcomeService();
    final navTarget = screenTypeForAction(action) ?? action;
    final entity = _targetEntityFromParams(recommendation.navigationParams);
    final telemetryFallback = FinanceStrings.t(context, 'advisory_telemetry_error');

    try {
      await svc.recordInteraction(
        companyId: companyId,
        recommendationId: recommendationId,
        interactionType: FinanceAiInteractionTypes.actionStarted,
        requestId: FinanceAiInteractionRequestIds.actionStarted(
          alertId,
          recommendationId,
        ),
        clientSurface: 'alert_detail',
        targetEntityType: entity.type,
        targetEntityId: entity.id,
        metadata: {
          'navigationTarget': navTarget,
          if (recommendation.navigationParams['filter'] != null)
            'filterPreset': recommendation.navigationParams['filter'].toString(),
        },
      );
    } on FirebaseFunctionsException catch (e) {
      onTelemetryError?.call(e.message ?? telemetryFallback);
    } catch (_) {
      onTelemetryError?.call(telemetryFallback);
    }

    FinanceAiAdvisoryActionBridge.beginNavigation(
      FinanceAiAdvisoryNavigationSession(
        companyId: companyId,
        alertId: alertId,
        recommendationId: recommendationId,
        actionType: action,
      ),
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(route);
    FinanceAiAdvisoryActionBridge.clear();
  }

  static ({String? type, String? id}) _targetEntityFromParams(
    Map<String, dynamic> params,
  ) {
    final txId = (params['transactionId'] ?? '').toString().trim();
    if (txId.isNotEmpty) {
      return (type: 'finance_cash_transaction', id: txId);
    }
    final accountId = (params['accountId'] ?? '').toString().trim();
    if (accountId.isNotEmpty) {
      return (type: 'finance_account', id: accountId);
    }
    return (type: null, id: null);
  }

  static MaterialPageRoute<void>? _routeForAction({
    required String action,
    required Map<String, dynamic> companyData,
    bool debugUnlockModule = false,
  }) {
    final type = screenTypeForAction(action);
    if (type == null) return null;
    switch (action.trim().toLowerCase()) {
      case 'view_cash_flow_forecast':
        return MaterialPageRoute<void>(
          builder: (_) => FinanceCashFlowForecastScreen(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
      case 'view_receivables':
        return MaterialPageRoute<void>(
          builder: (_) => FinanceReceivablesScreen(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
      case 'view_payables':
        return MaterialPageRoute<void>(
          builder: (_) => FinancePayablesScreen(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
      case 'view_planned_cash_items':
      case 'review_draft_planned_items':
        return MaterialPageRoute<void>(
          builder: (_) => FinancePlannedCashItemsScreen(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
      case 'view_account':
        return MaterialPageRoute<void>(
          builder: (_) => FinanceAccountsScreen(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
      case 'view_payment_allocations':
        return MaterialPageRoute<void>(
          builder: (_) => FinanceCashTransactionsScreen(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
      case 'no_action':
        return null;
      default:
        return MaterialPageRoute<void>(
          builder: (_) => FinanceCashFlowHubTabBody(
            companyData: companyData,
            debugUnlockModule: debugUnlockModule,
          ),
        );
    }
  }

  /// Kanonski P1–P3 ekran za actionType (integration / QA).
  static String? screenTypeForAction(String actionType) {
    switch (actionType.trim().toLowerCase()) {
      case 'view_cash_flow_forecast':
        return 'FinanceCashFlowForecastScreen';
      case 'view_receivables':
        return 'FinanceReceivablesScreen';
      case 'view_payables':
        return 'FinancePayablesScreen';
      case 'view_planned_cash_items':
      case 'review_draft_planned_items':
        return 'FinancePlannedCashItemsScreen';
      case 'view_account':
        return 'FinanceAccountsScreen';
      case 'view_payment_allocations':
        return 'FinanceCashTransactionsScreen';
      case 'no_action':
        return null;
      default:
        return 'FinanceCashFlowHubTabBody';
    }
  }
}
