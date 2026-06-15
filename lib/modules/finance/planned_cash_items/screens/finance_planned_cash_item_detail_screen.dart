import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_planned_cash_item.dart';
import '../services/finance_planned_cash_items_service.dart';
import 'finance_planned_cash_item_form_screen.dart';

class FinancePlannedCashItemDetailScreen extends StatefulWidget {
  const FinancePlannedCashItemDetailScreen({
    super.key,
    required this.companyData,
    required this.item,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinancePlannedCashItem item;
  final bool debugUnlockModule;

  @override
  State<FinancePlannedCashItemDetailScreen> createState() =>
      _FinancePlannedCashItemDetailScreenState();
}

class _FinancePlannedCashItemDetailScreenState
    extends State<FinancePlannedCashItemDetailScreen> {
  final _service = FinancePlannedCashItemsService();
  late FinancePlannedCashItem _item;
  bool _busy = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canEdit => _item.isDraft &&
      FinancePermissions.canEditPlannedCashItemDraft(
        companyData: widget.companyData,
        role: _role,
        itemCreatedBy: _item.createdBy ?? '',
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canApprove => _item.isDraft &&
      FinancePermissions.canApproveCancelPlannedCashItem(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canCancel =>
      (_item.isDraft || _item.isApproved) &&
      FinancePermissions.canApproveCancelPlannedCashItem(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _service.getItem(
        companyId: _companyId,
        plannedCashItemId: _item.id,
      );
      if (!mounted) return;
      setState(() => _item = fresh);
    } catch (_) {
      /* keep cached */
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, 'approve_planned_item')),
        content: Text(FinanceStrings.t(ctx, 'approve_planned_item_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(ctx, 'approve_planned_item')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _service.approveItem(
        companyId: _companyId,
        plannedCashItemId: _item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'planned_item_approved'))),
      );
      await _refresh();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, 'cancel_planned_item')),
        content: Text(FinanceStrings.t(ctx, 'cancel_planned_item_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(ctx, 'cancel_planned_item')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _service.cancelItem(
        companyId: _companyId,
        plannedCashItemId: _item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'planned_item_cancelled'))),
      );
      await _refresh();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinancePlannedCashItemFormScreen(
          companyData: widget.companyData,
          item: _item,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) {
      await _refresh();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = _item.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'planned_item_detail')),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _edit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_item.isApproved)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(FinanceStrings.t(context, 'planned_readonly_hint')),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _item.description,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _row(
                    FinanceStrings.t(context, 'status'),
                    FinanceDisplayLabels.plannedCashItemStatus(
                      context,
                      _item.status,
                    ),
                  ),
                  _row(
                    FinanceStrings.t(context, 'direction'),
                    FinanceDisplayLabels.transactionDirection(
                      context,
                      _item.direction,
                    ),
                  ),
                  _row(
                    FinanceStrings.t(context, 'expected_date'),
                    _formatDate(_item.expectedDate),
                  ),
                  _row(
                    FinanceStrings.t(context, 'nominal_amount'),
                    FinanceMoneyFormat.format(_item.nominalAmount, currency),
                  ),
                  _row(
                    FinanceStrings.t(context, 'weighted_amount'),
                    FinanceMoneyFormat.format(_item.weightedAmount, currency),
                  ),
                  _row(
                    FinanceStrings.t(context, 'probability_percent'),
                    '${_item.probabilityPercent.toStringAsFixed(0)}%',
                  ),
                  _row(
                    FinanceStrings.t(context, 'probability_source'),
                    FinanceDisplayLabels.probabilitySource(
                      context,
                      _item.probabilitySource,
                    ),
                  ),
                  _row(
                    FinanceStrings.t(context, 'currency'),
                    currency,
                  ),
                ],
              ),
            ),
          ),
          if (_canApprove || _canCancel) ...[
            const SizedBox(height: 16),
            if (_canApprove)
              FilledButton(
                onPressed: _busy ? null : _approve,
                child: Text(FinanceStrings.t(context, 'approve_planned_item')),
              ),
            if (_canCancel) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                child: Text(FinanceStrings.t(context, 'cancel_planned_item')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
