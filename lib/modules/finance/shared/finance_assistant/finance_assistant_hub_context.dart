import 'package:flutter/material.dart';

import '../finance_strings.dart';
import 'finance_assistant_context.dart';

/// Kontekst Finance asistenta za tabove Finance & Controlling huba.
abstract final class FinanceAssistantHubContext {
  FinanceAssistantHubContext._();

  static const _tabKeys = <String>[
    FinanceAssistantTabs.overview,
    FinanceAssistantTabs.production,
    FinanceAssistantTabs.downtime,
    FinanceAssistantTabs.quality,
    FinanceAssistantTabs.maintenance,
    FinanceAssistantTabs.procurement,
    FinanceAssistantTabs.budgets,
    FinanceAssistantTabs.cashFlow,
    FinanceAssistantTabs.invoices,
    FinanceAssistantTabs.erp,
  ];

  static const _screenKeys = <String>[
    FinanceAssistantScreens.hubOverview,
    FinanceAssistantScreens.hubProduction,
    FinanceAssistantScreens.hubDowntime,
    FinanceAssistantScreens.hubQuality,
    FinanceAssistantScreens.hubMaintenance,
    FinanceAssistantScreens.hubProcurement,
    FinanceAssistantScreens.hubBudgets,
    FinanceAssistantScreens.hubCashFlow,
    FinanceAssistantScreens.hubInvoices,
    FinanceAssistantScreens.hubErp,
  ];

  static const _tabLabelKeys = <String>[
    'finance_assistant_tab_overview',
    'finance_assistant_tab_production',
    'finance_assistant_tab_downtime',
    'finance_assistant_tab_quality',
    'finance_assistant_tab_maintenance',
    'finance_assistant_tab_procurement',
    'finance_assistant_tab_budgets',
    'help_cash_flow_tab_title',
    'finance_assistant_tab_invoices',
    'finance_assistant_tab_erp',
  ];

  static FinanceAssistantContext forTab({
    required BuildContext context,
    required Map<String, dynamic> companyData,
    required int tabIndex,
  }) {
    final index = tabIndex.clamp(0, _tabKeys.length - 1);
    return FinanceAssistantContext(
      companyId: (companyData['companyId'] ?? '').toString().trim(),
      screenKey: _screenKeys[index],
      tabKey: _tabKeys[index],
      tabLabelKey: _tabLabelKeys[index],
      role: (companyData['role'] ?? '').toString().trim(),
      availableActions: [
        FinanceStrings.t(context, 'refresh'),
      ],
    );
  }

  static FinanceAssistantContext erpOnlyHub({
    required BuildContext context,
    required Map<String, dynamic> companyData,
  }) {
    return FinanceAssistantContext(
      companyId: (companyData['companyId'] ?? '').toString().trim(),
      screenKey: FinanceAssistantScreens.hubErpOnly,
      tabKey: FinanceAssistantTabs.erpOnly,
      tabLabelKey: 'finance_assistant_tab_erp',
      role: (companyData['role'] ?? '').toString().trim(),
      availableActions: [
        FinanceStrings.t(context, 'refresh'),
      ],
    );
  }
}
