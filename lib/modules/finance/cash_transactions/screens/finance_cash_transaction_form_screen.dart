import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../accounts/models/finance_account.dart';
import '../../accounts/services/finance_accounts_service.dart';
import '../../cash_flow_categories/models/finance_cash_flow_category.dart';
import '../../cash_flow_categories/services/finance_cash_flow_categories_service.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_transaction.dart';
import '../services/finance_cash_transactions_service.dart';

class FinanceCashTransactionFormScreen extends StatefulWidget {
  const FinanceCashTransactionFormScreen({
    super.key,
    required this.companyData,
    this.transaction,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinanceCashTransaction? transaction;
  final bool debugUnlockModule;

  bool get isEdit => transaction != null;

  @override
  State<FinanceCashTransactionFormScreen> createState() =>
      _FinanceCashTransactionFormScreenState();
}

class _FinanceCashTransactionFormScreenState
    extends State<FinanceCashTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _txService = FinanceCashTransactionsService();
  final _accountsService = FinanceAccountsService();
  final _categoriesService = FinanceCashFlowCategoriesService();

  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _plantKeyCtrl = TextEditingController();

  bool _loadingMasters = true;
  bool _saving = false;
  List<FinanceAccount> _accounts = const [];
  List<FinanceCashFlowCategory> _categories = const [];

  String? _accountId;
  String? _categoryId;
  String _direction = 'inflow';
  DateTime? _transactionDate;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  FinanceAccount? get _selectedAccount {
    if (_accountId == null) return null;
    for (final a in _accounts) {
      if (a.id == _accountId) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _accountId = tx.accountId;
      _categoryId = tx.cashFlowCategoryId;
      _direction = tx.direction;
      _amountCtrl.text = tx.amount.toStringAsFixed(2);
      _descriptionCtrl.text = tx.description ?? '';
      _referenceCtrl.text = tx.reference ?? '';
      _plantKeyCtrl.text = tx.plantKey ?? '';
      _transactionDate = tx.transactionDate;
    } else {
      final now = DateTime.now();
      _transactionDate = DateTime(now.year, now.month, now.day);
    }
    _loadMasters();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _referenceCtrl.dispose();
    _plantKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() => _loadingMasters = true);
    try {
      final accounts = await _accountsService.listAccounts(
        companyId: _companyId,
        activeOnly: true,
      );
      final categories = await _categoriesService.listCategories(
        companyId: _companyId,
        activeOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _categories = categories;
        _loadingMasters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMasters = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null || _categoryId == null || _transactionDate == null) {
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;

    final account = _selectedAccount;
    if (account == null) return;

    if (widget.isEdit) {
      final tx = widget.transaction!;
      if (!FinancePermissions.canEditCashTransactionDraft(
        companyData: widget.companyData,
        role: _role,
        transactionCreatedBy: tx.createdBy ?? '',
        debugUnlockModule: widget.debugUnlockModule,
      )) {
        return;
      }
    } else if (!FinancePermissions.canCreateCashTransactionDraft(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _txService.updateDraft(
          companyId: _companyId,
          transactionId: widget.transaction!.id,
          accountId: _accountId,
          cashFlowCategoryId: _categoryId,
          direction: _direction,
          amount: amount,
          currency: account.currency,
          transactionDate: _transactionDate,
          description: _descriptionCtrl.text,
          reference: _referenceCtrl.text,
          plantKey: _plantKeyCtrl.text,
        );
      } else {
        await _txService.createDraft(
          companyId: _companyId,
          accountId: _accountId!,
          cashFlowCategoryId: _categoryId!,
          direction: _direction,
          amount: amount,
          currency: account.currency,
          transactionDate: _transactionDate!,
          description: _descriptionCtrl.text,
          reference: _referenceCtrl.text,
          plantKey: _plantKeyCtrl.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'saved'))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit
        ? FinanceStrings.t(context, 'transaction_edit')
        : FinanceStrings.t(context, 'transaction_new');

    if (_loadingMasters) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: FinanceAssistantScreens.transactionForm,
          tabKey: FinanceAssistantTabs.cashFlow,
          tabLabelKey: 'help_cash_flow_tab_title',
        ),
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.transactionForm,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
      ),
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'account'),
                border: const OutlineInputBorder(),
              ),
              value: _accounts.any((a) => a.id == _accountId) ? _accountId : null,
              items: _accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.accountCode} · ${a.name} (${a.currency})'),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _accountId = v),
              validator: (v) =>
                  v == null ? FinanceStrings.t(context, 'select_account') : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'category'),
                border: const OutlineInputBorder(),
              ),
              value:
                  _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.categoryCode} · ${c.name} · ${FinanceDisplayLabels.activityType(context, c.cashFlowActivityType)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _categoryId = v),
              validator: (v) => v == null
                  ? FinanceStrings.t(context, 'select_category')
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'direction'),
                border: const OutlineInputBorder(),
              ),
              value: _direction,
              items: FinanceDisplayLabels.transactionDirectionCodes
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(
                        FinanceDisplayLabels.transactionDirection(context, code),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _direction = v);
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'amount'),
                border: const OutlineInputBorder(),
                suffixText: _selectedAccount?.currency,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) {
                  return FinanceStrings.t(context, 'amount');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FinanceDatePickerField(
              label: FinanceStrings.t(context, 'transaction_date'),
              value: _transactionDate,
              onChanged: (d) => setState(() => _transactionDate = d),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'description'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _referenceCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'reference'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _plantKeyCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'plant_key'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(FinanceStrings.t(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}
