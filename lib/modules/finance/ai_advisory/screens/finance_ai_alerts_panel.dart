import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../models/finance_ai_alert.dart';
import '../models/finance_ai_analysis_result.dart';
import '../services/finance_ai_advisory_service.dart';
import 'finance_ai_alert_detail_screen.dart';
import '../widgets/finance_ai_alert_card.dart';

/// Ugradivi panel proaktivnih upozorenja unutar Finance AI Assistant taba.
class FinanceAiAlertsPanel extends StatefulWidget {
  const FinanceAiAlertsPanel({
    super.key,
    required this.companyData,
    required this.businessYearId,
    this.sessionPlantKey = '',
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final String sessionPlantKey;
  final bool debugUnlockModule;

  @override
  State<FinanceAiAlertsPanel> createState() => _FinanceAiAlertsPanelState();
}

class _FinanceAiAlertsPanelState extends State<FinanceAiAlertsPanel> {
  final _svc = FinanceAiAdvisoryService();

  bool _showHistory = false;
  String? _severityMin;
  String _filterPlantKey = '';
  bool _loading = false;
  bool _actionInProgress = false;
  String? _error;
  List<FinanceAiAlert> _alerts = const [];
  Map<String, String> _plantLabels = const {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString().trim();

  String get _profilePlantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewFinanceAiAdvisory(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canRun => FinancePermissions.canRunFinanceAiAdvisoryAnalysis(
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
    _filterPlantKey = widget.sessionPlantKey.trim();
    if (!_canPickPlant && _profilePlantKey.isNotEmpty) {
      _filterPlantKey = _profilePlantKey;
    }
    _loadAlerts();
  }

  List<String> get _statusFilter {
    if (_showHistory) return const ['resolved', 'dismissed'];
    return const ['open', 'acknowledged'];
  }

  Future<void> _loadAlerts() async {
    if (!_canView || _companyId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listAlerts(
        companyId: _companyId,
        status: _statusFilter,
        severityMin: _severityMin,
        plantKey: _filterPlantKey.trim().isEmpty ? null : _filterPlantKey.trim(),
      );
      await _resolvePlantLabels(list);
      if (!mounted) return;
      setState(() {
        _alerts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resolvePlantLabels(List<FinanceAiAlert> alerts) async {
    final keys = alerts
        .map((a) => a.plantKey.trim())
        .where((k) => k.isNotEmpty)
        .toSet();
    final labels = Map<String, String>.from(_plantLabels);
    for (final pk in keys) {
      if (labels.containsKey(pk)) continue;
      labels[pk] = await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: pk,
      );
    }
    _plantLabels = labels;
  }

  Future<void> _runAnalysis() async {
    if (!_canRun || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await _svc.runAdvisoryAnalysis(
        companyId: _companyId,
        plantKey: _filterPlantKey.trim().isEmpty ? null : _filterPlantKey.trim(),
        businessYearId: widget.businessYearId.trim().isEmpty
            ? null
            : widget.businessYearId.trim(),
      );
      if (!mounted) return;
      _showRunSummary(result);
      await _loadAlerts();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? FinanceStrings.t(context, 'advisory_load_error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showRunSummary(FinanceAiAnalysisResult result) {
    final msg = FinanceStrings.t(context, 'advisory_run_summary')
        .replaceAll('{rules}', '${result.evaluatedRuleCount}')
        .replaceAll('{created}', '${result.createdAlertCount}')
        .replaceAll('{updated}', '${result.updatedAlertCount}')
        .replaceAll('{resolved}', '${result.resolvedAlertCount}')
        .replaceAll('{skipped}', '${result.skippedInsufficientFactsCount}');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openDetail(FinanceAiAlert alert) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceAiAlertDetailScreen(
          companyData: widget.companyData,
          alertId: alert.alertId,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FinanceStrings.t(context, 'advisory_section_title'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _buildFilters(context),
        const SizedBox(height: 8),
        if (_canRun)
          FilledButton.tonalIcon(
            onPressed: (_actionInProgress || _loading) ? null : _runAnalysis,
            icon: _actionInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              _actionInProgress
                  ? FinanceStrings.t(context, 'advisory_run_analysis_running')
                  : FinanceStrings.t(context, 'advisory_run_analysis'),
            ),
          ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_error != null)
          Text(
            FinanceStrings.t(context, 'advisory_load_error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (_alerts.isEmpty)
          Text(
            FinanceStrings.t(context, 'advisory_empty'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ..._alerts.map((alert) {
            final pk = alert.plantKey.trim();
            return FinanceAiAlertCard(
              alert: alert,
              plantDisplayName: pk.isEmpty ? null : (_plantLabels[pk] ?? pk),
              onTap: () => _openDetail(alert),
            );
          }),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(FinanceStrings.t(context, 'advisory_filter_active')),
            ),
            ButtonSegment(
              value: true,
              label: Text(FinanceStrings.t(context, 'advisory_filter_history')),
            ),
          ],
          selected: {_showHistory},
          onSelectionChanged: (s) {
            setState(() => _showHistory = s.first);
            _loadAlerts();
          },
        ),
        DropdownButton<String?>(
          value: _severityMin,
          hint: Text(FinanceStrings.t(context, 'advisory_filter_severity')),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                FinanceStrings.t(context, 'advisory_filter_all_severities'),
              ),
            ),
            ...FinanceDisplayLabels.advisorySeverityCodes.map(
              (code) => DropdownMenuItem<String?>(
                value: code,
                child: Text(FinanceDisplayLabels.advisorySeverity(context, code)),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _severityMin = v);
            _loadAlerts();
          },
        ),
        if (_canPickPlant) _buildPlantDropdown(context),
      ],
    );
  }

  Widget _buildPlantDropdown(BuildContext context) {
    return FutureBuilder<List<({String plantKey, String label})>>(
      future: CompanyPlantDisplayName.listSelectablePlants(
        companyId: _companyId,
      ),
      builder: (context, snap) {
        final plants = snap.data ?? [];
        return DropdownButton<String>(
          value: _filterPlantKey,
          hint: Text(FinanceStrings.t(context, 'advisory_filter_plant')),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                FinanceStrings.t(context, 'advisory_filter_all_plants'),
              ),
            ),
            ...plants.map(
              (p) => DropdownMenuItem(
                value: p.plantKey,
                child: Text(p.label),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _filterPlantKey = v ?? '');
            _loadAlerts();
          },
        );
      },
    );
  }
}
