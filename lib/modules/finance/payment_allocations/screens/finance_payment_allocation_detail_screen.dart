import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_payment_allocation.dart';
import '../services/finance_payment_allocations_service.dart';

class FinancePaymentAllocationDetailScreen extends StatelessWidget {
  const FinancePaymentAllocationDetailScreen({
    super.key,
    required this.companyData,
    required this.allocation,
    this.debugUnlockModule = false,
    this.onChanged,
  });

  final Map<String, dynamic> companyData;
  final FinancePaymentAllocation allocation;
  final bool debugUnlockModule;
  final VoidCallback? onChanged;

  String get _role => (companyData['role'] ?? '').toString().trim();

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  bool get _canCancel => allocation.isActive &&
      FinancePermissions.canCancelPaymentAllocation(
        companyData: companyData,
        role: _role,
        debugUnlockModule: debugUnlockModule,
      );

  String _formatDate(BuildContext context, DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .add_jm()
        .format(d);
  }

  Future<void> _cancel(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, 'allocation_cancel')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(FinanceStrings.t(ctx, 'allocation_cancel_warning')),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: FinanceStrings.t(ctx, 'allocation_cancel_reason'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(FinanceStrings.t(ctx, 'allocation_cancel_confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await FinancePaymentAllocationsService().cancelAllocation(
        companyId: _companyId,
        allocationId: allocation.id,
        cancelReason: reasonCtrl.text.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_cancelled'))),
      );
      onChanged?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    } finally {
      reasonCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = allocation;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          a.allocationCode.isNotEmpty ? a.allocationCode : a.id,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Chip(
            label: Text(FinanceDisplayLabels.allocationStatus(context, a.status)),
          ),
          const SizedBox(height: 12),
          _row(
            context,
            FinanceStrings.t(context, 'allocation_line_amount'),
            FinanceMoneyFormat.format(a.allocatedAmount, a.currency),
          ),
          _row(
            context,
            FinanceStrings.t(context, 'transaction_code'),
            a.transactionCode ?? a.transactionId,
          ),
          _row(
            context,
            FinanceStrings.t(context, 'invoice_number'),
            a.invoiceNumber ?? a.invoiceId,
          ),
          _row(
            context,
            FinanceStrings.t(context, 'allocation_allocated_at'),
            _formatDate(context, a.allocatedAt),
          ),
          _row(
            context,
            FinanceStrings.t(context, 'allocation_allocated_by'),
            a.allocatedByEmail ?? a.allocatedBy ?? '—',
          ),
          if (a.isCancelled) ...[
            _row(
              context,
              FinanceStrings.t(context, 'allocation_cancelled_at'),
              _formatDate(context, a.cancelledAt),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'allocation_cancelled_by'),
              a.cancelledByEmail ?? a.cancelledBy ?? '—',
            ),
            if ((a.cancelReason ?? '').isNotEmpty)
              _row(
                context,
                FinanceStrings.t(context, 'allocation_cancel_reason'),
                a.cancelReason!,
              ),
          ],
          const SizedBox(height: 24),
          if (_canCancel)
            FilledButton(
              onPressed: () => _cancel(context),
              child: Text(FinanceStrings.t(context, 'allocation_cancel')),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

/// Dijalog za poništenje alokacije (koristi se iz liste na fakturi / transakciji).
Future<bool> showFinanceCancelAllocationDialog({
  required BuildContext context,
  required String companyId,
  required FinancePaymentAllocation allocation,
}) async {
  final reasonCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(FinanceStrings.t(ctx, 'allocation_cancel')),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(FinanceStrings.t(ctx, 'allocation_cancel_warning')),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(ctx, 'allocation_cancel_reason'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(FinanceStrings.t(ctx, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (reasonCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
          child: Text(FinanceStrings.t(ctx, 'allocation_cancel_confirm')),
        ),
      ],
    ),
  );
  if (ok != true) {
    reasonCtrl.dispose();
    return false;
  }
  try {
    await FinancePaymentAllocationsService().cancelAllocation(
      companyId: companyId,
      allocationId: allocation.id,
      cancelReason: reasonCtrl.text.trim(),
    );
    return true;
  } finally {
    reasonCtrl.dispose();
  }
}
