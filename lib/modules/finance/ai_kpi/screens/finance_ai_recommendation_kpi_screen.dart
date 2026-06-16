import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_plant_filter_dropdown.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../models/finance_ai_recommendation_kpi_snapshot.dart';
import '../services/finance_ai_recommendation_kpi_service.dart';
import '../widgets/finance_ai_attribution_breakdown.dart';
import '../widgets/finance_ai_confirmed_impact_card.dart';
import '../widgets/finance_ai_kpi_formatters.dart';
import '../widgets/finance_ai_kpi_summary_card.dart';
import '../widgets/finance_ai_rate_card.dart';
import '../widgets/finance_ai_rejection_breakdown.dart';

/// Ugradivi read-only KPI prikaz unutar Finance AI Assistant taba.
class FinanceAiRecommendationKpiScreen extends StatefulWidget {
  const FinanceAiRecommendationKpiScreen({
    super.key,
    required this.companyData,
    required this.periodYear,
    required this.periodMonth,
    required this.plantScopeKey,
    this.onPlantScopeChanged,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final int periodYear;
  final int periodMonth;
  final String plantScopeKey;
  final ValueChanged<String>? onPlantScopeChanged;
  final bool debugUnlockModule;

  @override
  State<FinanceAiRecommendationKpiScreen> createState() =>
      _FinanceAiRecommendationKpiScreenState();
}

class _FinanceAiRecommendationKpiScreenState
    extends State<FinanceAiRecommendationKpiScreen> {
  final _svc = FinanceAiRecommendationKpiService();

  bool _loading = false;
  String? _error;
  FinanceAiRecommendationKpiSnapshot? _snapshot;
  late DateTime _periodFrom;
  late DateTime _periodTo;
  Map<String, String> _plantLabels = const {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString().trim();

  String get _profilePlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewFinanceAiRecommendationKpis(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canPickPlant => FinancePermissions.shouldUseHubPlantScopeSelector(
        role: _role,
        profilePlantKey: _profilePlantKey,
      );

  @override
  void initState() {
    super.initState();
    _seedPeriod(widget.periodYear, widget.periodMonth);
    _loadSnapshot();
  }

  @override
  void didUpdateWidget(covariant FinanceAiRecommendationKpiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plantScopeKey != widget.plantScopeKey ||
        oldWidget.periodYear != widget.periodYear ||
        oldWidget.periodMonth != widget.periodMonth) {
      if (oldWidget.periodYear != widget.periodYear ||
          oldWidget.periodMonth != widget.periodMonth) {
        _seedPeriod(widget.periodYear, widget.periodMonth);
      }
      _loadSnapshot();
    }
  }

  void _seedPeriod(int year, int month) {
    _periodFrom = DateTime(year, month, 1);
    final now = DateTime.now();
    if (year == now.year && month == now.month) {
      _periodTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else {
      _periodTo = DateTime(year, month + 1, 0, 23, 59, 59);
    }
  }

  Future<void> _loadSnapshot() async {
    if (!_canView || _companyId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plants = await CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      );
      final labels = {for (final p in plants) p.plantKey: p.label};
      final snap = await _svc.loadSnapshot(
        companyId: _companyId,
        periodFrom: _periodFrom,
        periodTo: _periodTo,
        plantKey: widget.plantScopeKey,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _plantLabels = labels;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = FinanceErrorMapper.toMessage(e, context: context);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = FinanceStrings.t(context, 'kpi_load_error');
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _periodFrom : _periodTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: FinanceStrings.t(
        context,
        isFrom ? 'kpi_period_from' : 'kpi_period_to',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _periodFrom = DateTime(picked.year, picked.month, picked.day);
        if (_periodFrom.isAfter(_periodTo)) {
          _periodTo = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            59,
          );
        }
      } else {
        _periodTo = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
        if (_periodTo.isBefore(_periodFrom)) {
          _periodFrom = DateTime(picked.year, picked.month, picked.day);
        }
      }
    });
    await _loadSnapshot();
  }

  String _scopeLabel(BuildContext context) {
    final pk = widget.plantScopeKey.trim();
    if (pk.isEmpty) {
      return FinanceStrings.t(context, 'advisory_filter_all_plants');
    }
    return _plantLabels[pk] ?? pk;
  }

  void _showContractInfo(BuildContext context, FinanceAiRecommendationKpiSnapshot snap) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, 'kpi_contract_info_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${FinanceStrings.t(ctx, 'kpi_contract_version')}: ${snap.contractVersion}'),
              const SizedBox(height: 8),
              Text('${FinanceStrings.t(ctx, 'kpi_evaluator_version')}: ${snap.evaluatorVersion}'),
              const SizedBox(height: 8),
              Text(
                FinanceStrings.t(ctx, 'kpi_contract_sources'),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              ...snap.sourceCollections.map((c) => Text('• $c')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMMMd(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                FinanceStrings.t(context, 'kpi_section_title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_snapshot != null)
              IconButton(
                tooltip: FinanceStrings.t(context, 'kpi_contract_info_title'),
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: () => _showContractInfo(context, _snapshot!),
              ),
            IconButton(
              tooltip: FinanceStrings.t(context, 'refresh'),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              onPressed: _loading ? null : _loadSnapshot,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          FinanceStrings.t(context, 'kpi_section_subtitle'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pickDate(isFrom: true),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                '${FinanceStrings.t(context, 'kpi_period_from')}: ${dateFmt.format(_periodFrom)}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pickDate(isFrom: false),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                '${FinanceStrings.t(context, 'kpi_period_to')}: ${dateFmt.format(_periodTo)}',
              ),
            ),
            if (_canPickPlant && widget.onPlantScopeChanged != null)
              FinancePlantFilterDropdown(
                companyId: _companyId,
                selectedPlantKey: widget.plantScopeKey,
                onChanged: widget.onPlantScopeChanged!,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          FinanceStrings.t(context, 'kpi_scope_line')
              .replaceAll('{scope}', _scopeLabel(context))
              .replaceAll('{from}', dateFmt.format(_periodFrom))
              .replaceAll('{to}', dateFmt.format(_periodTo)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading && _snapshot == null)
          const LinearProgressIndicator(minHeight: 2),
        if (_error != null) ...[
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          TextButton(
            onPressed: _loadSnapshot,
            child: Text(FinanceStrings.t(context, 'retry')),
          ),
        ] else if (_snapshot != null) ...[
          _buildMetricsBody(context, _snapshot!),
        ],
      ],
    );
  }

  Widget _buildMetricsBody(
    BuildContext context,
    FinanceAiRecommendationKpiSnapshot snap,
  ) {
    final m = snap.metrics;
    final types = m.interactionTypeCounts;
    final rejected = types['rejected'] ?? 0;
    final isEmpty = m.shownCount.value == 0 && m.evaluatedOutcomeCount.value == 0;

    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          FinanceStrings.t(context, 'kpi_empty_period'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final status = m.outcomeCountByStatus;
    final confirmed = status['outcome_confirmed'] ?? 0;
    final notConfirmed = status['outcome_not_confirmed'] ?? 0;
    final unknown = status['outcome_unknown'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceAiKpiSummaryCard(metrics: m),
        const SizedBox(height: 12),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_viewed_rate'),
          metric: m.viewedRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_viewed_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_shown_label'),
        ),
        const SizedBox(height: 8),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_acceptance_rate'),
          metric: m.acceptanceRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_accepted_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_decision_label'),
        ),
        const SizedBox(height: 16),
        Text(
          FinanceStrings.t(context, 'kpi_section_execution'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        _countTile(
          context,
          FinanceStrings.t(context, 'kpi_action_started_count'),
          types['action_started'] ?? 0,
        ),
        _countTile(
          context,
          FinanceStrings.t(context, 'kpi_action_completed_count'),
          types['action_completed'] ?? 0,
        ),
        const SizedBox(height: 8),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_action_start_rate'),
          metric: m.actionStartRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_action_started_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_accepted_label'),
        ),
        const SizedBox(height: 8),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_action_completion_rate'),
          metric: m.actionCompletionRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_action_completed_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_action_started_label'),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  FinanceStrings.t(context, 'kpi_avg_time_to_action'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  FinanceAiKpiFormatters.durationMs(
                    context,
                    m.avgTimeShownToActionCompletedMs.valueMs,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (m.avgTimeShownToActionCompletedMs.pairCount > 0)
                  Text(
                    FinanceStrings.t(context, 'kpi_avg_time_pairs')
                        .replaceAll(
                          '{count}',
                          '${m.avgTimeShownToActionCompletedMs.pairCount}',
                        ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          FinanceStrings.t(context, 'kpi_section_outcomes'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        _countTile(
          context,
          FinanceStrings.t(context, 'kpi_outcome_confirmed_count'),
          confirmed,
        ),
        _countTile(
          context,
          FinanceStrings.t(context, 'kpi_outcome_not_confirmed_count'),
          notConfirmed,
          hint: FinanceStrings.t(context, 'kpi_outcome_not_confirmed_hint'),
        ),
        _countTile(
          context,
          FinanceStrings.t(context, 'kpi_outcome_unknown_count'),
          unknown,
          hint: FinanceStrings.t(context, 'kpi_outcome_unknown_hint'),
        ),
        const SizedBox(height: 8),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_confirmed_outcome_rate'),
          metric: m.confirmedOutcomeRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_outcome_confirmed_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_outcome_evaluated_label'),
        ),
        const SizedBox(height: 8),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_positive_confirmed_outcome_rate'),
          metric: m.positiveConfirmedOutcomeRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_positive_outcome_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_financial_result_label'),
          subtitle: FinanceStrings.t(context, 'kpi_positive_outcome_hint'),
        ),
        const SizedBox(height: 8),
        FinanceAiRateCard(
          title: FinanceStrings.t(context, 'kpi_outcome_unknown_rate'),
          metric: m.outcomeUnknownRate,
          numeratorLabel: FinanceStrings.t(context, 'kpi_outcome_unknown_label'),
          denominatorLabel: FinanceStrings.t(context, 'kpi_outcome_evaluated_label'),
        ),
        const SizedBox(height: 16),
        FinanceAiRejectionBreakdown(
          rejectionRateByReason: m.rejectionRateByReason,
          rejectionCountByReason: m.rejectionCountByReason,
          totalRejected: rejected,
        ),
        const SizedBox(height: 12),
        FinanceAiAttributionBreakdown(
          outcomeCountByAttribution: m.outcomeCountByAttribution,
          confirmedImpact: m.confirmedFinancialImpactSum,
        ),
        const SizedBox(height: 12),
        FinanceAiConfirmedImpactCard(
          impact: m.confirmedFinancialImpactSum,
        ),
        const SizedBox(height: 8),
        Text(
          FinanceStrings.t(context, 'kpi_neutral_disclaimer'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  Widget _countTile(
    BuildContext context,
    String label,
    int value, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          if (hint != null && hint.isNotEmpty)
            Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}
