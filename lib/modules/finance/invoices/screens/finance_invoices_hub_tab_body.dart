import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_strings.dart';
import '../../receivables/screens/finance_receivables_screen.dart';
import '../../payables/screens/finance_payables_screen.dart';
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
        Text(
          FinanceStrings.t(context, 'invoices_hub_subtitle'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _EntryCard(
          icon: Icons.receipt_long_outlined,
          title: FinanceStrings.t(context, 'card_sales_invoices_title'),
          subtitle: FinanceStrings.t(context, 'card_sales_invoices_subtitle'),
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
        _EntryCard(
          icon: Icons.request_quote_outlined,
          title: FinanceStrings.t(context, 'card_purchase_invoices_title'),
          subtitle: FinanceStrings.t(context, 'card_purchase_invoices_subtitle'),
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
        _EntryCard(
          icon: Icons.account_balance_outlined,
          title: FinanceStrings.t(context, 'card_receivables_title'),
          subtitle: FinanceStrings.t(context, 'card_receivables_subtitle'),
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
        _EntryCard(
          icon: Icons.payments_outlined,
          title: FinanceStrings.t(context, 'card_payables_title'),
          subtitle: FinanceStrings.t(context, 'card_payables_subtitle'),
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
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
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
