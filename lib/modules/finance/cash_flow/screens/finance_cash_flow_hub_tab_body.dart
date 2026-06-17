import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../advanced_cash_flow/screens/finance_advanced_cash_flow_screen.dart';
import '../../accounts/screens/finance_accounts_screen.dart';
import '../../bank_reconciliation/screens/finance_bank_statements_screen.dart';
import '../../cash_flow_categories/screens/finance_cash_flow_categories_screen.dart';
import '../../cash_transactions/screens/finance_cash_transactions_screen.dart';
import '../../cash_transactions/screens/finance_realized_cash_flow_screen.dart';
import '../../forecast/screens/finance_cash_flow_forecast_screen.dart';
import '../../planned_cash_items/screens/finance_planned_cash_items_screen.dart';
import '../../shared/finance_hub_entry_card.dart';
import '../../shared/finance_strings.dart';

/// Tab **Cash Flow** unutar postojećeg Finance & Controlling huba.
class FinanceCashFlowHubTabBody extends StatelessWidget {
  const FinanceCashFlowHubTabBody({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  String get _role => (companyData['role'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canAccessCashFlowOperative(
      companyData: companyData,
      role: _role,
      debugUnlockModule: debugUnlockModule,
    )) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            FinanceStrings.t(context, 'module_not_enabled'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final canBank = FinancePermissions.canViewBankReconciliation(
      companyData: companyData,
      role: _role,
      debugUnlockModule: debugUnlockModule,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FinanceHubEntryCard(
          icon: Icons.account_balance_wallet_outlined,
          title: FinanceStrings.t(context, 'card_accounts_title'),
          helpTitleKey: 'help_card_accounts_title',
          helpBodyKey: 'help_card_accounts_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceAccountsScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.category_outlined,
          title: FinanceStrings.t(context, 'card_categories_title'),
          helpTitleKey: 'help_card_categories_title',
          helpBodyKey: 'help_card_categories_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceCashFlowCategoriesScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.receipt_long_outlined,
          title: FinanceStrings.t(context, 'card_transactions_title'),
          helpTitleKey: 'help_card_transactions_title',
          helpBodyKey: 'help_card_transactions_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceCashTransactionsScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.assessment_outlined,
          title: FinanceStrings.t(context, 'card_realized_title'),
          helpTitleKey: 'help_card_realized_title',
          helpBodyKey: 'help_card_realized_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceRealizedCashFlowScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.event_note_outlined,
          title: FinanceStrings.t(context, 'card_planned_items_title'),
          helpTitleKey: 'help_card_planned_items_title',
          helpBodyKey: 'help_card_planned_items_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinancePlannedCashItemsScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        if (canBank) ...[
          const SizedBox(height: 12),
          FinanceHubEntryCard(
            icon: Icons.account_balance_outlined,
            title: FinanceStrings.t(context, 'card_bank_statements_title'),
            helpTitleKey: 'help_card_bank_statements_title',
            helpBodyKey: 'help_card_bank_statements_body',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FinanceBankStatementsScreen(
                  companyData: companyData,
                  debugUnlockModule: debugUnlockModule,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.insights_outlined,
          title: FinanceStrings.t(context, 'card_advanced_cash_flow_title'),
          helpTitleKey: 'help_card_advanced_cash_flow_title',
          helpBodyKey: 'help_card_advanced_cash_flow_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceAdvancedCashFlowScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.timeline_outlined,
          title: FinanceStrings.t(context, 'card_forecast_title'),
          helpTitleKey: 'help_card_forecast_title',
          helpBodyKey: 'help_card_forecast_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceCashFlowForecastScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
