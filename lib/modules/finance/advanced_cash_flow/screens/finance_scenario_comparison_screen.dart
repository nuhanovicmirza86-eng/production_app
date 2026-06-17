import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_context_factory.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario.dart';
import '../widgets/finance_scenario_comparison_table.dart';

class FinanceScenarioComparisonScreen extends StatelessWidget {
  const FinanceScenarioComparisonScreen({
    super.key,
    required this.companyData,
    this.optimistic,
    this.base,
    this.pessimistic,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceCashFlowScenario? optimistic;
  final FinanceCashFlowScenario? base;
  final FinanceCashFlowScenario? pessimistic;
  final bool debugUnlockModule;

  @override
  Widget build(BuildContext context) {
    final role = (companyData['role'] ?? '').toString().trim();
    final canView = FinancePermissions.canViewCashFlowScenarios(
      companyData: companyData,
      role: role,
      debugUnlockModule: debugUnlockModule,
    );

    final assistant = FinanceAssistantContextFactory.fromCompany(
      context: context,
      companyData: companyData,
      screenKey: FinanceAssistantScreens.scenariosHub,
      tabKey: FinanceAssistantTabs.advancedCashFlow,
      tabLabelKey: 'help_advanced_cash_flow_tab_title',
    );

    return FinanceScaffold(
      assistantContext: assistant,
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'scenario_comparison_title')),
      ),
      body: canView
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: FinanceScenarioComparisonTable(
                optimistic: optimistic,
                base: base,
                pessimistic: pessimistic,
              ),
            )
          : Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
    );
  }
}
