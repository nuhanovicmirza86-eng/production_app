import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../accounts/screens/finance_accounts_screen.dart';
import '../../cash_flow_categories/screens/finance_cash_flow_categories_screen.dart';
import '../../cash_transactions/screens/finance_cash_transactions_screen.dart';
import '../../cash_transactions/screens/finance_realized_cash_flow_screen.dart';
import '../../forecast/screens/finance_cash_flow_forecast_screen.dart';
import '../../planned_cash_items/screens/finance_planned_cash_items_screen.dart';
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          FinanceStrings.t(context, 'finance_hub_subtitle'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _CashFlowEntryCard(
          icon: Icons.account_balance_wallet_outlined,
          title: FinanceStrings.t(context, 'card_accounts_title'),
          subtitle: FinanceStrings.t(context, 'card_accounts_subtitle'),
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
        _CashFlowEntryCard(
          icon: Icons.category_outlined,
          title: FinanceStrings.t(context, 'card_categories_title'),
          subtitle: FinanceStrings.t(context, 'card_categories_subtitle'),
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
        _CashFlowEntryCard(
          icon: Icons.receipt_long_outlined,
          title: FinanceStrings.t(context, 'card_transactions_title'),
          subtitle: FinanceStrings.t(context, 'card_transactions_subtitle'),
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
        _CashFlowEntryCard(
          icon: Icons.assessment_outlined,
          title: FinanceStrings.t(context, 'card_realized_title'),
          subtitle: FinanceStrings.t(context, 'card_realized_subtitle'),
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
        _CashFlowEntryCard(
          icon: Icons.event_note_outlined,
          title: FinanceStrings.t(context, 'card_planned_items_title'),
          subtitle: FinanceStrings.t(context, 'card_planned_items_subtitle'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinancePlannedCashItemsScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CashFlowEntryCard(
          icon: Icons.timeline_outlined,
          title: FinanceStrings.t(context, 'card_forecast_title'),
          subtitle: FinanceStrings.t(context, 'card_forecast_subtitle'),
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

class _CashFlowEntryCard extends StatelessWidget {
  const _CashFlowEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
