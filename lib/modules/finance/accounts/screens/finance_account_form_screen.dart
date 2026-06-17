import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_account.dart';
import '../services/finance_accounts_service.dart';

class FinanceAccountFormScreen extends StatefulWidget {
  const FinanceAccountFormScreen({
    super.key,
    required this.companyData,
    this.account,
  });

  final Map<String, dynamic> companyData;
  final FinanceAccount? account;

  bool get isEdit => account != null;

  @override
  State<FinanceAccountFormScreen> createState() =>
      _FinanceAccountFormScreenState();
}

class _FinanceAccountFormScreenState extends State<FinanceAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FinanceAccountsService();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _openingCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _plantCtrl;

  String _accountType = 'transactional';
  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _codeCtrl = TextEditingController(text: a?.accountCode ?? '');
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _currencyCtrl = TextEditingController(text: a?.currency ?? 'BAM');
    _openingCtrl = TextEditingController(
      text: a != null ? a.openingBalance.toString() : '0',
    );
    _bankCtrl = TextEditingController(text: a?.bankName ?? '');
    _ibanCtrl = TextEditingController(text: a?.iban ?? '');
    _plantCtrl = TextEditingController(text: a?.plantKey ?? '');
    if (a != null && a.accountType.isNotEmpty) {
      _accountType = a.accountType;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _openingCtrl.dispose();
    _bankCtrl.dispose();
    _ibanCtrl.dispose();
    _plantCtrl.dispose();
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

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _service.updateAccount(
          companyId: _companyId,
          accountId: widget.account!.id,
          name: _nameCtrl.text,
          bankName: _bankCtrl.text,
          iban: _ibanCtrl.text,
          plantKey: _plantCtrl.text,
        );
      } else {
        final opening = double.tryParse(
              _openingCtrl.text.replaceAll(',', '.').trim(),
            ) ??
            0;
        await _service.createAccount(
          companyId: _companyId,
          accountCode: _codeCtrl.text,
          name: _nameCtrl.text,
          accountType: _accountType,
          currency: _currencyCtrl.text,
          openingBalance: opening,
          bankName: _bankCtrl.text,
          iban: _ibanCtrl.text,
          plantKey: _plantCtrl.text,
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
        ? FinanceStrings.t(context, 'account_edit')
        : FinanceStrings.t(context, 'account_new');

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.accountForm,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
      ),
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.isEdit && widget.account != null)
              ListTile(
                title: Text(FinanceStrings.t(context, 'current_balance')),
                subtitle: Text(
                  '${widget.account!.currentBalance} ${widget.account!.currency}',
                ),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            TextFormField(
              controller: _codeCtrl,
              enabled: !widget.isEdit,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'account_code'),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? FinanceStrings.t(context, 'account_code') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'account_name'),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? FinanceStrings.t(context, 'account_name') : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _accountType,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'account_type'),
              ),
              items: FinanceDisplayLabels.accountTypeCodes
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(FinanceDisplayLabels.accountType(context, code)),
                    ),
                  )
                  .toList(),
              onChanged: widget.isEdit
                  ? null
                  : (v) {
                      if (v != null) setState(() => _accountType = v);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyCtrl,
              enabled: !widget.isEdit,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'currency'),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length < 3) {
                  return FinanceStrings.t(context, 'currency');
                }
                return null;
              },
            ),
            if (!widget.isEdit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _openingCtrl,
                decoration: InputDecoration(
                  labelText: FinanceStrings.t(context, 'opening_balance'),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'bank_name'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ibanCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'iban'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plantCtrl,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'plant_key'),
              ),
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
