import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../finance_integrations/utils/finance_load_error_presenter.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_context_factory.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_operating_currencies.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_budget_actual_working_capital_snapshot.dart';
import '../services/finance_budget_actual_working_capital_service.dart';
import '../widgets/finance_bawc_display_widgets.dart';

/// P5-M2-M2 — Budžet naspram realizacije i obrtni kapital (backend snapshot only).
class FinanceBudgetActualWorkingCapitalScreen extends StatefulWidget {
  const FinanceBudgetActualWorkingCapitalScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceBudgetActualWorkingCapitalScreen> createState() =>
      _FinanceBudgetActualWorkingCapitalScreenState();
}

class _FinanceBudgetActualWorkingCapitalScreenState
    extends State<FinanceBudgetActualWorkingCapitalScreen> {
  final _service = FinanceBudgetActualWorkingCapitalService();

  bool _loading = false;
  bool _initialLoad = true;
  String? _error;
  FinanceBudgetActualWorkingCapitalSnapshot? _snapshot;

  late DateTime _periodFrom;
  late DateTime _periodTo;
  String _currency = FinanceOperatingCurrencies.codes.first;
  String? _plantKey;

  List<({String plantKey, String label})> _plants = const [];
  bool _plantsLoading = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewCashFlowScenarios(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodFrom = DateTime(now.year, now.month, 1);
    _periodTo = DateTime(now.year, now.month + 1, 0);
    _loadPlants();
    if (_canView) {
      _load();
    } else {
      _initialLoad = false;
    }
  }

  Future<void> _loadPlants() async {
    setState(() => _plantsLoading = true);
    try {
      final plants = await CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _plantsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plants = const [];
        _plantsLoading = false;
      });
    }
  }

  Future<void> _load() async {
    if (!_canView) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await _service.getSnapshot(
        companyId: _companyId,
        periodFrom: _periodFrom,
        periodTo: _periodTo,
        currency: _currency,
        plantKey: _plantKey,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
        _initialLoad = false;
      });
    }
  }

  FinanceAssistantContext _assistantContext(BuildContext context) {
    return FinanceAssistantContextFactory.fromCompany(
      context: context,
      companyData: widget.companyData,
      screenKey: FinanceAssistantScreens.budgetVsActual,
      tabKey: FinanceAssistantTabs.advancedCashFlow,
      tabLabelKey: 'help_advanced_cash_flow_tab_title',
      screenFacts: _assistantScreenFacts(context),
      actions: FinanceAssistantContextFactory.refreshOnly(),
    );
  }

  Map<String, String> _assistantScreenFacts(BuildContext context) {
    final snap = _snapshot;
    if (snap == null) return const {};

    final b = snap.budgetActual;
    final wc = snap.workingCapital;
    final currency = snap.currency;
    final unavailable = FinanceStrings.t(context, 'bawc_dio_ccc_unavailable');
    final notApplicable = FinanceStrings.t(context, 'bawc_variance_not_applicable');

    String plantScope = FinanceStrings.t(context, 'advisory_filter_all_plants');
    if (_plantKey != null && _plantKey!.isNotEmpty) {
      for (final p in _plants) {
        if (p.plantKey == _plantKey) {
          plantScope = p.label;
          break;
        }
      }
    }

    String fmtPct(double? percent) =>
        percent == null ? notApplicable : FinanceBawcDisplay.formatPercent(context, percent);

    final coverageCount = _coverageMessages(context, snap).length;

    return {
      'periodFrom': snap.periodFrom,
      'periodTo': snap.periodTo,
      'currency': currency,
      'plantScope': plantScope,
      'plannedInflow': FinanceBawcDisplay.formatMoney(b.plannedInflow, currency),
      'actualInflow': FinanceBawcDisplay.formatMoney(b.actualInflow, currency),
      'plannedOutflow': FinanceBawcDisplay.formatMoney(b.plannedOutflow, currency),
      'actualOutflow': FinanceBawcDisplay.formatMoney(b.actualOutflow, currency),
      'inflowVarianceAmount':
          FinanceBawcDisplay.formatVarianceAmount(b.inflowVarianceAmount, currency),
      'outflowVarianceAmount':
          FinanceBawcDisplay.formatVarianceAmount(b.outflowVarianceAmount, currency),
      'netVarianceAmount':
          FinanceBawcDisplay.formatVarianceAmount(b.netVarianceAmount, currency),
      'inflowVariancePercent': fmtPct(b.inflowVariancePercent),
      'outflowVariancePercent': fmtPct(b.outflowVariancePercent),
      'netVariancePercent': fmtPct(b.netVariancePercent),
      'dsoPeriodEnd': FinanceBawcDisplay.formatDays(context, wc.dsoPeriodEnd),
      'dsoCollectionDaysAverage':
          FinanceBawcDisplay.formatDays(context, wc.dsoCollectionDaysAverage),
      'dpoPeriodEnd': FinanceBawcDisplay.formatDays(context, wc.dpoPeriodEnd),
      'dpoPaymentDaysAverage':
          FinanceBawcDisplay.formatDays(context, wc.dpoPaymentDaysAverage),
      'dioStatus': unavailable,
      'cccStatus': unavailable,
      if (coverageCount > 0) 'coverageWarningCount': '$coverageCount',
    };
  }

  List<String> _coverageMessages(
    BuildContext context,
    FinanceBudgetActualWorkingCapitalSnapshot snap,
  ) {
    final messages = <String>[];
    final cov = snap.sourceCoverage;
    final wc = snap.workingCapital;

    if (cov.budgetLinesIncluded == 0) {
      messages.add(FinanceStrings.t(context, 'bawc_warn_no_budget'));
    }
    if (wc.dsoCollectionDaysAverageReason == 'insufficient_paid_invoices') {
      messages.add(FinanceStrings.t(context, 'bawc_warn_no_collection_payments'));
    }
    if (wc.dpoPaymentDaysAverageReason == 'insufficient_paid_invoices') {
      messages.add(FinanceStrings.t(context, 'bawc_warn_no_payment_payments'));
    }
    if (wc.cccAvailability == 'unavailable_missing_dio' ||
        wc.dioAvailability == 'unavailable_missing_inventory_cost') {
      messages.add(FinanceStrings.t(context, 'bawc_warn_dio_ccc_unavailable'));
    }

    for (final w in snap.warnings) {
      final friendly = _friendlyWarning(context, w.code);
      if (friendly != null && !messages.contains(friendly)) {
        messages.add(friendly);
      }
    }

    return messages;
  }

  String? _friendlyWarning(BuildContext context, String code) {
    switch (code) {
      case 'budget_line_missing_period':
      case 'budget_line_missing_direction':
        return FinanceStrings.t(context, 'bawc_warn_budget_incomplete');
      default:
        return null;
    }
  }

  bool _isEmptySnapshot(FinanceBudgetActualWorkingCapitalSnapshot snap) {
    final b = snap.budgetActual;
    final cov = snap.sourceCoverage;
    return cov.budgetLinesIncluded == 0 &&
        cov.cashTransactionsIncluded == 0 &&
        b.plannedInflow == 0 &&
        b.actualInflow == 0 &&
        b.plannedOutflow == 0 &&
        b.actualOutflow == 0;
  }

  String _categoryLabel(
    BuildContext context,
    FinanceBudgetActualBreakdownRow row,
  ) {
    return FinanceBawcDisplay.categoryBreakdownLabel(context, row);
  }

  String _plantLabel(
    BuildContext context,
    FinanceBudgetActualBreakdownRow row,
  ) {
    if (row.plantKey == null || row.plantKey!.isEmpty) {
      return FinanceStrings.t(context, 'advisory_filter_all_plants');
    }
    for (final p in _plants) {
      if (p.plantKey == row.plantKey) return p.label;
    }
    return row.plantKey!;
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FinanceDatePickerField(
                label: FinanceStrings.t(context, 'date_from'),
                value: _periodFrom,
                lastDate: _periodTo,
                onChanged: (d) => setState(() => _periodFrom = d),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FinanceDatePickerField(
                label: FinanceStrings.t(context, 'date_to'),
                value: _periodTo,
                firstDate: _periodFrom,
                onChanged: (d) => setState(() => _periodTo = d),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          isExpanded: true,
          value: _plantKey,
          decoration: InputDecoration(
            labelText: FinanceStrings.t(context, 'bawc_filter_plant'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                FinanceStrings.t(context, 'advisory_filter_all_plants'),
              ),
            ),
            ..._plants.map(
              (p) => DropdownMenuItem<String?>(
                value: p.plantKey,
                child: Text(p.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: _loading || _plantsLoading
              ? null
              : (v) => setState(() => _plantKey = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _currency,
                decoration: InputDecoration(
                  labelText: FinanceStrings.t(context, 'bawc_currency'),
                  border: const OutlineInputBorder(),
                ),
                items: FinanceOperatingCurrencies.codes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _currency = v);
                      },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(FinanceStrings.t(context, 'refresh')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetSection(
    BuildContext context,
    FinanceBudgetActualTotals b,
    String currency,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FinanceStrings.t(context, 'bawc_section_budget'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Divider(height: 24),
            FinanceBawcVarianceRow(
              label: FinanceStrings.t(context, 'bawc_inflow'),
              planned: b.plannedInflow,
              actual: b.actualInflow,
              varianceAmount: b.inflowVarianceAmount,
              variancePercent: b.inflowVariancePercent,
              currency: currency,
              higherActualIsFavorable: true,
            ),
            const Divider(height: 8),
            FinanceBawcVarianceRow(
              label: FinanceStrings.t(context, 'bawc_outflow'),
              planned: b.plannedOutflow,
              actual: b.actualOutflow,
              varianceAmount: b.outflowVarianceAmount,
              variancePercent: b.outflowVariancePercent,
              currency: currency,
              higherActualIsFavorable: false,
            ),
            const Divider(height: 8),
            FinanceBawcVarianceRow(
              label: FinanceStrings.t(context, 'bawc_net_cash_flow'),
              planned: b.plannedNetCashFlow,
              actual: b.actualNetCashFlow,
              varianceAmount: b.netVarianceAmount,
              variancePercent: b.netVariancePercent,
              currency: currency,
              higherActualIsFavorable: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingCapitalSection(
    BuildContext context,
    FinanceWorkingCapitalMetrics wc,
  ) {
    final dioCccUnavailable = FinanceStrings.t(
      context,
      'bawc_dio_ccc_unavailable',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FinanceStrings.t(context, 'bawc_section_working_capital'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            FinanceBawcMetricTile(
              label: FinanceStrings.t(context, 'bawc_dso_period_end'),
              value: FinanceBawcDisplay.formatDays(context, wc.dsoPeriodEnd),
              tooltip: FinanceStrings.t(context, 'bawc_dso_period_end_hint'),
            ),
            FinanceBawcMetricTile(
              label: FinanceStrings.t(context, 'bawc_dso_collection_avg'),
              value: FinanceBawcDisplay.formatDays(
                context,
                wc.dsoCollectionDaysAverage,
              ),
              tooltip: FinanceStrings.t(context, 'bawc_dso_collection_avg_hint'),
            ),
            FinanceBawcMetricTile(
              label: FinanceStrings.t(context, 'bawc_dpo_period_end'),
              value: FinanceBawcDisplay.formatDays(context, wc.dpoPeriodEnd),
              tooltip: FinanceStrings.t(context, 'bawc_dpo_period_end_hint'),
            ),
            FinanceBawcMetricTile(
              label: FinanceStrings.t(context, 'bawc_dpo_payment_avg'),
              value: FinanceBawcDisplay.formatDays(
                context,
                wc.dpoPaymentDaysAverage,
              ),
              tooltip: FinanceStrings.t(context, 'bawc_dpo_payment_avg_hint'),
            ),
            FinanceBawcMetricTile(
              label: FinanceStrings.t(context, 'bawc_dio'),
              value: dioCccUnavailable,
            ),
            FinanceBawcMetricTile(
              label: FinanceStrings.t(context, 'bawc_ccc'),
              value: dioCccUnavailable,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageHint(
    BuildContext context,
    List<String> messages,
  ) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = FinanceStrings
        .t(context, 'bawc_coverage_compact')
        .replaceAll('{count}', '${messages.length}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showFinanceTechnicalDetailDialog(
          context,
          title: FinanceStrings.t(context, 'bawc_coverage_title'),
          detail: messages.map((m) => '• $m').join('\n\n'),
          closeLabel: FinanceStrings.t(context, 'help_info_close'),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (_initialLoad && _loading && _snapshot == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null && _snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    final snap = _snapshot;
    if (snap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(FinanceStrings.t(context, 'bawc_empty_hint')),
        ),
      );
    }

    final currency = snap.currency;
    final coverage = _coverageMessages(context, snap);

    return Stack(
      children: [
        Opacity(
          opacity: _loading ? 0.55 : 1,
          child: IgnorePointer(
            ignoring: _loading,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                _buildCoverageHint(context, coverage),
                if (coverage.isNotEmpty) const SizedBox(height: 4),
                if (_isEmptySnapshot(snap))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      FinanceStrings.t(context, 'bawc_empty_period'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                _buildBudgetSection(context, snap.budgetActual, currency),
                const SizedBox(height: 12),
                _buildWorkingCapitalSection(context, snap.workingCapital),
                const SizedBox(height: 16),
                Text(
                  FinanceStrings.t(context, 'bawc_breakdown_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                FinanceBawcBreakdownTable(
                  title: FinanceStrings.t(context, 'bawc_breakdown_period'),
                  dimensionLabel: FinanceStrings.t(context, 'bawc_period'),
                  rows: snap.breakdownByPeriod,
                  currency: currency,
                  labelForRow: (row) => row.key,
                ),
                const SizedBox(height: 16),
                FinanceBawcBreakdownTable(
                  title: FinanceStrings.t(context, 'bawc_breakdown_category'),
                  dimensionLabel: FinanceStrings.t(context, 'bawc_category'),
                  rows: snap.breakdownByCategory,
                  currency: currency,
                  labelForRow: (row) => _categoryLabel(context, row),
                ),
                const SizedBox(height: 16),
                FinanceBawcBreakdownTable(
                  title: FinanceStrings.t(context, 'bawc_breakdown_plant'),
                  dimensionLabel: FinanceStrings.t(context, 'bawc_plant'),
                  rows: snap.breakdownByPlant,
                  currency: currency,
                  labelForRow: (row) => _plantLabel(context, row),
                ),
              ],
            ),
          ),
        ),
        if (_loading && _snapshot != null)
          const Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return FinanceScaffold(
        assistantContext: _assistantContext(context),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'bawc_title')),
        ),
        body: Center(
          child: Text(FinanceStrings.t(context, 'access_denied')),
        ),
      );
    }

    return FinanceScaffold(
      assistantContext: _assistantContext(context),
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'bawc_title')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildFilters(context),
          ),
          Expanded(child: _buildBodyContent(context)),
        ],
      ),
    );
  }
}
