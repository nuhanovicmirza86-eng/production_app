import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../models/finance_ai_alert.dart';
import '../models/finance_ai_interaction_types.dart';
import '../models/finance_ai_outcome.dart';
import '../services/finance_ai_advisory_navigation.dart';
import '../services/finance_ai_advisory_service.dart';
import '../services/finance_ai_outcome_service.dart';
import '../widgets/finance_ai_facts_section.dart';
import '../widgets/finance_ai_feedback_sheet.dart';
import '../widgets/finance_ai_outcome_section.dart';
import '../widgets/finance_ai_recommendation_decision_section.dart';
import '../widgets/finance_ai_severity_chip.dart';

class FinanceAiAlertDetailScreen extends StatefulWidget {
  const FinanceAiAlertDetailScreen({
    super.key,
    required this.companyData,
    required this.alertId,
    this.initialAlert,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String alertId;
  final FinanceAiAlert? initialAlert;
  final bool debugUnlockModule;

  @override
  State<FinanceAiAlertDetailScreen> createState() =>
      _FinanceAiAlertDetailScreenState();
}

class _FinanceAiAlertDetailScreenState extends State<FinanceAiAlertDetailScreen> {
  final _svc = FinanceAiAdvisoryService();
  final _outcomeSvc = FinanceAiOutcomeService();

  FinanceAiAlert? _alert;
  FinanceAiOutcomeDetail _outcomeDetail = const FinanceAiOutcomeDetail();
  String? _plantLabel;
  bool _loading = true;
  bool _outcomeLoading = false;
  bool _actionInProgress = false;
  String? _error;
  String? _outcomeError;
  String? _telemetryError;
  bool _changed = false;
  bool _shownSent = false;
  bool _viewedSent = false;
  String? _pendingTelemetryRetry;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString().trim();

  String? get _recommendationId {
    final id = _alert?.primaryRecommendationId.trim() ?? '';
    return id.isEmpty ? null : id;
  }

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

  bool get _canInteract => FinancePermissions.canRecordFinanceAiInteraction(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    _alert = widget.initialAlert;
    _loading = widget.initialAlert == null;
    _load();
  }

  Future<void> _load() async {
    if (_alert == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
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
        _error = null;
      });
      await _recordViewedIfNeeded();
      await _loadOutcome();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = _friendlyLoadError(context, e);
      setState(() {
        _loading = false;
        _error = _alert == null ? message : null;
      });
      if (_alert != null) {
        _showError(message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _alert == null ? FinanceStrings.t(context, 'advisory_load_error') : null;
      });
      if (_alert != null) {
        _showError(FinanceStrings.t(context, 'advisory_load_error'));
      }
    }
  }

  Future<void> _loadOutcome() async {
    final recommendationId = _recommendationId;
    if (!_canInteract || recommendationId == null) return;
    setState(() {
      _outcomeLoading = true;
      _outcomeError = null;
    });
    try {
      final detail = await _outcomeSvc.getOutcome(
        companyId: _companyId,
        recommendationId: recommendationId,
      );
      if (!mounted) return;
      setState(() {
        _outcomeDetail = detail;
        _outcomeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outcomeLoading = false;
        _outcomeError = FinanceStrings.t(context, 'advisory_outcome_load_error');
      });
    }
  }

  Future<void> _recordInteraction({
    required String interactionType,
    required String requestId,
    Map<String, dynamic>? metadata,
    String? targetEntityType,
    String? targetEntityId,
    String? actionAuditId,
  }) async {
    final recommendationId = _recommendationId;
    if (!_canInteract || recommendationId == null) return;
    try {
      await _outcomeSvc.recordInteraction(
        companyId: _companyId,
        recommendationId: recommendationId,
        interactionType: interactionType,
        requestId: requestId,
        clientSurface: 'alert_detail',
        metadata: metadata,
        targetEntityType: targetEntityType,
        targetEntityId: targetEntityId,
        actionAuditId: actionAuditId,
      );
      if (!mounted) return;
      setState(() => _telemetryError = null);
      await _loadOutcome();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _telemetryError = e.message ?? FinanceStrings.t(context, 'advisory_telemetry_error');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _telemetryError = FinanceStrings.t(context, 'advisory_telemetry_error');
      });
    }
  }

  Future<void> _recordViewedIfNeeded() async {
    if (_viewedSent || !_canInteract || _recommendationId == null) return;
    _viewedSent = true;
    _pendingTelemetryRetry = 'viewed';
    await _recordInteraction(
      interactionType: FinanceAiInteractionTypes.viewed,
      requestId: FinanceAiInteractionRequestIds.viewed(
        widget.alertId,
        _recommendationId!,
      ),
    );
  }

  Future<void> _recordShownIfNeeded() async {
    if (_shownSent || !_canInteract || _recommendationId == null) return;
    _shownSent = true;
    await _recordInteraction(
      interactionType: FinanceAiInteractionTypes.shown,
      requestId: FinanceAiInteractionRequestIds.shown(
        widget.alertId,
        _recommendationId!,
      ),
    );
  }

  Future<void> _acceptRecommendation() async {
    if (_actionInProgress || _recommendationId == null) return;
    setState(() => _actionInProgress = true);
    try {
      await _recordInteraction(
        interactionType: FinanceAiInteractionTypes.accepted,
        requestId: FinanceAiInteractionRequestIds.accepted(
          widget.alertId,
          _recommendationId!,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _rejectRecommendation(String reasonCode, String? otherText) async {
    if (_actionInProgress || _recommendationId == null) return;
    setState(() => _actionInProgress = true);
    try {
      await _recordInteraction(
        interactionType: FinanceAiInteractionTypes.rejected,
        requestId: FinanceAiInteractionRequestIds.rejected(
          widget.alertId,
          _recommendationId!,
          reasonCode,
        ),
        metadata: {
          'filterPreset': reasonCode,
          if (otherText != null && otherText.trim().isNotEmpty)
            'navigationTarget': otherText.trim(),
        },
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _retryPendingTelemetry() async {
    final pending = _pendingTelemetryRetry;
    if (pending == null) return;
    if (pending == 'shown') {
      _shownSent = false;
      await _recordShownIfNeeded();
    } else if (pending == 'viewed') {
      _viewedSent = false;
      await _recordViewedIfNeeded();
    }
  }

  String _friendlyLoadError(BuildContext context, FirebaseFunctionsException e) {
    if (e.code == 'not-found') {
      return FinanceStrings.t(context, 'advisory_alert_not_found');
    }
    final msg = e.message?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    return FinanceStrings.t(context, 'advisory_load_error');
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

  Future<void> _openRecommendation() async {
    final alert = _alert;
    final recommendationId = _recommendationId;
    if (alert == null || recommendationId == null) return;
    await FinanceAiAdvisoryNavigation.openRecommendation(
      context,
      companyData: widget.companyData,
      recommendation: alert.primaryRecommendation,
      alertId: widget.alertId,
      recommendationId: recommendationId,
      companyId: _companyId,
      outcomeService: _outcomeSvc,
      debugUnlockModule: widget.debugUnlockModule,
      onTelemetryError: (msg) {
        if (!mounted) return;
        setState(() => _telemetryError = msg);
      },
    );
    await _loadOutcome();
  }

  @override
  Widget build(BuildContext context) {
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
        body: _loading && _alert == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _alert == null
                ? _buildErrorState(context)
                : alert == null
                    ? const SizedBox.shrink()
                    : _buildBody(context, Theme.of(context), alert),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? FinanceStrings.t(context, 'advisory_load_error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_changed),
              child: Text(FinanceStrings.t(context, 'cancel')),
            ),
          ],
        ),
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
      if (alert.summary.isNotEmpty && alert.summary.trim() != alert.headline.trim())
        alert.summary,
      if (alert.aiExplanation.causeSummary.trim().isNotEmpty &&
          alert.aiExplanation.causeSummary.trim() != alert.headline.trim() &&
          alert.aiExplanation.causeSummary.trim() != alert.summary.trim())
        alert.aiExplanation.causeSummary.trim(),
    ].join('\n\n');

    final rec = alert.primaryRecommendation;
    final hasRecommendation =
        rec.actionType.trim().toLowerCase() != 'no_action' &&
            rec.title.trim().isNotEmpty &&
            _recommendationId != null;

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
          FinanceStrings.t(context, 'advisory_confidence_score'),
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
              '${FinanceDisplayLabels.advisoryConfidenceFactorKey(context, e.key)}: '
              '${FinanceDisplayLabels.advisoryConfidenceFactorValue(context, e.key, e.value)}',
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
        if (hasRecommendation)
          FinanceAiRecommendationVisibilityReporter(
            enabled: true,
            onVisible: () {
              _pendingTelemetryRetry = 'shown';
              _recordShownIfNeeded();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(rec.title, style: theme.textTheme.bodyMedium),
                if (rec.detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(rec.detail, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _actionInProgress ? null : _openRecommendation,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    FinanceStrings.t(context, 'advisory_open_recommendation'),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            FinanceStrings.t(context, 'advisory_facts_empty'),
            style: theme.textTheme.bodyMedium,
          ),
        if (hasRecommendation) ...[
          const SizedBox(height: 16),
          FinanceAiRecommendationDecisionSection(
            canInteract: _canInteract,
            actionInProgress: _actionInProgress,
            interactionSummary: _outcomeDetail.interactionSummary,
            onAccept: _acceptRecommendation,
            onReject: _rejectRecommendation,
            telemetryError: _telemetryError,
            onRetryTelemetry: _telemetryError != null ? _retryPendingTelemetry : null,
          ),
        ],
        if (_canInteract && _recommendationId != null) ...[
          const SizedBox(height: 24),
          FinanceAiOutcomeSection(
            detail: _outcomeDetail,
            loading: _outcomeLoading,
            error: _outcomeError,
            onRetry: _loadOutcome,
          ),
        ],
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
