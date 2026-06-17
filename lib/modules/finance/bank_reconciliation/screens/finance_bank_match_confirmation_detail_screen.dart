import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_assistant/finance_assistant_host.dart';
import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_reason_prompt_dialog.dart';
import '../../shared/finance_label_with_term_help.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_match_confirmation.dart';
import '../services/finance_bank_reconciliation_service.dart';

class FinanceBankMatchConfirmationDetailScreen extends StatefulWidget {
  const FinanceBankMatchConfirmationDetailScreen({
    super.key,
    required this.companyData,
    required this.confirmationId,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String confirmationId;
  final bool debugUnlockModule;

  @override
  State<FinanceBankMatchConfirmationDetailScreen> createState() =>
      _FinanceBankMatchConfirmationDetailScreenState();
}

class _FinanceBankMatchConfirmationDetailScreenState
    extends State<FinanceBankMatchConfirmationDetailScreen> {
  final _service = FinanceBankReconciliationService();
  final _cancelRequestId = const Uuid().v4();

  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  FinanceBankMatchConfirmation? _confirmation;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canCancel => FinancePermissions.canConfirmBankMatch(
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
      final conf = await _service.getMatchConfirmation(
        companyId: _companyId,
        confirmationId: widget.confirmationId,
      );
      if (!mounted) return;
      setState(() {
        _confirmation = conf;
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

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).add_Hm().format(d);
  }

  Future<void> _cancelConfirmation() async {
    final conf = _confirmation;
    if (conf == null || !conf.isActive) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(context, 'bank_match_cancel_confirm_title')),
        content: Text(FinanceStrings.t(context, 'bank_match_cancel_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(context, 'bank_match_cancel')),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final reason = await showFinanceReasonPromptDialog(
      context: context,
      title: FinanceStrings.t(context, 'bank_match_cancel'),
      hint: FinanceStrings.t(context, 'bank_match_cancel_reason'),
      confirmLabel: FinanceStrings.t(context, 'bank_match_cancel'),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _cancelling = true);
    try {
      await _service.cancelMatchConfirmation(
        companyId: _companyId,
        confirmationId: conf.id,
        requestId: _cancelRequestId,
        cancelReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'bank_match_cancelled'))),
      );
      await _load();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      var msg = FinanceErrorMapper.toMessage(e, context: context);
      if (FinanceErrorMapper.isConcurrencyAborted(e)) {
        msg = FinanceErrorMapper.concurrencyHint(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conf = _confirmation;

    return FinanceAssistantHost(
      contextData: FinanceAssistantContext(
        screenKey: FinanceAssistantScreens.bankMatchConfirmationDetail,
        role: _role,
        entityStatus: conf == null
            ? null
            : FinanceDisplayLabels.bankMatchConfirmationStatus(context, conf),
      ),
      child: Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'bank_match_confirmation_detail')),
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
          ? Center(child: Text(_error!))
          : conf == null
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
                          conf.displayTitle ??
                              FinanceStrings.t(
                                context,
                                'bank_match_confirmation_unlabeled',
                              ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        FinanceLabelWithTermHelp(
                          label: FinanceStrings.t(context, 'filter_status'),
                          value: FinanceDisplayLabels.bankMatchConfirmationStatus(
                            context,
                            conf,
                          ),
                          labelWidth: 160,
                          helpTitleKey: conf.reconciliationStatus
                                      .toLowerCase() ==
                                  'partially_reconciled'
                              ? 'help_term_partially_reconciled_title'
                              : null,
                          helpBodyKey: conf.reconciliationStatus
                                      .toLowerCase() ==
                                  'partially_reconciled'
                              ? 'help_term_partially_reconciled_body'
                              : null,
                        ),
                        _row(
                          FinanceStrings.t(context, 'bank_match_confirmed_by'),
                          conf.confirmedByEmail ?? conf.confirmedBy ?? '—',
                        ),
                        _row(
                          FinanceStrings.t(context, 'bank_match_confirmed_at'),
                          _formatDateTime(conf.confirmedAt),
                        ),
                        _row(
                          FinanceStrings.t(context, 'filter_direction'),
                          FinanceDisplayLabels.transactionDirection(
                            context,
                            conf.direction,
                          ),
                        ),
                        _row(
                          FinanceStrings.t(context, 'bank_match_bank_amount'),
                          FinanceMoneyFormat.format(
                            conf.totalBankAmount,
                            conf.currency,
                          ),
                        ),
                        _row(
                          FinanceStrings.t(context, 'bank_match_allocated'),
                          FinanceMoneyFormat.format(
                            conf.totalAllocatedAmount,
                            conf.currency,
                          ),
                        ),
                        FinanceLabelWithTermHelp(
                          label: FinanceStrings.t(context, 'bank_match_unallocated'),
                          value: FinanceMoneyFormat.format(
                            conf.unallocatedAmount,
                            conf.currency,
                          ),
                          labelWidth: 160,
                          helpTitleKey: 'help_term_unallocated_title',
                          helpBodyKey: 'help_term_unallocated_body',
                        ),
                        if (conf.confirmReason != null)
                          _row(
                            FinanceStrings.t(context, 'bank_match_note'),
                            conf.confirmReason!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (conf.cashTransactionLabel != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      FinanceStrings.t(context, 'bank_match_cash_transaction'),
                    ),
                    subtitle: Text(conf.cashTransactionLabel!),
                  ),
                if (conf.reversalTransactionLabel != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      FinanceStrings.t(context, 'bank_match_reversal_txn'),
                    ),
                    subtitle: Text(conf.reversalTransactionLabel!),
                  ),
                const SizedBox(height: 12),
                Text(
                  FinanceStrings.t(context, 'bank_match_allocations'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...conf.allocationLines.map(
                  (line) => Card(
                    child: ListTile(
                      title: Text(
                        line.invoiceNumber.isNotEmpty
                            ? line.invoiceNumber
                            : FinanceStrings.t(context, 'invoice_number'),
                      ),
                      subtitle: line.allocationCode != null &&
                              line.allocationCode!.isNotEmpty
                          ? Text(line.allocationCode!)
                          : null,
                      trailing: Text(
                        FinanceMoneyFormat.format(
                          line.allocatedAmount,
                          line.currency,
                        ),
                      ),
                    ),
                  ),
                ),
                if (conf.isCancelled) ...[
                  const SizedBox(height: 16),
                  Text(
                    FinanceStrings.t(context, 'bank_match_cancel_result_title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row(
                            FinanceStrings.t(context, 'bank_match_cancel_reason'),
                            conf.cancelReason ?? '—',
                          ),
                          _row(
                            FinanceStrings.t(context, 'bank_match_cancelled_at'),
                            _formatDateTime(conf.cancelledAt),
                          ),
                          _row(
                            FinanceStrings.t(context, 'bank_match_cancelled_by'),
                            conf.cancelledByEmail ?? conf.cancelledBy ?? '—',
                          ),
                          if (conf.reversalTransactionLabel != null)
                            _row(
                              FinanceStrings.t(context, 'bank_match_reversal_txn'),
                              conf.reversalTransactionLabel!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_canCancel && conf.isActive) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancelConfirmation,
                    icon: _cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo_outlined),
                    label: Text(FinanceStrings.t(context, 'bank_match_cancel')),
                  ),
                ],
              ],
            ),
    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
