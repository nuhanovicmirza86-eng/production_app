import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../cash_flow_categories/models/finance_cash_flow_category.dart';
import '../../cash_flow_categories/services/finance_cash_flow_categories_service.dart';
import '../../invoices/models/finance_purchase_invoice.dart';
import '../../invoices/models/finance_sales_invoice.dart';
import '../../invoices/services/finance_invoices_service.dart';
import '../../payment_allocations/widgets/finance_allocation_amount_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_assistant/finance_assistant_context.dart';
import '../../shared/finance_help_info_button.dart';
import '../../shared/finance_labeled_filter_field.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_match_suggestion.dart';
import '../models/finance_bank_statement_transaction.dart';
import '../services/finance_bank_reconciliation_service.dart';
import '../utils/finance_bank_reconciliation_revision.dart';
import 'finance_bank_match_confirmation_detail_screen.dart';

class FinanceBankMatchConfirmScreen extends StatefulWidget {
  const FinanceBankMatchConfirmScreen({
    super.key,
    required this.companyData,
    required this.bankTransaction,
    this.initialSuggestion,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceBankStatementTransaction bankTransaction;
  final FinanceBankMatchSuggestion? initialSuggestion;
  final bool debugUnlockModule;

  @override
  State<FinanceBankMatchConfirmScreen> createState() =>
      _FinanceBankMatchConfirmScreenState();
}

class _ConfirmLineDraft {
  _ConfirmLineDraft({
    required this.invoiceType,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.openAmount,
    required this.currency,
    required this.revision,
  }) : amountController = TextEditingController();

  final String invoiceType;
  final String invoiceId;
  final String invoiceNumber;
  final double openAmount;
  final String currency;
  String revision;
  final TextEditingController amountController;

  void dispose() => amountController.dispose();
}

class _FinanceBankMatchConfirmScreenState
    extends State<FinanceBankMatchConfirmScreen> {
  final _service = FinanceBankReconciliationService();
  final _categoriesService = FinanceCashFlowCategoriesService();
  final _invoicesService = FinanceInvoicesService();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _requestId = const Uuid().v4();
  final _previewTick = ValueNotifier<int>(0);

  late FinanceBankStatementTransaction _bank;
  FinanceBankMatchSuggestion? _suggestion;
  List<FinanceCashFlowCategory> _categories = const [];
  List<FinanceSalesInvoice> _salesCandidates = const [];
  List<FinancePurchaseInvoice> _purchaseCandidates = const [];
  final List<_ConfirmLineDraft> _lines = [];

  String? _categoryId;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canSubmit {
    if (_submitting || _lines.isEmpty || _categoryId == null) return false;
    if (_sumAllocated <= FinanceAllocationAmountUtils.tolerance) return false;
    if (_sumAllocated > _bank.amount + FinanceAllocationAmountUtils.tolerance) {
      return false;
    }
    for (final line in _lines) {
      final v = FinanceAllocationAmountUtils.parsePositive(
        line.amountController.text,
      );
      if (v == null || v > line.openAmount + FinanceAllocationAmountUtils.tolerance) {
        return false;
      }
    }
    if (_suggestion?.isBlocked == true) return false;
    return true;
  }

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

  double get _unallocated =>
      FinanceAllocationAmountUtils.round2(_bank.amount - _sumAllocated);

  String get _previewResultKey {
    if (_sumAllocated > _bank.amount + FinanceAllocationAmountUtils.tolerance) {
      return 'bank_match_result_over';
    }
    if (_unallocated > FinanceAllocationAmountUtils.tolerance) {
      return 'bank_match_result_partial';
    }
    return 'bank_match_result_full';
  }

  @override
  void initState() {
    super.initState();
    _bank = widget.bankTransaction;
    _suggestion = widget.initialSuggestion;
    _bootstrap();
  }

  @override
  void dispose() {
    _previewTick.dispose();
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _bank = await _service.getBankTransaction(
        companyId: _companyId,
        transactionId: _bank.id,
      );
      final categories = await _categoriesService.listCategories(
        companyId: _companyId,
        activeOnly: true,
      );
      if (_bank.isInflow) {
        _salesCandidates = await _invoicesService.listSalesInvoices(
          companyId: _companyId,
          openOnly: true,
        );
      } else if (_bank.isOutflow) {
        _purchaseCandidates = await _invoicesService.listPurchaseInvoices(
          companyId: _companyId,
          openOnly: true,
        );
      }
      if (_suggestion != null) {
        await _addLineFromSuggestion(_suggestion!);
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  Future<void> _addLineFromSuggestion(
    FinanceBankMatchSuggestion sug, {
    bool prefillEmpty = false,
  }) async {
    final raw = await _loadInvoiceRaw(sug.invoiceType, sug.invoiceId);
    final revision = FinanceBankReconciliationRevision.revisionFromMap(
          raw,
          'invoiceRevision',
        ) ??
        FinanceBankReconciliationRevision.computeInvoiceRevision(raw);
    final line = _ConfirmLineDraft(
      invoiceType: sug.invoiceType,
      invoiceId: sug.invoiceId,
      invoiceNumber: sug.invoiceNumber,
      openAmount: sug.invoiceOpenAmount,
      currency: sug.currency,
      revision: revision,
    );
    if (!prefillEmpty) {
      final prefill = sug.invoiceOpenAmount <= _bank.amount
          ? sug.invoiceOpenAmount
          : _bank.amount;
      line.amountController.text = prefill.toStringAsFixed(2);
    }
    line.amountController.addListener(_bumpPreview);
    setState(() => _lines.add(line));
    _bumpPreview();
  }

  void _bumpPreview() {
    _previewTick.value++;
  }

  Future<void> _pickInvoice() async {
    if (_bank.isInflow) {
      await _pickSalesInvoice();
    } else if (_bank.isOutflow) {
      await _pickPurchaseInvoice();
    }
  }

  bool _alreadySelected(String invoiceId) =>
      _lines.any((l) => l.invoiceId == invoiceId);

  Future<void> _pickSalesInvoice() async {
    final available = _salesCandidates
        .where(
          (i) =>
              !_alreadySelected(i.id) &&
              i.currency.toUpperCase() == _bank.currency.toUpperCase(),
        )
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_no_invoices'))),
      );
      return;
    }
    final picked = await showModalBottomSheet<FinanceSalesInvoice>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SimpleInvoicePicker<FinanceSalesInvoice>(
        title: FinanceStrings.t(ctx, 'allocation_pick_sales_invoice'),
        items: available,
        label: (i) => i.invoiceNumber,
        subtitle: (i) =>
            FinanceMoneyFormat.format(i.openAmount, i.currency),
      ),
    );
    if (picked == null) return;
    final raw = await _loadInvoiceRaw('sales', picked.id);
    final revision = FinanceBankReconciliationRevision.revisionFromMap(
          raw,
          'invoiceRevision',
        ) ??
        FinanceBankReconciliationRevision.computeInvoiceRevision(raw);
    setState(() {
      final line = _ConfirmLineDraft(
        invoiceType: 'sales',
        invoiceId: picked.id,
        invoiceNumber: picked.invoiceNumber,
        openAmount: picked.openAmount,
        currency: picked.currency,
        revision: revision,
      );
      line.amountController.addListener(_bumpPreview);
      _lines.add(line);
    });
    _bumpPreview();
  }

  Future<void> _pickPurchaseInvoice() async {
    final available = _purchaseCandidates
        .where(
          (i) =>
              !_alreadySelected(i.id) &&
              i.currency.toUpperCase() == _bank.currency.toUpperCase(),
        )
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'allocation_no_invoices'))),
      );
      return;
    }
    final picked = await showModalBottomSheet<FinancePurchaseInvoice>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SimpleInvoicePicker<FinancePurchaseInvoice>(
        title: FinanceStrings.t(ctx, 'allocation_pick_purchase_invoice'),
        items: available,
        label: (i) => i.invoiceNumber,
        subtitle: (i) =>
            FinanceMoneyFormat.format(i.openAmount, i.currency),
      ),
    );
    if (picked == null) return;
    final raw = await _loadInvoiceRaw('purchase', picked.id);
    final revision = FinanceBankReconciliationRevision.revisionFromMap(
          raw,
          'invoiceRevision',
        ) ??
        FinanceBankReconciliationRevision.computeInvoiceRevision(raw);
    setState(() {
      final line = _ConfirmLineDraft(
        invoiceType: 'purchase',
        invoiceId: picked.id,
        invoiceNumber: picked.invoiceNumber,
        openAmount: picked.openAmount,
        currency: picked.currency,
        revision: revision,
      );
      line.amountController.addListener(_bumpPreview);
      _lines.add(line);
    });
    _bumpPreview();
  }

  Future<Map<String, dynamic>> _loadInvoiceRaw(
    String invoiceType,
    String invoiceId,
  ) async {
    if (invoiceType == 'purchase') {
      return _invoicesService.getPurchaseInvoiceRaw(
        companyId: _companyId,
        invoiceId: invoiceId,
      );
    }
    return _invoicesService.getSalesInvoiceRaw(
      companyId: _companyId,
      invoiceId: invoiceId,
    );
  }

  Future<void> _reloadConfirmContext() async {
    _bank = await _service.getBankTransaction(
      companyId: _companyId,
      transactionId: _bank.id,
    );
    for (final line in _lines) {
      final raw = await _loadInvoiceRaw(line.invoiceType, line.invoiceId);
      line.revision = FinanceBankReconciliationRevision.revisionFromMap(
            raw,
            'invoiceRevision',
          ) ??
          FinanceBankReconciliationRevision.computeInvoiceRevision(raw);
    }
    if (_suggestion != null) {
      _suggestion = await _service.getMatchSuggestion(
        companyId: _companyId,
        suggestionId: _suggestion!.id,
      );
    }
    if (mounted) {
      setState(() {});
      _bumpPreview();
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    setState(() => _submitting = true);
    try {
      final bankRevision = _bank.bankRevision ??
          FinanceBankReconciliationRevision.computeBankRevision(
            _bank.raw ?? {},
          );
      final callableLines = <Map<String, dynamic>>[];
      final expectedRevisions = <Map<String, dynamic>>[];

      for (final line in _lines) {
        final amount = FinanceAllocationAmountUtils.parsePositive(
          line.amountController.text,
        );
        if (amount == null) continue;
        callableLines.add({
          'invoiceType': line.invoiceType,
          'invoiceId': line.invoiceId,
          'allocatedAmount': amount,
        });
        expectedRevisions.add({
          'invoiceType': line.invoiceType,
          'invoiceId': line.invoiceId,
          'revision': line.revision,
        });
      }

      final result = await _service.confirmBankMatch(
        companyId: _companyId,
        bankStatementTransactionId: _bank.id,
        requestId: _requestId,
        cashFlowCategoryId: _categoryId!,
        expectedBankRevision: bankRevision,
        expectedInvoiceRevisions: expectedRevisions,
        suggestionId: _suggestion?.id,
        expectedSuggestionSourceStateHash: _suggestion?.sourceStateHash,
        lines: callableLines,
        reason: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        accountId: _bank.bankAccountId,
      );

      if (!mounted) return;
      final confirmationId =
          (result['confirmationId'] ?? result['confirmation']?['confirmationId'])
              ?.toString();
      if (confirmationId != null && confirmationId.isNotEmpty) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => FinanceBankMatchConfirmationDetailScreen(
              companyData: widget.companyData,
              debugUnlockModule: widget.debugUnlockModule,
              confirmationId: confirmationId,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      var msg = FinanceErrorMapper.toMessage(e, context: context);
      if (FinanceErrorMapper.isConcurrencyAborted(e)) {
        try {
          await _reloadConfirmContext();
        } catch (_) {
          // Prikaži poruku i bez osvježavanja.
        }
        msg = FinanceErrorMapper.bankMatchConfirmNotSavedMessage(context, e);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canConfirmBankMatch(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContext(
          companyId: _companyId,
          screenKey: FinanceAssistantScreens.bankMatchConfirm,
          tabKey: FinanceAssistantTabs.cashFlow,
          tabLabelKey: 'help_cash_flow_tab_title',
          role: _role,
          disabledActions: [
            FinanceStrings.t(context, 'bank_match_confirm'),
          ],
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'bank_match_confirm_title')),
        ),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    return FinanceScaffold(
      assistantContext: FinanceAssistantContext(
        companyId: _companyId,
        screenKey: FinanceAssistantScreens.bankMatchConfirm,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
        role: _role,
        entityStatus: FinanceDisplayLabels.bankStatementStatus(
          context,
          _bank.status,
        ),
        availableActions: [
          FinanceStrings.t(context, 'bank_match_confirm'),
        ],
      ),
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'bank_match_confirm_title')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _previewTick,
                    builder: (context, _, __) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FinanceStrings.t(context, 'bank_match_confirm_preview'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${FinanceStrings.t(context, 'bank_match_bank_amount')}: '
                              '${FinanceMoneyFormat.format(_bank.amount, _bank.currency)}',
                            ),
                            Text(
                              '${FinanceStrings.t(context, 'filter_direction')}: '
                              '${FinanceDisplayLabels.transactionDirection(context, _bank.direction)}',
                            ),
                            Text(
                              '${FinanceStrings.t(context, 'currency')}: ${_bank.currency}',
                            ),
                            const Divider(),
                            Text(
                              '${FinanceStrings.t(context, 'bank_match_allocated')}: '
                              '${FinanceMoneyFormat.format(_sumAllocated, _bank.currency)}',
                            ),
                            Text(
                              '${FinanceStrings.t(context, 'bank_match_unallocated')}: '
                              '${FinanceMoneyFormat.format(_unallocated, _bank.currency)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              FinanceStrings.t(context, _previewResultKey),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._lines.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final line = entry.value;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              line.invoiceNumber,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '${FinanceStrings.t(context, 'bank_match_open_amount')}: '
                              '${FinanceMoneyFormat.format(line.openAmount, line.currency)}',
                            ),
                            const SizedBox(height: 8),
                            FinanceAllocationAmountField(
                              key: ValueKey('alloc-${line.invoiceId}'),
                              controller: line.amountController,
                              label: FinanceStrings.t(
                                context,
                                'allocation_line_amount',
                              ),
                              currency: _bank.currency,
                              onChanged: (_) => _bumpPreview(),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () {
                                        setState(() {
                                          line.amountController
                                              .removeListener(_bumpPreview);
                                          line.dispose();
                                          _lines.removeAt(idx);
                                        });
                                        _bumpPreview();
                                      },
                                child: Text(FinanceStrings.t(context, 'cancel')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_suggestion != null && _lines.isEmpty)
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () => _addLineFromSuggestion(_suggestion!),
                      child: Text(FinanceStrings.t(context, 'bank_match_add_line')),
                    ),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickInvoice,
                    icon: const Icon(Icons.add),
                    label: Text(FinanceStrings.t(context, 'allocation_add_invoice')),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          FinanceStrings.t(context, 'bank_match_category'),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      const FinanceHelpInfoButton(
                        titleKey: 'help_term_cash_flow_category_title',
                        bodyKey: 'help_term_cash_flow_category_body',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _categoryId,
                    decoration: financeFilterInputDecoration(),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.categoryCode} · ${c.name}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => _categories
                        .map(
                          (c) => Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${c.categoryCode} · ${c.name}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (v) {
                            FocusScope.of(context).unfocus();
                            setState(() => _categoryId = v);
                          },
                    validator: (v) => v == null || v.isEmpty
                        ? FinanceStrings.t(context, 'allocation_amount_required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'bank_match_note'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            FinanceStrings.t(context, 'bank_match_confirm_submit'),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SimpleInvoicePicker<T> extends StatelessWidget {
  const _SimpleInvoicePicker({
    required this.title,
    required this.items,
    required this.label,
    required this.subtitle,
  });

  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) subtitle;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(label(item)),
                    subtitle: Text(subtitle(item)),
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
