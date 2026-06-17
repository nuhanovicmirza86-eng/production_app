import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_flow_category.dart';
import '../services/finance_cash_flow_categories_service.dart';

class FinanceCashFlowCategoryFormScreen extends StatefulWidget {
  const FinanceCashFlowCategoryFormScreen({
    super.key,
    required this.companyData,
    this.category,
  });

  final Map<String, dynamic> companyData;
  final FinanceCashFlowCategory? category;

  bool get isEdit => category != null;

  @override
  State<FinanceCashFlowCategoryFormScreen> createState() =>
      _FinanceCashFlowCategoryFormScreenState();
}

class _FinanceCashFlowCategoryFormScreenState
    extends State<FinanceCashFlowCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FinanceCashFlowCategoriesService();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sortCtrl;

  String _activityType = 'operating';
  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _codeCtrl = TextEditingController(text: c?.categoryCode ?? '');
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _sortCtrl = TextEditingController(text: '${c?.sortOrder ?? 0}');
    if (c != null && c.cashFlowActivityType.isNotEmpty) {
      _activityType = c.cashFlowActivityType;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!FinancePermissions.canManageCashFlowMasterData(
      companyData: widget.companyData,
      role: _role,
    )) {
      return;
    }

    final sortOrder = int.tryParse(_sortCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _service.updateCategory(
          companyId: _companyId,
          categoryId: widget.category!.id,
          name: _nameCtrl.text,
          cashFlowActivityType: _activityType,
          sortOrder: sortOrder,
        );
      } else {
        await _service.createCategory(
          companyId: _companyId,
          categoryCode: _codeCtrl.text,
          name: _nameCtrl.text,
          cashFlowActivityType: _activityType,
          sortOrder: sortOrder,
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
        ? FinanceStrings.t(context, 'category_edit')
        : FinanceStrings.t(context, 'category_new');

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.categoryForm,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
      ),
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _codeCtrl,
              enabled: !widget.isEdit,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'category_code'),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? FinanceStrings.t(context, 'category_code')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'category_name'),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? FinanceStrings.t(context, 'category_name')
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _activityType,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'activity_type'),
              ),
              items: FinanceDisplayLabels.activityTypeCodes
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(
                        FinanceDisplayLabels.activityType(context, code),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _activityType = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sortCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'sort_order'),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
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
