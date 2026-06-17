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
import '../models/finance_planned_cash_item.dart';
import '../services/finance_planned_cash_items_service.dart';

class FinancePlannedCashItemFormScreen extends StatefulWidget {
  const FinancePlannedCashItemFormScreen({
    super.key,
    required this.companyData,
    this.item,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinancePlannedCashItem? item;
  final bool debugUnlockModule;

  bool get isEdit => item != null;

  @override
  State<FinancePlannedCashItemFormScreen> createState() =>
      _FinancePlannedCashItemFormScreenState();
}

class _FinancePlannedCashItemFormScreenState
    extends State<FinancePlannedCashItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FinancePlannedCashItemsService();
  final _accountsService = FinanceAccountsService();
  final _categoriesService = FinanceCashFlowCategoriesService();

  final _nominalCtrl = TextEditingController();
  final _probabilityCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'EUR');

  bool _loadingMasters = true;
  bool _saving = false;
  List<FinanceAccount> _accounts = const [];
  List<FinanceCashFlowCategory> _categories = const [];

  String? _categoryId;
  String? _accountId;
  String _direction = 'inflow';
  String _probabilitySource = 'manual_confirmed';
  DateTime? _expectedDate;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _categoryId = item.cashFlowCategoryId;
      _accountId = item.accountId;
      _direction = item.direction;
      _probabilitySource = item.probabilitySource;
      _nominalCtrl.text = item.nominalAmount.toStringAsFixed(2);
      _probabilityCtrl.text = item.probabilityPercent.toStringAsFixed(0);
      _descriptionCtrl.text = item.description;
      _currencyCtrl.text = item.currency;
      _expectedDate = item.expectedDate;
    } else {
      final now = DateTime.now();
      _expectedDate = DateTime(now.year, now.month, now.day);
      _probabilityCtrl.text = '80';
    }
    _loadMasters();
  }

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _probabilityCtrl.dispose();
    _descriptionCtrl.dispose();
    _currencyCtrl.dispose();
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

  double? _parseAmount(String raw) {
    final v = double.tryParse(raw.replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return v;
  }

  double? _parseProbability(String raw) {
    final v = double.tryParse(raw.replaceAll(',', '.'));
    if (v == null || v < 0 || v > 100) return null;
    return v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expectedDate == null || _categoryId == null) return;

    final nominal = _parseAmount(_nominalCtrl.text);
    final prob = _parseProbability(_probabilityCtrl.text);
    if (nominal == null || prob == null) return;

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _service.updateItem(
          companyId: _companyId,
          plannedCashItemId: widget.item!.id,
          direction: _direction,
          cashFlowCategoryId: _categoryId!,
          nominalAmount: nominal,
          currency: _currencyCtrl.text.trim().toUpperCase(),
          expectedDate: _expectedDate!,
          probabilityPercent: prob,
          probabilitySource: _probabilitySource,
          description: _descriptionCtrl.text.trim(),
          accountId: _accountId,
        );
      } else {
        await _service.createItem(
          companyId: _companyId,
          direction: _direction,
          cashFlowCategoryId: _categoryId!,
          nominalAmount: nominal,
          currency: _currencyCtrl.text.trim().toUpperCase(),
          expectedDate: _expectedDate!,
          probabilityPercent: prob,
          probabilitySource: _probabilitySource,
          description: _descriptionCtrl.text.trim(),
          accountId: _accountId,
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
    final item = widget.item;
    final canEdit = item == null ||
        (item.isDraft &&
            FinancePermissions.canEditPlannedCashItemDraft(
              companyData: widget.companyData,
              role: _role,
              itemCreatedBy: item.createdBy ?? '',
              debugUnlockModule: widget.debugUnlockModule,
            ));

    if (!canEdit) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: FinanceAssistantScreens.plannedItemForm,
          tabKey: FinanceAssistantTabs.cashFlow,
          tabLabelKey: 'help_cash_flow_tab_title',
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'planned_item_edit')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FinanceStrings.t(context, 'planned_readonly_hint')),
          ),
        ),
      );
    }

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.plannedItemForm,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
      ),
      appBar: AppBar(
        title: Text(
          FinanceStrings.t(
            context,
            widget.isEdit ? 'planned_item_edit' : 'planned_item_new',
          ),
        ),
      ),
      body: _loadingMasters
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    value: _direction,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'direction'),
                      border: const OutlineInputBorder(),
                    ),
                    items: FinanceDisplayLabels.transactionDirectionCodes.map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text(
                          FinanceDisplayLabels.transactionDirection(
                            context,
                            code,
                          ),
                        ),
                      ),
                    ).toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _direction = v ?? 'inflow'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'category'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.categoryCode} · ${c.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _categoryId = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? FinanceStrings.t(context, 'select_category') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nominalCtrl,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'nominal_amount'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: (v) =>
                        _parseAmount(v ?? '') == null ? FinanceStrings.t(context, 'allocation_amount_invalid') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _currencyCtrl,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'currency'),
                      border: const OutlineInputBorder(),
                    ),
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      final c = (v ?? '').trim();
                      if (c.length != 3) {
                        return FinanceStrings.t(context, 'error_generic');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  FinanceDatePickerField(
                    label: FinanceStrings.t(context, 'expected_date'),
                    value: _expectedDate,
                    onChanged: (d) => setState(() => _expectedDate = d),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _probabilityCtrl,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'probability_percent'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) =>
                        _parseProbability(v ?? '') == null ? FinanceStrings.t(context, 'error_generic') : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _probabilitySource,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'probability_source'),
                      border: const OutlineInputBorder(),
                    ),
                    items: FinanceDisplayLabels.probabilitySourceCodes.map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text(
                          FinanceDisplayLabels.probabilitySource(context, code),
                        ),
                      ),
                    ).toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _probabilitySource = v ?? 'manual_confirmed',
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'description'),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? FinanceStrings.t(context, 'error_generic') : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _accountId,
                    decoration: InputDecoration(
                      labelText: FinanceStrings.t(context, 'account'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(FinanceStrings.t(context, 'filter_all_accounts')),
                      ),
                      ..._accounts.map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.accountCode} · ${a.name}'),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _accountId = v),
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
