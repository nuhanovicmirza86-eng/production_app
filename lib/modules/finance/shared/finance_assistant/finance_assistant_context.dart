/// Siguran kontekst za Finance asistenta — bez punih financijskih dokumenata.
class FinanceAssistantContext {
  const FinanceAssistantContext({
    required this.companyId,
    required this.screenKey,
    this.moduleKey = 'finance_controlling',
    this.tabKey = 'hub_overview',
    this.moduleLabelKey = 'finance_assistant_module',
    this.tabLabelKey,
    this.role,
    this.entityStatus,
    this.availableActions = const [],
    this.disabledActions = const [],
    this.extraFacts = const {},
    this.prefilledQuestionKey,
  });

  final String companyId;
  final String screenKey;
  final String moduleKey;
  final String tabKey;
  final String moduleLabelKey;
  final String? tabLabelKey;
  final String? role;
  final String? entityStatus;
  final List<String> availableActions;
  final List<String> disabledActions;
  final Map<String, String> extraFacts;
  final String? prefilledQuestionKey;

  Map<String, dynamic> toCallableContext() {
    return {
      'moduleKey': moduleKey,
      'tabKey': tabKey,
      'screenKey': screenKey,
      if (entityStatus != null && entityStatus!.isNotEmpty)
        'entityState': entityStatus,
      'availableActions': availableActions,
      'disabledActions': disabledActions,
    };
  }

  FinanceAssistantContext copyWith({
    String? companyId,
    String? screenKey,
    String? moduleKey,
    String? tabKey,
    String? moduleLabelKey,
    String? tabLabelKey,
    String? role,
    String? entityStatus,
    List<String>? availableActions,
    List<String>? disabledActions,
    Map<String, String>? extraFacts,
    String? prefilledQuestionKey,
  }) {
    return FinanceAssistantContext(
      companyId: companyId ?? this.companyId,
      screenKey: screenKey ?? this.screenKey,
      moduleKey: moduleKey ?? this.moduleKey,
      tabKey: tabKey ?? this.tabKey,
      moduleLabelKey: moduleLabelKey ?? this.moduleLabelKey,
      tabLabelKey: tabLabelKey ?? this.tabLabelKey,
      role: role ?? this.role,
      entityStatus: entityStatus ?? this.entityStatus,
      availableActions: availableActions ?? this.availableActions,
      disabledActions: disabledActions ?? this.disabledActions,
      extraFacts: extraFacts ?? this.extraFacts,
      prefilledQuestionKey: prefilledQuestionKey ?? this.prefilledQuestionKey,
    );
  }
}

/// Kanonski ključevi tabova unutar Finance & Controlling huba.
abstract final class FinanceAssistantTabs {
  static const overview = 'hub_overview';
  static const production = 'hub_production';
  static const downtime = 'hub_downtime';
  static const quality = 'hub_quality';
  static const maintenance = 'hub_maintenance';
  static const procurement = 'hub_procurement';
  static const budgets = 'hub_budgets';
  static const cashFlow = 'cash_flow';
  static const invoices = 'hub_invoices';
  static const erp = 'hub_erp';
  static const erpOnly = 'erp_integrations';
  static const aiAnalysis = 'finance_ai_analysis';
}

/// Kanonski ključevi ekrana — cijeli Finance modul (M2-G).
abstract final class FinanceAssistantScreens {
  // Hub tabovi
  static const hubOverview = 'finance_controlling_dashboard';
  static const hubProduction = 'finance_controlling_production';
  static const hubDowntime = 'finance_controlling_downtime';
  static const hubQuality = 'finance_controlling_quality';
  static const hubMaintenance = 'finance_controlling_maintenance';
  static const hubProcurement = 'finance_controlling_procurement';
  static const hubBudgets = 'finance_budgets';
  static const hubCashFlow = 'finance_cash_flow_hub';
  static const hubInvoices = 'finance_invoices_hub';
  static const hubErp = 'finance_erp_hub';
  static const hubErpOnly = 'finance_erp_integrations_only';

  // P1–P3 Cash Flow
  static const accountsList = 'finance_accounts_list';
  static const accountForm = 'finance_account_form';
  static const categoriesList = 'finance_cash_flow_categories_list';
  static const categoryForm = 'finance_cash_flow_category_form';
  static const transactionsList = 'finance_transactions_list';
  static const transactionDetail = 'finance_transaction_detail';
  static const transactionForm = 'finance_transaction_form';
  static const realizedCashFlow = 'finance_realized_cash_flow';
  static const plannedItemsList = 'finance_planned_cash_items_list';
  static const plannedItemDetail = 'finance_planned_item_detail';
  static const plannedItemForm = 'finance_planned_item_form';
  static const cashFlowForecast = 'finance_cash_flow_forecast';

  // P4 bank reconciliation
  static const bankStatementsList = 'bank_statements_list';
  static const bankStatementDetail = 'bank_statement_detail';
  static const bankMatchSuggestionDetail = 'bank_match_suggestion_detail';
  static const bankMatchConfirm = 'bank_match_confirm';
  static const bankMatchConfirmationDetail = 'bank_match_confirmation_detail';

  // Fakture i alokacije
  static const salesInvoicesList = 'finance_sales_invoices_list';
  static const salesInvoiceDetail = 'finance_sales_invoice_detail';
  static const salesInvoiceForm = 'finance_sales_invoice_form';
  static const purchaseInvoicesList = 'finance_purchase_invoices_list';
  static const purchaseInvoiceDetail = 'finance_purchase_invoice_detail';
  static const purchaseInvoiceForm = 'finance_purchase_invoice_form';
  static const receivablesList = 'finance_receivables_list';
  static const payablesList = 'finance_payables_list';
  static const allocatePayment = 'finance_allocate_payment';
  static const paymentAllocationDetail = 'finance_payment_allocation_detail';

  // Finance AI
  static const aiAssistant = 'finance_ai_assistant';
  static const aiAlertDetail = 'finance_ai_alert_detail';
  static const aiNotificationDeliveryDetail =
      'finance_ai_notification_delivery_detail';
}
