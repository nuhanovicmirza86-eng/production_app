import 'dart:math';

import 'package:flutter/material.dart';

import '../../ai_advisory/services/finance_ai_advisory_action_bridge.dart';
import '../../ai_advisory/services/finance_ai_outcome_service.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../cash_transactions/models/finance_cash_transaction.dart';
import '../../cash_transactions/services/finance_cash_transactions_service.dart';
import '../../invoices/models/finance_purchase_invoice.dart';
import '../../invoices/models/finance_sales_invoice.dart';
import '../../invoices/services/finance_invoices_service.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../services/finance_payment_allocations_service.dart';
import '../widgets/finance_allocation_amount_field.dart';

class FinanceAllocatePaymentScreen extends StatefulWidget {
  const FinanceAllocatePaymentScreen({
    super.key,
    required this.companyData,
    required this.transaction,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceCashTransaction transaction;
  final bool debugUnlockModule;

  @override
  State<FinanceAllocatePaymentScreen> createState() =>
      _FinanceAllocatePaymentScreenState();
}

class _AllocationDraftLine {
  _AllocationDraftLine({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.invoiceType,
    required this.openAmount,
    required this.currency,
  }) : amountController = TextEditingController();

  final String invoiceId;
  final String invoiceNumber;
  final String invoiceType;
  final double openAmount;
  final String currency;
  final TextEditingController amountController;

  void dispose() => amountController.dispose();
}

class _FinanceAllocatePaymentScreenState
    extends State<FinanceAllocatePaymentScreen> {
  final _invoicesService = FinanceInvoicesService();
  final _allocService = FinancePaymentAllocationsService();
  final _txService = FinanceCashTransactionsService();
  final _formKey = GlobalKey<FormState>();

  late FinanceCashTransaction _tx;
  bool _loadingInvoices = true;
  bool _actionInProgress = false;
  String? _loadError;

  List<FinanceSalesInvoice> _salesCandidates = const [];
  List<FinancePurchaseInvoice> _purchaseCandidates = const [];
  final List<_AllocationDraftLine> _lines = [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _isInflow => _tx.direction == 'inflow';

  double get _sumAllocated {
    var sum = 0.0;
    for (final line in _lines) {
      final v = FinanceAllocationAmountUtils.parsePositive(
        line.amountController.text,
      );
      if (v != null) sum += v;
    }
    return FinanceAllocationAmountUtils.round2(sum);
  }

  double get _remaining =>
      FinanceAllocationAmountUtils.round2(
        _tx.effectiveUnallocatedAmount - _sumAllocated,
      );

  bool get _canSubmit {
    if (_lines.isEmpty || _actionInProgress) return false;
    if (_remaining < -FinanceAllocationAmountUtils.tolerance) return false;
    if (_sumAllocated <= FinanceAllocationAmountUtils.tolerance) return false;
    for (final line in _lines) {
      final amount = FinanceAllocationAmountUtils.parsePositive(
        line.amountController.text,
      );
      if (amount == null) return false;
      if (amount - line.openAmount > FinanceAllocationAmountUtils.tolerance) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
    _load();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingInvoices = true;
      _loadError = null;
    });
    try {
      final fresh = await _txService.findTransactionById(
        companyId: _companyId,
        transactionId: _tx.id,
      );
      if (fresh != null) _tx = fresh;

      if (_isInflow) {
        final all = await _invoicesService.listSalesInvoices(
          companyId: _companyId,
          openOnly: true,
          limit: 200,
        );
        _salesCandidates = all.where(_isEligibleSales).toList();
        _purchaseCandidates = const [];
      } else {
        final all = await _invoicesService.listPurchaseInvoices(
          companyId: _companyId,
          openOnly: true,
          limit: 200,
        );
        _purchaseCandidates = all.where(_isEligiblePurchase).toList();
        _salesCandidates = const [];
      }
      if (!mounted) return;
      setState(() => _loadingInvoices = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInvoices = false;
        _loadError = FinanceErrorMapper.toMessage(e, context: context);
      });
    }
  }

  bool _isEligibleSales(FinanceSalesInvoice inv) {
    return inv.currency.toUpperCase() == _tx.currency.toUpperCase() &&
        (inv.status == 'open' || inv.status == 'partial') &&
        inv.openAmount > FinanceAllocationAmountUtils.tolerance;
  }

  bool _isEligiblePurchase(FinancePurchaseInvoice inv) {
    return inv.currency.toUpperCase() == _tx.currency.toUpperCase() &&
        (inv.status == 'open' || inv.status == 'partial') &&
        inv.openAmount > FinanceAllocationAmountUtils.tolerance;
  }

  bool _alreadySelected(String invoiceId) {
    return _lines.any((l) => l.invoiceId == invoiceId);
  }

  Future<void> _pickInvoice() async {
    if (_isInflow) {
      await _showSalesPicker();
    } else {
      await _showPurchasePicker();
    }
  }

  Future<void> _showSalesPicker() async {
    final available =
        _salesCandidates.where((i) => !_alreadySelected(i.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_no_invoices'))),
      );
      return;
    }
    final picked = await showModalBottomSheet<FinanceSalesInvoice>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InvoicePickerSheet<FinanceSalesInvoice>(
        title: FinanceStrings.t(ctx, 'allocation_pick_sales_invoice'),
        items: available,
        labelBuilder: (i) => i.invoiceNumber,
        subtitleBuilder: (i) =>
            '${FinanceMoneyFormat.format(i.openAmount, i.currency)} · ${FinanceDisplayLabels.invoiceStatus(ctx, i.status)}',
      ),
    );
    if (picked == null) return;
    setState(() {
      _lines.add(
        _AllocationDraftLine(
          invoiceId: picked.id,
          invoiceNumber: picked.invoiceNumber,
          invoiceType: 'sales',
          openAmount: picked.openAmount,
          currency: picked.currency,
        ),
      );
    });
  }

  Future<void> _showPurchasePicker() async {
    final available =
        _purchaseCandidates.where((i) => !_alreadySelected(i.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_no_invoices'))),
      );
      return;
    }
    final picked = await showModalBottomSheet<FinancePurchaseInvoice>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _InvoicePickerSheet<FinancePurchaseInvoice>(
        title: FinanceStrings.t(ctx, 'allocation_pick_purchase_invoice'),
        items: available,
        labelBuilder: (i) => i.invoiceNumber,
        subtitleBuilder: (i) =>
            '${FinanceMoneyFormat.format(i.openAmount, i.currency)} · ${FinanceDisplayLabels.invoiceStatus(ctx, i.status)}',
      ),
    );
    if (picked == null) return;
    setState(() {
      _lines.add(
        _AllocationDraftLine(
          invoiceId: picked.id,
          invoiceNumber: picked.invoiceNumber,
          invoiceType: 'purchase',
          openAmount: picked.openAmount,
          currency: picked.currency,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_canSubmit || _actionInProgress) {
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      final lines = _lines
          .map(
            (l) => FinanceAllocationLineInput(
              invoiceType: l.invoiceType,
              invoiceId: l.invoiceId,
              allocatedAmount: FinanceAllocationAmountUtils.parsePositive(
                l.amountController.text,
              )!,
            ),
          )
          .toList();
      final result = await _allocService.allocatePayment(
        companyId: _companyId,
        transactionId: _tx.id,
        lines: lines,
        requestId:
            '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 30)}',
      );
      final auditLogId = (result['auditLogId'] ?? '').toString().trim();
      if (auditLogId.isNotEmpty) {
        await FinanceAiAdvisoryActionBridge.tryCompleteFromWorkflow(
          outcomeService: FinanceAiOutcomeService(),
          targetEntityType: 'finance_cash_transaction',
          targetEntityId: _tx.id,
          actionAuditId: auditLogId,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_saved'))),
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

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canCreatePaymentAllocation(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'allocate_to_invoices')),
        ),
        body: Center(
          child: Text(FinanceStrings.t(context, 'access_denied')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'allocate_to_invoices')),
        actions: [
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            onPressed: _actionInProgress ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingInvoices
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _loadError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  _SummaryCard(tx: _tx, sumAllocated: _sumAllocated, remaining: _remaining),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _actionInProgress ? null : _pickInvoice,
                    icon: const Icon(Icons.add),
                    label: Text(FinanceStrings.t(context, 'allocation_add_invoice')),
                  ),
                  const SizedBox(height: 12),
                  if (_lines.isEmpty)
                    Text(FinanceStrings.t(context, 'allocation_lines_empty')),
                  ...List.generate(_lines.length, (index) {
                    final line = _lines[index];
                    final parsed = FinanceAllocationAmountUtils.parsePositive(
                      line.amountController.text,
                    );
                    final invoiceRemaining = parsed == null
                        ? line.openAmount
                        : FinanceAllocationAmountUtils.round2(
                            line.openAmount - parsed,
                          );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    line.invoiceNumber,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _actionInProgress
                                      ? null
                                      : () => _removeLine(index),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            Text(
                              '${FinanceStrings.t(context, 'open_amount')}: ${FinanceMoneyFormat.format(line.openAmount, line.currency)}',
                            ),
                            const SizedBox(height: 8),
                            FinanceAllocationAmountField(
                              controller: line.amountController,
                              label: FinanceStrings.t(context, 'allocation_line_amount'),
                              enabled: !_actionInProgress,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${FinanceStrings.t(context, 'allocation_invoice_remaining')}: ${FinanceMoneyFormat.format(invoiceRemaining.clamp(0, double.infinity), line.currency)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_remaining < -FinanceAllocationAmountUtils.tolerance)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        FinanceStrings.t(context, 'allocation_exceeds_unallocated'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _actionInProgress
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(FinanceStrings.t(context, 'allocation_confirm')),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tx,
    required this.sumAllocated,
    required this.remaining,
  });

  final FinanceCashTransaction tx;
  final double sumAllocated;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tx.transactionCode.isNotEmpty ? tx.transactionCode : tx.id,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _row(
              context,
              FinanceStrings.t(context, 'amount'),
              FinanceMoneyFormat.format(tx.amount, tx.currency),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'allocated_amount'),
              FinanceMoneyFormat.format(tx.allocatedAmount, tx.currency),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'unallocated_amount'),
              FinanceMoneyFormat.format(tx.effectiveUnallocatedAmount, tx.currency),
            ),
            const Divider(height: 24),
            _row(
              context,
              FinanceStrings.t(context, 'allocation_batch_total'),
              FinanceMoneyFormat.format(sumAllocated, tx.currency),
            ),
            _row(
              context,
              FinanceStrings.t(context, 'allocation_remaining_tx'),
              FinanceMoneyFormat.format(remaining, tx.currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _InvoicePickerSheet<T> extends StatelessWidget {
  const _InvoicePickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final String Function(T item) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(
                      labelBuilder(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(subtitleBuilder(item)),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
