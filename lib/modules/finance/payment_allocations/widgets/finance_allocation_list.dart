import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_payment_allocation.dart';

class FinanceAllocationList extends StatelessWidget {
  const FinanceAllocationList({
    super.key,
    required this.items,
    required this.activeAllocatedTotal,
    this.canCancel = false,
    this.actionInProgress = false,
    this.onCancel,
    this.onTap,
    this.showInvoiceColumn = true,
    this.showTransactionColumn = false,
  });

  final List<FinancePaymentAllocation> items;
  final double activeAllocatedTotal;
  final bool canCancel;
  final bool actionInProgress;
  final void Function(FinancePaymentAllocation item)? onCancel;
  final void Function(FinancePaymentAllocation item)? onTap;
  final bool showInvoiceColumn;
  final bool showTransactionColumn;

  String _formatDate(BuildContext context, DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(FinanceStrings.t(context, 'allocations_empty')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FinanceStrings.t(context, 'allocations_active_total'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          FinanceMoneyFormat.format(activeAllocatedTotal, items.first.currency),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final title = showInvoiceColumn
              ? (item.invoiceNumber?.isNotEmpty == true
                    ? item.invoiceNumber!
                    : item.invoiceId)
              : (item.transactionCode?.isNotEmpty == true
                    ? item.transactionCode!
                    : item.transactionId);
          final subtitleParts = <String>[
            FinanceMoneyFormat.format(item.allocatedAmount, item.currency),
            _formatDate(context, item.allocatedAt),
            FinanceDisplayLabels.allocationStatus(context, item.status),
          ];
          if (showInvoiceColumn && (item.partnerName ?? '').isNotEmpty) {
            subtitleParts.insert(0, item.partnerName!);
          }
          if (showTransactionColumn && (item.invoiceNumber ?? '').isNotEmpty) {
            subtitleParts.insert(0, item.invoiceNumber!);
          }
          final executor =
              item.allocatedByEmail ?? item.allocatedBy ?? item.createdByEmail;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: subtitleParts
                        .map((s) => Chip(label: Text(s), visualDensity: VisualDensity.compact))
                        .toList(),
                  ),
                  if (executor != null && executor.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${FinanceStrings.t(context, 'allocation_allocated_by')}: $executor',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (item.isCancelled && (item.cancelReason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${FinanceStrings.t(context, 'allocation_cancel_reason')}: ${item.cancelReason}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              trailing: canCancel && item.isActive
                  ? IconButton(
                      tooltip: FinanceStrings.t(context, 'allocation_cancel'),
                      onPressed: actionInProgress
                          ? null
                          : () => onCancel?.call(item),
                      icon: const Icon(Icons.undo_outlined),
                    )
                  : (onTap != null ? const Icon(Icons.chevron_right) : null),
              onTap: onTap == null ? null : () => onTap!(item),
            ),
          );
        }),
      ],
    );
  }
}
