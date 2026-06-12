import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../accounts/models/finance_account.dart';
import '../../accounts/services/finance_accounts_service.dart';
import '../../cash_flow_categories/models/finance_cash_flow_category.dart';
import '../../cash_flow_categories/services/finance_cash_flow_categories_service.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_transaction.dart';
import '../services/finance_cash_transactions_service.dart';
import 'finance_cash_transaction_form_screen.dart';

class FinanceCashTransactionDetailScreen extends StatefulWidget {
  const FinanceCashTransactionDetailScreen({
    super.key,
    required this.companyData,
    required this.transaction,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceCashTransaction transaction;
  final bool debugUnlockModule;

  @override
  State<FinanceCashTransactionDetailScreen> createState() =>
      _FinanceCashTransactionDetailScreenState();
}

class _FinanceCashTransactionDetailScreenState
    extends State<FinanceCashTransactionDetailScreen> {
  final _txService = FinanceCashTransactionsService();
  final _accountsService = FinanceAccountsService();
  final _categoriesService = FinanceCashFlowCategoriesService();

  late FinanceCashTransaction _tx;
  bool _actionInProgress = false;
  FinanceAccount? _account;
  FinanceCashFlowCategory? _category;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canEdit => _tx.isDraft &&
      FinancePermissions.canEditCashTransactionDraft(
        companyData: widget.companyData,
        role: _role,
        transactionCreatedBy: _tx.createdBy ?? '',
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canPost => _tx.isDraft &&
      FinancePermissions.canPostCashTransaction(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canReconcile => _tx.isPosted &&
      !_tx.hasReversal &&
      FinancePermissions.canReconcileCashTransaction(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canReverse => _tx.isPostedLike &&
      !_tx.hasReversal &&
      !_tx.isReversal &&
      FinancePermissions.canReverseCashTransaction(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canCancelDraft => _tx.isDraft &&
      FinancePermissions.canCancelCashTransactionDraft(
        companyData: widget.companyData,
        role: _role,
        transactionCreatedBy: _tx.createdBy ?? '',
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final accounts = await _accountsService.listAccounts(
        companyId: _companyId,
      );
      final categories = await _categoriesService.listCategories(
        companyId: _companyId,
      );
      if (!mounted) return;
      FinanceAccount? account;
      FinanceCashFlowCategory? category;
      for (final a in accounts) {
        if (a.id == _tx.accountId) {
          account = a;
          break;
        }
      }
      for (final c in categories) {
        if (c.id == _tx.cashFlowCategoryId) {
          category = c;
          break;
        }
      }
      setState(() {
        _account = account;
        _category = category;
      });
    } catch (_) {
      // Prikaz detalja ne ovisi o master podacima.
    }
  }

  Future<bool> _confirm(String titleKey, String bodyKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, titleKey)),
        content: Text(FinanceStrings.t(ctx, bodyKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(ctx, titleKey)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successKey,
  }) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, successKey))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _post() async {
    if (!await _confirm('post_transaction', 'post_transaction_confirm')) return;
    await _runAction(
      () => _txService.postTransaction(
        companyId: _companyId,
        transactionId: _tx.id,
      ),
      successKey: 'posted',
    );
  }

  Future<void> _reconcile() async {
    if (!await _confirm('reconcile_transaction', 'reconcile_transaction_confirm')) {
      return;
    }
    await _runAction(
      () => _txService.reconcileTransaction(
        companyId: _companyId,
        transactionId: _tx.id,
      ),
      successKey: 'reconciled',
    );
  }

  Future<void> _reverse() async {
    if (!await _confirm('reverse_transaction', 'reverse_transaction_confirm')) {
      return;
    }
    await _runAction(
      () => _txService.cancelTransaction(
        companyId: _companyId,
        transactionId: _tx.id,
      ),
      successKey: 'reversed',
    );
  }

  Future<void> _cancelDraft() async {
    if (!await _confirm('cancel_draft', 'cancel_draft_confirm')) return;
    await _runAction(
      () => _txService.cancelTransaction(
        companyId: _companyId,
        transactionId: _tx.id,
      ),
      successKey: 'draft_cancelled',
    );
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceCashTransactionFormScreen(
          companyData: widget.companyData,
          transaction: _tx,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _openLinked(String? linkedId) async {
    if (linkedId == null || linkedId.isEmpty) return;
    try {
      final linked = await _txService.findTransactionById(
        companyId: _companyId,
        transactionId: linkedId,
      );
      if (!mounted || linked == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FinanceCashTransactionDetailScreen(
            companyData: widget.companyData,
            transaction: linked,
            debugUnlockModule: widget.debugUnlockModule,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).add_jm().format(d);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountLabel = _account != null
        ? '${_account!.accountCode} · ${_account!.name}'
        : _tx.accountId;
    final categoryLabel = _category != null
        ? '${_category!.categoryCode} · ${_category!.name}'
        : (_tx.cashFlowCategoryCode ?? _tx.cashFlowCategoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'transaction_detail')),
        actions: [
          if (_canEdit)
            IconButton(
              tooltip: FinanceStrings.t(context, 'transaction_edit'),
              onPressed: _actionInProgress ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _tx.transactionCode.isNotEmpty ? _tx.transactionCode : _tx.id,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Chip(
            label: Text(
              FinanceDisplayLabels.transactionStatus(context, _tx.status),
            ),
          ),
          const SizedBox(height: 16),
          _row(
            FinanceStrings.t(context, 'amount'),
            FinanceMoneyFormat.format(_tx.amount, _tx.currency),
          ),
          _row(
            FinanceStrings.t(context, 'direction'),
            FinanceDisplayLabels.transactionDirection(context, _tx.direction),
          ),
          _row(FinanceStrings.t(context, 'transaction_date'), _formatDate(_tx.transactionDate)),
          _row(FinanceStrings.t(context, 'account'), accountLabel),
          _row(FinanceStrings.t(context, 'category'), categoryLabel),
          if ((_tx.cashFlowActivityType ?? '').isNotEmpty)
            _row(
              FinanceStrings.t(context, 'activity_type'),
              FinanceDisplayLabels.activityType(
                context,
                _tx.cashFlowActivityType!,
              ),
            ),
          if ((_tx.description ?? '').isNotEmpty)
            _row(FinanceStrings.t(context, 'description'), _tx.description!),
          if ((_tx.reference ?? '').isNotEmpty)
            _row(FinanceStrings.t(context, 'reference'), _tx.reference!),
          if ((_tx.plantKey ?? '').isNotEmpty)
            _row(FinanceStrings.t(context, 'plant_key'), _tx.plantKey!),
          const Divider(height: 32),
          Text(
            FinanceStrings.t(context, 'audit_section'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _row(
            FinanceStrings.t(context, 'audit_created_by'),
            _tx.createdByEmail ?? _tx.createdBy ?? '—',
          ),
          if (_tx.postedBy != null || _tx.postedByEmail != null)
            _row(
              FinanceStrings.t(context, 'audit_posted_by'),
              _tx.postedByEmail ?? _tx.postedBy ?? '—',
            ),
          if (_tx.postedAt != null)
            _row(
              FinanceStrings.t(context, 'audit_posted_at'),
              _formatDateTime(_tx.postedAt),
            ),
          if (_tx.reconciledBy != null || _tx.reconciledByEmail != null)
            _row(
              FinanceStrings.t(context, 'audit_reconciled_by'),
              _tx.reconciledByEmail ?? _tx.reconciledBy ?? '—',
            ),
          if (_tx.reconciledAt != null)
            _row(
              FinanceStrings.t(context, 'audit_reconciled_at'),
              _formatDateTime(_tx.reconciledAt),
            ),
          if (_tx.reversalTransactionId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(FinanceStrings.t(context, 'link_reversal')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _actionInProgress
                  ? null
                  : () => _openLinked(_tx.reversalTransactionId),
            ),
          if (_tx.reversalOfTransactionId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(FinanceStrings.t(context, 'link_original')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _actionInProgress
                  ? null
                  : () => _openLinked(_tx.reversalOfTransactionId),
            ),
          const SizedBox(height: 24),
          if (_canPost)
            FilledButton(
              onPressed: _actionInProgress ? null : _post,
              child: _actionInProgress
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(FinanceStrings.t(context, 'post_transaction')),
            ),
          if (_canReconcile) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _actionInProgress ? null : _reconcile,
              child: Text(FinanceStrings.t(context, 'reconcile_transaction')),
            ),
          ],
          if (_canReverse) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _actionInProgress ? null : _reverse,
              child: Text(FinanceStrings.t(context, 'reverse_transaction')),
            ),
          ],
          if (_canCancelDraft) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _actionInProgress ? null : _cancelDraft,
              child: Text(FinanceStrings.t(context, 'cancel_draft')),
            ),
          ],
        ],
      ),
    );
  }
}
