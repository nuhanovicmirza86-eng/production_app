import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../../payment_allocations/widgets/finance_payment_allocations_section.dart';
import '../models/finance_sales_invoice.dart';
import '../services/finance_invoices_service.dart';
import '../widgets/finance_invoice_widgets.dart';
import 'finance_sales_invoice_form_screen.dart';

class FinanceSalesInvoiceDetailScreen extends StatefulWidget {
  const FinanceSalesInvoiceDetailScreen({
    super.key,
    required this.companyData,
    required this.invoice,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceSalesInvoice invoice;
  final bool debugUnlockModule;

  @override
  State<FinanceSalesInvoiceDetailScreen> createState() =>
      _FinanceSalesInvoiceDetailScreenState();
}

class _FinanceSalesInvoiceDetailScreenState
    extends State<FinanceSalesInvoiceDetailScreen> {
  final _service = FinanceInvoicesService();
  late FinanceSalesInvoice _invoice;
  bool _busy = false;
  final _allocationsKey = GlobalKey<FinancePaymentAllocationsSectionState>();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canEdit => _invoice.isDraft &&
      FinancePermissions.canEditFinanceInvoiceDraft(
        companyData: widget.companyData,
        role: _role,
        invoiceCreatedBy: _invoice.createdBy ?? '',
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canIssue => _invoice.isDraft &&
      FinancePermissions.canIssueSalesInvoice(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  bool get _canCancel => _invoice.canCancelDraftOrOpen &&
      FinancePermissions.canCancelFinanceInvoice(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _service.getSalesInvoice(
        companyId: _companyId,
        invoiceId: _invoice.id,
      );
      if (!mounted) return;
      setState(() => _invoice = fresh);
      await _allocationsKey.currentState?.reload();
    } catch (_) {
      /* keep cached row */
    }
  }

  Future<void> _issue() async {
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    DateTime? issueDate = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(FinanceStrings.t(ctx, 'issue_sales_invoice')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FinanceDatePickerField(
                    label: FinanceStrings.t(ctx, 'due_date'),
                    value: dueDate,
                    onChanged: (d) => setLocal(() => dueDate = d),
                  ),
                  const SizedBox(height: 12),
                  FinanceDatePickerField(
                    label: FinanceStrings.t(ctx, 'issue_date'),
                    value: issueDate,
                    onChanged: (d) => setLocal(() => issueDate = d),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(FinanceStrings.t(ctx, 'cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(FinanceStrings.t(ctx, 'issue_sales_invoice')),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _service.issueSalesInvoice(
        companyId: _companyId,
        invoiceId: _invoice.id,
        dueDate: dueDate,
        issueDate: issueDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'invoice_issued'))),
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
        title: Text(FinanceStrings.t(ctx, 'cancel_invoice')),
        content: Text(FinanceStrings.t(ctx, 'cancel_invoice_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(ctx, 'cancel_invoice')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _service.cancelSalesInvoice(
        companyId: _companyId,
        invoiceId: _invoice.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'invoice_cancelled'))),
      );
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
        builder: (_) => FinanceSalesInvoiceFormScreen(
          companyData: widget.companyData,
          invoice: _invoice,
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
    final inv = _invoice;
    return Scaffold(
      appBar: AppBar(
        title: Text(inv.invoiceNumber),
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
          FinanceInvoiceStatusChip(
            status: inv.status,
            isOverdue: inv.isOverdue,
            isErpSynced: inv.isErpSynced,
          ),
          const SizedBox(height: 16),
          _DetailRow(
            FinanceStrings.t(context, 'customer_name'),
            inv.customerName ?? '—',
          ),
          _DetailRow(
            FinanceStrings.t(context, 'status'),
            FinanceDisplayLabels.invoiceStatus(context, inv.status),
          ),
          _DetailRow(
            FinanceStrings.t(context, 'total_amount'),
            FinanceMoneyFormat.format(inv.totalAmount, inv.currency),
          ),
          _DetailRow(
            FinanceStrings.t(context, 'paid_amount'),
            FinanceMoneyFormat.format(inv.paidAmount, inv.currency),
          ),
          _DetailRow(
            FinanceStrings.t(context, 'open_amount'),
            FinanceMoneyFormat.format(inv.openAmount, inv.currency),
          ),
          _DetailRow(
            FinanceStrings.t(context, 'issue_date'),
            formatFinanceInvoiceDate(context, inv.issueDate),
          ),
          _DetailRow(
            FinanceStrings.t(context, 'due_date'),
            formatFinanceInvoiceDate(context, inv.dueDate),
          ),
          if (inv.description != null && inv.description!.isNotEmpty)
            _DetailRow(
              FinanceStrings.t(context, 'description'),
              inv.description!,
            ),
          if (inv.reference != null && inv.reference!.isNotEmpty)
            _DetailRow(
              FinanceStrings.t(context, 'reference'),
              inv.reference!,
            ),
          const Divider(height: 32),
          FinancePaymentAllocationsSection(
            key: _allocationsKey,
            companyData: widget.companyData,
            debugUnlockModule: widget.debugUnlockModule,
            mode: FinancePaymentAllocationsSectionMode.invoice,
            invoiceId: inv.id,
            invoiceType: 'sales',
            onChanged: _refresh,
          ),
          const SizedBox(height: 24),
          if (_canIssue)
            FilledButton(
              onPressed: _busy ? null : _issue,
              child: Text(FinanceStrings.t(context, 'issue_sales_invoice')),
            ),
          if (_canCancel) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _cancel,
              child: Text(FinanceStrings.t(context, 'cancel_invoice')),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
