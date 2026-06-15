import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_open_items_summary.dart';

class FinanceInvoiceSummaryCard extends StatelessWidget {
  const FinanceInvoiceSummaryCard({
    super.key,
    required this.summary,
    required this.currencyHint,
  });

  final FinanceOpenItemsSummary summary;
  final String? currencyHint;

  @override
  Widget build(BuildContext context) {
    final cur = currencyHint ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              context,
              FinanceStrings.t(context, 'open_items_count'),
              summary.invoiceCount.toString(),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'open_items_total'),
              FinanceMoneyFormat.format(summary.totalOpenAmount, cur),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'open_items_overdue_count'),
              summary.overdueCount.toString(),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'open_items_overdue_amount'),
              FinanceMoneyFormat.format(summary.overdueAmount, cur),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class FinanceInvoiceStatusChip extends StatelessWidget {
  const FinanceInvoiceStatusChip({
    super.key,
    required this.status,
    this.isOverdue = false,
    this.isErpSynced = false,
  });

  final String status;
  final bool isOverdue;
  final bool isErpSynced;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Chip(
          label: Text(
            FinanceDisplayLabels.invoiceStatus(context, status),
            style: const TextStyle(fontSize: 12),
          ),
          visualDensity: VisualDensity.compact,
        ),
        if (isOverdue)
          Chip(
            label: Text(
              FinanceStrings.t(context, 'invoice_overdue'),
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red.shade100,
            visualDensity: VisualDensity.compact,
          ),
        if (isErpSynced)
          Chip(
            avatar: const Icon(Icons.sync, size: 16),
            label: Text(
              FinanceStrings.t(context, 'invoice_erp_synced'),
              style: const TextStyle(fontSize: 12),
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

String formatFinanceInvoiceDate(BuildContext context, DateTime? date) {
  if (date == null) return '—';
  return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
      .format(date);
}
