import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../models/finance_ai_alert.dart';
import '../services/finance_ai_advisory_navigation.dart';
import '../services/finance_ai_advisory_service.dart';
import '../widgets/finance_ai_facts_section.dart';
import '../widgets/finance_ai_feedback_sheet.dart';
import '../widgets/finance_ai_severity_chip.dart';

class FinanceAiAlertDetailScreen extends StatefulWidget {
  const FinanceAiAlertDetailScreen({
    super.key,
    required this.companyData,
    required this.alertId,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String alertId;
  final bool debugUnlockModule;

  @override
  State<FinanceAiAlertDetailScreen> createState() =>
      _FinanceAiAlertDetailScreenState();
}

class _FinanceAiAlertDetailScreenState extends State<FinanceAiAlertDetailScreen> {
  final _svc = FinanceAiAdvisoryService();

  FinanceAiAlert? _alert;
  String? _plantLabel;
  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;
  bool _changed = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString().trim();

  bool get _canAck => FinancePermissions.canAcknowledgeFinanceAiAlert(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canDismiss => FinancePermissions.canDismissFinanceAiAlert(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canFeedback => FinancePermissions.canSubmitFinanceAiFeedback(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alert = await _svc.getAlert(
        companyId: _companyId,
        alertId: widget.alertId,
      );
      String? plantLabel;
      final pk = alert.plantKey.trim();
      if (pk.isNotEmpty) {
        plantLabel = await CompanyPlantDisplayName.resolve(
          companyId: _companyId,
          plantKey: pk,
        );
      }
      if (!mounted) return;
      setState(() {
        _alert = alert;
        _plantLabel = plantLabel;
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

  Future<void> _acknowledge() async {
    if (_actionInProgress || _alert == null || !_canAck || !_alert!.isOpen) {
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await _svc.acknowledgeAlert(
        companyId: _companyId,
        alertId: widget.alertId,
      );
      _changed = true;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FinanceStrings.t(context, 'advisory_acknowledged')),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? '$e');
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _dismiss(String reason) async {
    if (_actionInProgress || !_canDismiss) return;
    setState(() => _actionInProgress = true);
    try {
      await _svc.dismissAlert(
        companyId: _companyId,
        alertId: widget.alertId,
        dismissReason: reason,
      );
      _changed = true;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FinanceStrings.t(context, 'advisory_dismissed')),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? '$e');
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _feedback(String kind, String comment) async {
    if (_actionInProgress || !_canFeedback) return;
    setState(() => _actionInProgress = true);
    try {
      await _svc.submitFeedback(
        companyId: _companyId,
        alertId: widget.alertId,
        feedbackKind: kind,
        comment: comment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FinanceStrings.t(context, 'advisory_feedback_sent')),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? '$e');
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _openRecommendation() {
    final alert = _alert;
    if (alert == null) return;
    FinanceAiAdvisoryNavigation.openRecommendation(
      context,
      companyData: widget.companyData,
      recommendation: alert.primaryRecommendation,
      debugUnlockModule: widget.debugUnlockModule,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alert = _alert;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'advisory_detail_title')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : alert == null
                    ? const SizedBox.shrink()
                    : _buildBody(context, theme, alert),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    FinanceAiAlert alert,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale).add_Hm();
    final analysisDate = alert.lastDetectedAt ?? alert.triggeredAt;
    final observedText = [
      if (alert.headline.isNotEmpty) alert.headline,
      if (alert.summary.isNotEmpty) alert.summary,
      if (alert.aiExplanation.causeSummary.trim().isNotEmpty)
        alert.aiExplanation.causeSummary.trim(),
    ].join('\n\n');

    final rec = alert.primaryRecommendation;
    final hasRecommendation =
        rec.actionType.trim().toLowerCase() != 'no_action' &&
            rec.title.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                alert.headline.isNotEmpty
                    ? alert.headline
                    : FinanceDisplayLabels.advisoryRuleId(context, alert.ruleId),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FinanceAiSeverityChip(severity: alert.severity),
          ],
        ),
        const SizedBox(height: 4),
        Chip(
          label: Text(FinanceDisplayLabels.advisoryStatus(context, alert.status)),
        ),
        if ((alert.plantKey).trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            FinanceStrings.t(context, 'advisory_plant_scope').replaceAll(
              '{plant}',
              _plantLabel ?? alert.plantKey,
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        _sectionTitle(context, 'advisory_section_observed'),
        const SizedBox(height: 8),
        Text(observedText, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _sectionTitle(context, 'advisory_section_why'),
        const SizedBox(height: 8),
        FinanceAiFactsSection(facts: alert.factsUsed),
        const SizedBox(height: 16),
        _sectionTitle(context, 'advisory_section_assessment'),
        const SizedBox(height: 8),
        _assessmentRow(
          context,
          FinanceStrings.t(context, 'advisory_filter_severity'),
          FinanceDisplayLabels.advisorySeverity(context, alert.severity),
        ),
        _assessmentRow(
          context,
          FinanceStrings.t(context, 'advisory_confidence_label')
              .replaceAll('{score}', '')
              .replaceAll(': %', '')
              .trim(),
          '${alert.confidenceScore.toStringAsFixed(0)}%',
        ),
        _assessmentRow(
          context,
          FinanceStrings.t(context, 'advisory_confidence_origin'),
          FinanceDisplayLabels.advisoryConfidenceOrigin(
            context,
            alert.confidenceOrigin,
          ),
        ),
        if (alert.confidenceFactors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            FinanceStrings.t(context, 'advisory_confidence_factors'),
            style: theme.textTheme.labelLarge,
          ),
          ...alert.confidenceFactors.entries.map(
            (e) => Text(
              '${FinanceDisplayLabels.advisoryConfidenceFactorKey(context, e.key)}: ${e.value}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        if (analysisDate != null)
          _assessmentRow(
            context,
            FinanceStrings.t(context, 'advisory_analysis_date'),
            df.format(analysisDate.toLocal()),
          ),
        if (alert.contractVersion.isNotEmpty)
          _assessmentRow(
            context,
            FinanceStrings.t(context, 'advisory_evaluator_version'),
            alert.contractVersion,
          ),
        if (alert.resolutionReason != null &&
            alert.resolutionReason!.trim().isNotEmpty)
          _assessmentRow(
            context,
            FinanceStrings.t(context, 'advisory_resolution_reason'),
            alert.resolutionReason!,
          ),
        if (alert.dismissReason != null && alert.dismissReason!.trim().isNotEmpty)
          _assessmentRow(
            context,
            FinanceStrings.t(context, 'advisory_dismiss_reason_label'),
            alert.dismissReason!,
          ),
        const SizedBox(height: 16),
        _sectionTitle(context, 'advisory_section_recommendation'),
        const SizedBox(height: 8),
        if (hasRecommendation) ...[
          Text(rec.title, style: theme.textTheme.bodyMedium),
          if (rec.detail.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(rec.detail, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _actionInProgress ? null : _openRecommendation,
            icon: const Icon(Icons.open_in_new),
            label: Text(FinanceStrings.t(context, 'advisory_open_recommendation')),
          ),
        ] else
          Text(
            FinanceStrings.t(context, 'advisory_facts_empty'),
            style: theme.textTheme.bodyMedium,
          ),
        const SizedBox(height: 24),
        if (_canAck && alert.isOpen)
          FilledButton.tonal(
            onPressed: _actionInProgress ? null : _acknowledge,
            child: Text(FinanceStrings.t(context, 'advisory_acknowledge')),
          ),
        if (_canDismiss && alert.isActive) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _actionInProgress
                ? null
                : () => FinanceAiDismissSheet.show(
                      context,
                      onSubmit: _dismiss,
                    ),
            child: Text(FinanceStrings.t(context, 'advisory_dismiss')),
          ),
        ],
        if (_canFeedback) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _actionInProgress
                ? null
                : () => FinanceAiFeedbackSheet.show(
                      context,
                      onSubmit: _feedback,
                    ),
            child: Text(FinanceStrings.t(context, 'advisory_feedback')),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String key) {
    return Text(
      FinanceStrings.t(context, key),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _assessmentRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
