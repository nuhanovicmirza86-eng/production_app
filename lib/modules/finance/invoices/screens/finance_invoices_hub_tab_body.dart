import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../payables/screens/finance_payables_screen.dart';
import '../../receivables/screens/finance_receivables_screen.dart';
import '../../shared/finance_hub_entry_card.dart';
import '../../shared/finance_strings.dart';
import 'finance_purchase_invoices_screen.dart';
import 'finance_sales_invoices_screen.dart';

/// Tab **Fakture i otvorene stavke** unutar Finance & Controlling huba.
class FinanceInvoicesHubTabBody extends StatelessWidget {
  const FinanceInvoicesHubTabBody({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  String get _role => (companyData['role'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewFinanceInvoices(
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
        FinanceHubEntryCard(
          icon: Icons.receipt_long_outlined,
          title: FinanceStrings.t(context, 'card_sales_invoices_title'),
          helpTitleKey: 'help_card_sales_invoices_title',
          helpBodyKey: 'help_card_sales_invoices_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceSalesInvoicesScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.request_quote_outlined,
          title: FinanceStrings.t(context, 'card_purchase_invoices_title'),
          helpTitleKey: 'help_card_purchase_invoices_title',
          helpBodyKey: 'help_card_purchase_invoices_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinancePurchaseInvoicesScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.account_balance_outlined,
          title: FinanceStrings.t(context, 'card_receivables_title'),
          helpTitleKey: 'help_card_receivables_title',
          helpBodyKey: 'help_card_receivables_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinanceReceivablesScreen(
                companyData: companyData,
                debugUnlockModule: debugUnlockModule,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FinanceHubEntryCard(
          icon: Icons.payments_outlined,
          title: FinanceStrings.t(context, 'card_payables_title'),
          helpTitleKey: 'help_card_payables_title',
          helpBodyKey: 'help_card_payables_body',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinancePayablesScreen(
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
