import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_context_factory.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_scenario.dart';
import '../services/finance_cash_flow_scenario_service.dart';
import '../models/finance_cash_flow_scenario_result.dart';
import '../widgets/finance_scenario_assumptions_section.dart';
import '../widgets/finance_scenario_result_section.dart';
import 'finance_scenario_form_screen.dart';

class FinanceScenarioDetailScreen extends StatefulWidget {
  const FinanceScenarioDetailScreen({
    super.key,
    required this.companyData,
    required this.scenarioId,
    this.initialScenario,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String scenarioId;
  final FinanceCashFlowScenario? initialScenario;
  final bool debugUnlockModule;

  @override
  State<FinanceScenarioDetailScreen> createState() =>
      _FinanceScenarioDetailScreenState();
}

class _FinanceScenarioDetailScreenState extends State<FinanceScenarioDetailScreen> {
  final _service = FinanceCashFlowScenarioService();

  bool _loading = true;
  String? _error;
  FinanceCashFlowScenario? _scenario;

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
    _scenario = widget.initialScenario;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.getScenario(
        companyId: _companyId,
        scenarioId: widget.scenarioId,
      );
      if (!mounted) return;
      setState(() {
        _scenario = s;
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

  String _assistantScreenKey(FinanceCashFlowScenario s) {
    if (s.isWhatIf) return FinanceAssistantScreens.whatIf;
    switch (s.scenarioType) {
      case 'optimistic':
        return FinanceAssistantScreens.scenarioOptimistic;
      case 'pessimistic':
        return FinanceAssistantScreens.scenarioPessimistic;
      case 'base':
        return FinanceAssistantScreens.scenarioBase;
      default:
        return FinanceAssistantScreens.scenarioDetail;
    }
  }

  Future<void> _runAction(
    Future<FinanceCashFlowScenario> Function() action,
  ) async {
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _scenario = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'scenario_action_ok'))),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = FinanceErrorMapper.toMessage(e, context: context);
      final hint = FinanceErrorMapper.isConcurrencyAborted(e)
          ? '\n${FinanceErrorMapper.concurrencyHint(context)}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg$hint')),
      );
      if (FinanceErrorMapper.isConcurrencyAborted(e)) {
        await _load();
      }
    }
  }

  Future<void> _edit() async {
    final s = _scenario;
    if (s == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceScenarioFormScreen(
          companyData: widget.companyData,
          scenario: s,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _newVersion() async {
    final s = _scenario;
    if (s == null || !s.isApproved) return;
    await _runAction(() => _service.updateScenario(
      companyId: _companyId,
      scenarioId: s.scenarioId,
      expectedRevision: s.revision,
    ));
  }

  List<Widget> _actionButtons(FinanceCashFlowScenario s) {
    final buttons = <Widget>[];
    if (!_canManage || s.isArchived) return buttons;

    void add(String label, VoidCallback onPressed) {
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: OutlinedButton(onPressed: onPressed, child: Text(label)),
        ),
      );
    }

    if (s.isDraft) {
      add(FinanceStrings.t(context, 'scenario_action_edit'), _edit);
      add(
        FinanceStrings.t(context, 'scenario_action_calculate'),
        () => _runAction(() => _service.calculateScenario(
          companyId: _companyId,
          scenarioId: s.scenarioId,
        )),
      );
      add(
        FinanceStrings.t(context, 'scenario_action_archive'),
        () => _runAction(() => _service.archiveScenario(
          companyId: _companyId,
          scenarioId: s.scenarioId,
        )),
      );
    } else if (s.isCalculated) {
      add(
        FinanceStrings.t(context, 'scenario_action_recalculate'),
        () => _runAction(() => _service.calculateScenario(
          companyId: _companyId,
          scenarioId: s.scenarioId,
        )),
      );
      add(
        FinanceStrings.t(context, 'scenario_action_approve'),
        () => _runAction(() => _service.approveScenario(
          companyId: _companyId,
          scenarioId: s.scenarioId,
        )),
      );
      add(FinanceStrings.t(context, 'scenario_action_edit'), _edit);
      add(
        FinanceStrings.t(context, 'scenario_action_archive'),
        () => _runAction(() => _service.archiveScenario(
          companyId: _companyId,
          scenarioId: s.scenarioId,
        )),
      );
    } else if (s.isApproved) {
      add(
        FinanceStrings.t(context, 'scenario_action_new_version'),
        _newVersion,
      );
      add(
        FinanceStrings.t(context, 'scenario_action_archive'),
        () => _runAction(() => _service.archiveScenario(
          companyId: _companyId,
          scenarioId: s.scenarioId,
        )),
      );
    }
    return buttons;
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  @override
  Widget build(BuildContext context) {
    final s = _scenario;
    final assistant = s == null
        ? FinanceAssistantContextFactory.fromCompany(
            context: context,
            companyData: widget.companyData,
            screenKey: FinanceAssistantScreens.scenarioDetail,
            tabKey: FinanceAssistantTabs.advancedCashFlow,
          )
        : FinanceAssistantContextFactory.fromCompany(
            context: context,
            companyData: widget.companyData,
            screenKey: _assistantScreenKey(s),
            tabKey: FinanceAssistantTabs.advancedCashFlow,
            tabLabelKey: 'help_advanced_cash_flow_tab_title',
            entityStatus: s.status,
          );

    if (!_canView) {
      return FinanceScaffold(
        assistantContext: assistant,
        appBar: AppBar(title: Text(FinanceStrings.t(context, 'scenario_detail'))),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    return FinanceScaffold(
      assistantContext: assistant,
      appBar: AppBar(
        title: Text(s?.name ?? FinanceStrings.t(context, 'scenario_detail')),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: FinanceStrings.t(context, 'refresh'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : s == null
                  ? Center(child: Text(FinanceStrings.t(context, 'scenario_not_found')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  FinanceDisplayLabels.scenarioType(
                                    context,
                                    s.scenarioType,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  FinanceDisplayLabels.scenarioStatus(
                                    context,
                                    s.status,
                                  ),
                                ),
                              ),
                              Text(
                                FinanceStrings.t(context, 'scenario_revision')
                                    .replaceAll('{n}', s.revision.toString()),
                              ),
                            ],
                          ),
                          if (s.description != null && s.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(s.description!),
                            ),
                          const SizedBox(height: 12),
                          Wrap(children: _actionButtons(s)),
                          const Divider(height: 24),
                          Text(
                            FinanceStrings.t(context, 'scenario_section_base'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _baseRows(context, s.baseForecastSnapshot),
                          const SizedBox(height: 16),
                          FinanceScenarioAssumptionsSection(
                            assumptions: s.assumptions,
                            readOnly: true,
                          ),
                          if (s.calculatedSnapshot != null) ...[
                            const SizedBox(height: 16),
                            FinanceScenarioResultSection(
                              snapshot: s.calculatedSnapshot!,
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _baseRows(
    BuildContext context,
    FinanceCashFlowScenarioSnapshot snap,
  ) {
    final currency = snap.baseCurrency;
    return Column(
      children: [
        _row(
          context,
          FinanceStrings.t(context, 'scenario_base_period'),
          '${_formatDate(snap.periodFrom)} – ${_formatDate(snap.periodTo)}',
        ),
        _row(
          context,
          FinanceStrings.t(context, 'opening_balance'),
          FinanceMoneyFormat.format(snap.openingBalance, currency),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_actual_inflows'),
          FinanceMoneyFormat.format(snap.totalActualInflows, currency),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_actual_outflows'),
          FinanceMoneyFormat.format(snap.totalActualOutflows, currency),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_planned_inflows'),
          FinanceMoneyFormat.format(snap.totalPlannedNominalInflows, currency),
        ),
        _row(
          context,
          FinanceStrings.t(context, 'scenario_planned_outflows'),
          FinanceMoneyFormat.format(snap.totalPlannedNominalOutflows, currency),
        ),
        if (snap.accountBreakdown.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            FinanceStrings.t(context, 'scenario_currencies_used'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final line in snap.accountBreakdown)
            _row(
              context,
              line.sourceCurrency,
              FinanceMoneyFormat.format(line.sourceAmount, line.sourceCurrency),
            ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
