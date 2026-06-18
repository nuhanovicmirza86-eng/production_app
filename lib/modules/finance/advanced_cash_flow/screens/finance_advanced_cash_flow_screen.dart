import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_context_factory.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_hub_entry_card.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario.dart';
import '../services/finance_cash_flow_scenario_service.dart';
import '../widgets/finance_scenario_comparison_table.dart';
import '../widgets/finance_scenario_summary_tile.dart';
import 'finance_budget_actual_working_capital_screen.dart';
import 'finance_scenario_comparison_screen.dart';
import 'finance_scenario_detail_screen.dart';
import 'finance_scenario_form_screen.dart';

class FinanceAdvancedCashFlowScreen extends StatefulWidget {
  const FinanceAdvancedCashFlowScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceAdvancedCashFlowScreen> createState() =>
      _FinanceAdvancedCashFlowScreenState();
}

class _FinanceAdvancedCashFlowScreenState
    extends State<FinanceAdvancedCashFlowScreen> {
  final _service = FinanceCashFlowScenarioService();

  bool _loading = true;
  String? _error;
  List<FinanceCashFlowScenario> _scenarios = const [];

  DateTime? _filterFrom;
  DateTime? _filterTo;
  String? _typeFilter;
  String? _statusFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewCashFlowScenarios(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  bool get _canManage => FinancePermissions.canManageCashFlowScenarios(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterFrom = DateTime(now.year, now.month, 1);
    _filterTo = DateTime(now.year, now.month + 1, 0);
    if (_canView) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listScenarios(
        companyId: _companyId,
        status: _statusFilter,
        scenarioType: _typeFilter,
      );
      if (!mounted) return;
      setState(() {
        _scenarios = _applyClientFilters(items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  List<FinanceCashFlowScenario> _applyClientFilters(
    List<FinanceCashFlowScenario> items,
  ) {
    return items.where((s) {
      if (_typeFilter != null &&
          s.scenarioType != _typeFilter) {
        return false;
      }
      if (_statusFilter != null && s.status != _statusFilter) {
        return false;
      }
      if (_filterFrom != null && s.periodTo != null) {
        if (s.periodTo!.isBefore(_filterFrom!)) return false;
      }
      if (_filterTo != null && s.periodFrom != null) {
        if (s.periodFrom!.isAfter(_filterTo!)) return false;
      }
      return true;
    }).toList();
  }

  FinanceCashFlowScenario? _latestOfType(String type) {
    for (final s in _scenarios) {
      if (s.scenarioType == type && !s.isArchived) return s;
    }
    return null;
  }

  Future<void> _openForm() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceScenarioFormScreen(
          companyData: widget.companyData,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openDetail(FinanceCashFlowScenario scenario) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceScenarioDetailScreen(
          companyData: widget.companyData,
          scenarioId: scenario.scenarioId,
          initialScenario: scenario,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openComparison() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FinanceScenarioComparisonScreen(
          companyData: widget.companyData,
          optimistic: _latestOfType('optimistic'),
          base: _latestOfType('base'),
          pessimistic: _latestOfType('pessimistic'),
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assistant = FinanceAssistantContextFactory.fromCompany(
      context: context,
      companyData: widget.companyData,
      screenKey: FinanceAssistantScreens.advancedCashFlowHub,
      tabKey: FinanceAssistantTabs.advancedCashFlow,
      tabLabelKey: 'help_advanced_cash_flow_tab_title',
      actions: FinanceAssistantContextFactory.createAndRefresh(
        createKey: 'scenario_new',
        canCreate: _canManage,
      ),
    );

    if (!_canView) {
      return FinanceScaffold(
        assistantContext: assistant,
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'advanced_cash_flow_title')),
        ),
        body: Center(
          child: Text(FinanceStrings.t(context, 'access_denied')),
        ),
      );
    }

    return FinanceScaffold(
      assistantContext: assistant,
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'advanced_cash_flow_title')),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: FinanceStrings.t(context, 'scenario_new'),
              icon: const Icon(Icons.add),
              onPressed: _openForm,
            ),
          IconButton(
            onPressed: _load,
            tooltip: FinanceStrings.t(context, 'refresh'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilters(context),
            const SizedBox(height: 12),
            FinanceHubEntryCard(
              icon: Icons.compare_arrows_outlined,
              title: FinanceStrings.t(context, 'bawc_title'),
              helpTitleKey: 'help_card_bawc_title',
              helpBodyKey: 'help_card_bawc_body',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FinanceBudgetActualWorkingCapitalScreen(
                    companyData: widget.companyData,
                    debugUnlockModule: widget.debugUnlockModule,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (_scenarios.isEmpty)
              Text(FinanceStrings.t(context, 'scenario_list_empty'))
            else
              ..._scenarios.map(
                (s) => FinanceScenarioSummaryTile(
                  scenario: s,
                  onTap: () => _openDetail(s),
                ),
              ),
            const SizedBox(height: 16),
            FinanceScenarioComparisonTable(
              optimistic: _latestOfType('optimistic'),
              base: _latestOfType('base'),
              pessimistic: _latestOfType('pessimistic'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openComparison,
                child: Text(FinanceStrings.t(context, 'scenario_comparison_open')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FinanceDatePickerField(
                label: FinanceStrings.t(context, 'date_from'),
                value: _filterFrom,
                lastDate: _filterTo,
                onChanged: (d) {
                  setState(() => _filterFrom = d);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FinanceDatePickerField(
                label: FinanceStrings.t(context, 'date_to'),
                value: _filterTo,
                firstDate: _filterFrom,
                onChanged: (d) {
                  setState(() => _filterTo = d);
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _typeFilter,
                decoration: InputDecoration(
                  labelText: FinanceStrings.t(context, 'scenario_filter_type'),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(FinanceStrings.t(context, 'filter_all')),
                  ),
                  ...FinanceDisplayLabels.scenarioTypeCodes.map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(
                        FinanceDisplayLabels.scenarioType(context, code),
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _typeFilter = v);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _statusFilter,
                decoration: InputDecoration(
                  labelText: FinanceStrings.t(context, 'scenario_filter_status'),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(FinanceStrings.t(context, 'filter_all')),
                  ),
                  ...FinanceDisplayLabels.scenarioStatusCodes.map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(
                        FinanceDisplayLabels.scenarioStatus(context, code),
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _load();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
