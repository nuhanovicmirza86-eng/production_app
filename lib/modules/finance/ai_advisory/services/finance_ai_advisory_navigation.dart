import 'package:flutter/material.dart';

import '../../cash_flow/screens/finance_cash_flow_hub_tab_body.dart';
import '../../cash_transactions/screens/finance_cash_transactions_screen.dart';
import '../../forecast/screens/finance_cash_flow_forecast_screen.dart';
import '../../invoices/screens/finance_invoices_hub_tab_body.dart';
import '../../payables/screens/finance_payables_screen.dart';
import '../../planned_cash_items/screens/finance_planned_cash_items_screen.dart';
import '../../receivables/screens/finance_receivables_screen.dart';
import '../../accounts/screens/finance_accounts_screen.dart';
import '../models/finance_ai_alert.dart';

/// Navigacija preporučene akcije — samo pregled P1–P3 ekrana, bez mutacije.
class FinanceAiAdvisoryNavigation {
  FinanceAiAdvisoryNavigation._();

  static void openRecommendation(
    BuildContext context, {
    required Map<String, dynamic> companyData,
    required FinanceAiPrimaryRecommendation recommendation,
    bool debugUnlockModule = false,
  }) {
    final route = _routeForAction(
      action: recommendation.actionType.trim().toLowerCase(),
      companyData: companyData,
      debugUnlockModule: debugUnlockModule,
    );
    if (route != null) {
      Navigator.of(context).push(route);
    }
  }

  static MaterialPageRoute<void>? _routeForAction({
    required String action,
    required Map<String, dynamic> companyData,
    bool debugUnlockModule = false,
  }) {
    switch (action) {
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
}
