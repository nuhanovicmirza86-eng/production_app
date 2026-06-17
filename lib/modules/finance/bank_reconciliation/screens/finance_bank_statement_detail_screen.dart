import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_host.dart';
import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_reason_prompt_dialog.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_match_confirmation.dart';
import '../models/finance_bank_match_suggestion.dart';
import '../models/finance_bank_statement_transaction.dart';
import '../services/finance_bank_reconciliation_service.dart';
import '../utils/finance_bank_match_suggestion_ui_helper.dart';
import '../widgets/finance_bank_match_suggestion_card.dart';
import '../widgets/finance_bank_match_suggestion_detail_sheet.dart';
import '../widgets/finance_bank_audit_trail_section.dart';
import '../models/finance_bank_audit_trail_entry.dart';
import 'finance_bank_match_confirm_screen.dart';
import 'finance_bank_match_confirmation_detail_screen.dart';

class FinanceBankStatementDetailScreen extends StatefulWidget {
  const FinanceBankStatementDetailScreen({
    super.key,
    required this.companyData,
    required this.transactionId,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String transactionId;
  final bool debugUnlockModule;

  @override
  State<FinanceBankStatementDetailScreen> createState() =>
      _FinanceBankStatementDetailScreenState();
}

class _FinanceBankStatementDetailScreenState
    extends State<FinanceBankStatementDetailScreen> {
  final _service = FinanceBankReconciliationService();

  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;
  String? _suggestionsWarning;
  String? _confirmationsWarning;
  String? _auditTrailWarning;

  FinanceBankStatementTransaction? _txn;
  List<FinanceBankMatchSuggestion> _activeSuggestions = const [];
  List<FinanceBankMatchSuggestion> _dismissedSuggestions = const [];
  List<FinanceBankMatchConfirmation> _confirmations = const [];
  List<FinanceBankAuditTrailEntry> _auditTrail = const [];
  bool _showWeakSuggestions = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canManage => FinancePermissions.canManageBankStatementLines(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  bool get _canConfirm => FinancePermissions.canConfirmBankMatch(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  String? get _invoiceTypeFilter {
    final txn = _txn;
    if (txn == null) return null;
    if (txn.isInflow) return 'sales';
    if (txn.isOutflow) return 'purchase';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _suggestionsWarning = null;
      _confirmationsWarning = null;
      _auditTrailWarning = null;
    });
    try {
      final txn = await _service.getBankTransaction(
        companyId: _companyId,
        transactionId: widget.transactionId,
      );
      if (!mounted) return;

      var active = const <FinanceBankMatchSuggestion>[];
      var dismissed = const <FinanceBankMatchSuggestion>[];
      var confirmations = const <FinanceBankMatchConfirmation>[];
      var auditTrail = const <FinanceBankAuditTrailEntry>[];
      String? suggestionsWarning;
      String? confirmationsWarning;
      String? auditTrailWarning;

      final invoiceType = txn.isInflow
          ? 'sales'
          : txn.isOutflow
          ? 'purchase'
          : null;

      try {
        active = await _service.listMatchSuggestions(
          companyId: _companyId,
          bankStatementTransactionId: widget.transactionId,
          status: 'active',
          invoiceType: invoiceType,
        );
        dismissed = await _service.listMatchSuggestions(
          companyId: _companyId,
          bankStatementTransactionId: widget.transactionId,
          status: 'dismissed',
          invoiceType: invoiceType,
        );
      } catch (e) {
        suggestionsWarning = FinanceErrorMapper.toMessage(e, context: context);
      }

      try {
        confirmations = await _service.listMatchConfirmationHistory(
          companyId: _companyId,
          bankStatementTransactionId: widget.transactionId,
        );
      } catch (e) {
        confirmationsWarning = FinanceErrorMapper.toMessage(e, context: context);
      }

      try {
        auditTrail = await _service.listBankStatementAuditTrail(
          companyId: _companyId,
          bankStatementTransactionId: widget.transactionId,
        );
      } catch (e) {
        auditTrailWarning = FinanceErrorMapper.toMessage(e, context: context);
      }

      if (!mounted) return;
      setState(() {
        _txn = txn;
        _activeSuggestions = active;
        _dismissedSuggestions = dismissed;
        _confirmations = confirmations;
        _auditTrail = auditTrail;
        _suggestionsWarning = suggestionsWarning;
        _confirmationsWarning = confirmationsWarning;
        _auditTrailWarning = auditTrailWarning;
        _showWeakSuggestions = false;
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

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  Future<void> _generateSuggestions() async {
    final txn = _txn;
    if (txn != null && !txn.canGenerateSuggestions) {
      _showInfo(FinanceStrings.t(context, 'bank_match_generate_skipped_reconciled'));
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final result = await _service.generateMatchSuggestions(
        companyId: _companyId,
        bankStatementTransactionId: widget.transactionId,
      );
      await _load();
      if (!mounted) return;
      _showGenerateResult(result, txnBefore: txn);
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showGenerateResult(
    Map<String, dynamic> result, {
    FinanceBankStatementTransaction? txnBefore,
  }) {
    final created = _intFromResult(result, 'createdCount');
    final updated = _intFromResult(result, 'updatedCount');
    final skipped = _intFromResult(result, 'skippedBankCount');
    final total = created + updated;

    if (total > 0) {
      _showInfo(
        FinanceStrings.t(context, 'bank_match_generate_success')
            .replaceAll('{count}', '$total'),
      );
      return;
    }
    if (skipped > 0 ||
        (txnBefore != null && txnBefore.isPostedLike) ||
        (_txn?.isPostedLike ?? false)) {
      _showInfo(FinanceStrings.t(context, 'bank_match_generate_skipped_reconciled'));
      return;
    }
    _showInfo(FinanceStrings.t(context, 'bank_match_generate_none'));
  }

  int _intFromResult(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _ignoreTxn() async {
    final reason = await showFinanceReasonPromptDialog(
      context: context,
      title: FinanceStrings.t(context, 'bank_ignore'),
      hint: FinanceStrings.t(context, 'bank_ignore_reason'),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _actionInProgress = true);
    try {
      await _service.ignoreBankTransaction(
        companyId: _companyId,
        transactionId: widget.transactionId,
        reason: reason,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _restoreTxn() async {
    setState(() => _actionInProgress = true);
    try {
      await _service.restoreBankTransaction(
        companyId: _companyId,
        transactionId: widget.transactionId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _dismissSuggestion(FinanceBankMatchSuggestion sug) async {
    final reason = await showFinanceReasonPromptDialog(
      context: context,
      title: FinanceStrings.t(context, 'bank_match_dismiss'),
      hint: FinanceStrings.t(context, 'bank_match_dismiss_reason'),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _actionInProgress = true);
    try {
      await _service.dismissMatchSuggestion(
        companyId: _companyId,
        suggestionId: sug.id,
        reason: reason,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _restoreSuggestion(FinanceBankMatchSuggestion sug) async {
    setState(() => _actionInProgress = true);
    try {
      await _service.restoreMatchSuggestion(
        companyId: _companyId,
        suggestionId: sug.id,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _openConfirm({FinanceBankMatchSuggestion? suggestion}) async {
    final txn = _txn;
    if (txn == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinanceBankMatchConfirmScreen(
          companyData: widget.companyData,
          debugUnlockModule: widget.debugUnlockModule,
          bankTransaction: txn,
          initialSuggestion: suggestion,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  void _openConfirmation(FinanceBankMatchConfirmation conf) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinanceBankMatchConfirmationDetailScreen(
          companyData: widget.companyData,
          debugUnlockModule: widget.debugUnlockModule,
          confirmationId: conf.id,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  void _showError(Object e) {
    var msg = FinanceErrorMapper.toMessage(e, context: context);
    if (FinanceErrorMapper.isConcurrencyAborted(e)) {
      msg = FinanceErrorMapper.concurrencyHint(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openSuggestionDetail(
    FinanceBankMatchSuggestion sug, {
    required bool dismissed,
  }) {
    final txn = _txn;
    if (txn == null) return;
    showFinanceBankMatchSuggestionDetailSheet(
      context: context,
      bankTransaction: txn,
      suggestion: sug,
      canManage: _canManage,
      canConfirm: _canConfirm,
      dismissed: dismissed,
      onDismiss: () => _dismissSuggestion(sug),
      onRestore: () => _restoreSuggestion(sug),
      onContinueConfirm: () => _openConfirm(suggestion: sug),
    );
  }

  Widget _buildActiveSuggestionsSection(FinanceBankStatementTransaction txn) {
    final partition = FinanceBankMatchSuggestionUiHelper.partitionActive(
      _activeSuggestions,
    );
    final hasAny =
        partition.primary.isNotEmpty ||
        partition.weak.isNotEmpty ||
        partition.hiddenUsefulCount > 0;

    if (!hasAny) {
      return Text(
        txn.isPostedLike
            ? FinanceStrings.t(context, 'bank_match_suggestions_empty_reconciled')
            : FinanceStrings.t(context, 'bank_match_suggestions_empty'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FinanceStrings.t(context, 'bank_match_intro_primary'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ...partition.primary.map(
          (s) => FinanceBankMatchSuggestionCard(
            suggestion: s,
            onTap: () => _openSuggestionDetail(s, dismissed: false),
          ),
        ),
        if (partition.hiddenUsefulCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            FinanceStrings.t(context, 'bank_match_hidden_useful_hint')
                .replaceAll('{count}', '${partition.hiddenUsefulCount}'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (partition.weak.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _showWeakSuggestions = !_showWeakSuggestions);
              },
              icon: Icon(
                _showWeakSuggestions
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              label: Text(
                _showWeakSuggestions
                    ? FinanceStrings.t(context, 'bank_match_hide_weak')
                    : FinanceStrings.t(context, 'bank_match_show_weak')
                        .replaceAll('{count}', '${partition.weak.length}'),
              ),
            ),
          ),
          if (_showWeakSuggestions)
            ...partition.weak.map(
              (s) => FinanceBankMatchSuggestionCard(
                suggestion: s,
                onTap: () => _openSuggestionDetail(s, dismissed: false),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDismissedSuggestionsSection() {
    if (_dismissedSuggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          FinanceStrings.t(context, 'bank_match_dismissed_section'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ..._dismissedSuggestions.map(
          (s) => FinanceBankMatchSuggestionCard(
            suggestion: s,
            dismissed: true,
            onTap: () => _openSuggestionDetail(s, dismissed: true),
          ),
        ),
      ],
    );
  }

  List<String> _assistantActions(FinanceBankStatementTransaction txn) {
    final actions = <String>[];
    if (_canManage && txn.canGenerateSuggestions) {
      actions.add(FinanceStrings.t(context, 'bank_match_generate'));
    }
    if (_canConfirm) {
      actions.add(FinanceStrings.t(context, 'bank_match_confirm'));
    }
    if (_canManage && txn.canIgnore) {
      actions.add(FinanceStrings.t(context, 'bank_ignore'));
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final txn = _txn;

    return FinanceAssistantHost(
      contextData: FinanceAssistantContext(
        screenKey: FinanceAssistantScreens.bankStatementDetail,
        role: _role,
        entityStatus: txn == null
            ? null
            : FinanceDisplayLabels.bankStatementStatus(context, txn.status),
        availableActions: txn == null ? const [] : _assistantActions(txn),
      ),
      child: Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'bank_detail_title')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(FinanceStrings.t(context, 'retry')),
                    ),
                  ],
                ),
              ),
            )
          : txn == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FinanceMoneyFormat.format(
                            txn.amount,
                            txn.currency,
                          ),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        _detailRow(
                          FinanceStrings.t(context, 'filter_status'),
                          FinanceDisplayLabels.bankStatementStatus(
                            context,
                            txn.status,
                          ),
                        ),
                        _detailRow(
                          FinanceStrings.t(context, 'filter_direction'),
                          FinanceDisplayLabels.transactionDirection(
                            context,
                            txn.direction,
                          ),
                        ),
                        _detailRow(
                          FinanceStrings.t(context, 'bank_booking_date'),
                          _formatDate(txn.bookingDate),
                        ),
                        _detailRow(
                          FinanceStrings.t(context, 'bank_value_date'),
                          _formatDate(txn.valueDate),
                        ),
                        _detailRow(
                          FinanceStrings.t(context, 'bank_counterparty'),
                          txn.counterpartyName ?? '—',
                        ),
                        _detailRow(
                          FinanceStrings.t(context, 'bank_reference'),
                          txn.paymentReference ?? '—',
                        ),
                        _detailRow(
                          FinanceStrings.t(context, 'bank_description'),
                          txn.rawDescription ?? '—',
                        ),
                        if (txn.ignoreReason != null)
                          _detailRow(
                            FinanceStrings.t(context, 'bank_ignore_reason'),
                            txn.ignoreReason!,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_canManage) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_canManage && txn.canIgnore)
                        OutlinedButton.icon(
                          onPressed: _actionInProgress ? null : _ignoreTxn,
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(FinanceStrings.t(context, 'bank_ignore')),
                        ),
                      if (_canManage && txn.isIgnored)
                        OutlinedButton.icon(
                          onPressed: _actionInProgress ? null : _restoreTxn,
                          icon: const Icon(Icons.restore_outlined),
                          label: Text(FinanceStrings.t(context, 'bank_restore')),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                FinanceHelpSectionTitle(
                  title: FinanceStrings.t(context, 'bank_match_suggestions_title'),
                  helpTitleKey: 'help_bank_suggestions_title',
                  helpBodyKey: 'help_bank_suggestions_body',
                ),
                if (_suggestionsWarning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _suggestionsWarning!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                Row(
                  children: [
                    const Spacer(),
                    if (_canManage && (txn.canGenerateSuggestions))
                      TextButton.icon(
                        onPressed: _actionInProgress
                            ? null
                            : _generateSuggestions,
                        icon: const Icon(Icons.auto_fix_high_outlined),
                        label: Text(
                          FinanceStrings.t(context, 'bank_match_generate'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildActiveSuggestionsSection(txn),
                _buildDismissedSuggestionsSection(),
                const SizedBox(height: 20),
                FinanceHelpSectionTitle(
                  title: FinanceStrings.t(context, 'bank_match_confirmations_title'),
                  helpTitleKey: 'help_bank_confirmation_title',
                  helpBodyKey: 'help_bank_confirmation_body',
                ),
                if (_confirmationsWarning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _confirmationsWarning!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_confirmations.isEmpty)
                  Text(FinanceStrings.t(context, 'bank_match_confirmations_empty'))
                else
                  ..._confirmations.map(
                    (c) => Card(
                      child: ListTile(
                        onTap: () => _openConfirmation(c),
                        title: Text(
                          c.displayTitle ??
                              FinanceStrings.t(
                                context,
                                'bank_match_confirmation_unlabeled',
                              ),
                        ),
                        subtitle: Text(
                          '${FinanceDisplayLabels.bankMatchConfirmationStatus(context, c)} · '
                          '${FinanceMoneyFormat.format(c.totalAllocatedAmount, c.currency)} / '
                          '${FinanceMoneyFormat.format(c.totalBankAmount, c.currency)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FinanceBankAuditTrailSection(
                  entries: _auditTrail,
                  warning: _auditTrailWarning,
                  loading: _loading,
                  onRefresh: _load,
                ),
              ],
            ),
    ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
