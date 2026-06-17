import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_purchase_invoice.dart';
import '../services/finance_invoices_service.dart';

class FinancePurchaseInvoiceFormScreen extends StatefulWidget {
  const FinancePurchaseInvoiceFormScreen({
    super.key,
    required this.companyData,
    this.invoice,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final FinancePurchaseInvoice? invoice;
  final bool debugUnlockModule;

  bool get isEdit => invoice != null;

  @override
  State<FinancePurchaseInvoiceFormScreen> createState() =>
      _FinancePurchaseInvoiceFormScreenState();
}

class _FinancePurchaseInvoiceFormScreenState
    extends State<FinancePurchaseInvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FinanceInvoicesService();

  final _supplierIdCtrl = TextEditingController();
  final _supplierNameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'BAM');
  final _netCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();

  bool _saving = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canSave {
    if (widget.isEdit) {
      return FinancePermissions.canEditFinanceInvoiceDraft(
        companyData: widget.companyData,
        role: _role,
        invoiceCreatedBy: widget.invoice!.createdBy ?? '',
        debugUnlockModule: widget.debugUnlockModule,
      );
    }
    return FinancePermissions.canCreateFinanceInvoiceDraft(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    );
  }

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    if (inv != null) {
      _supplierIdCtrl.text = inv.supplierId ?? '';
      _supplierNameCtrl.text = inv.supplierName ?? '';
      _currencyCtrl.text = inv.currency;
      if (inv.netAmount != null) {
        _netCtrl.text = inv.netAmount!.toStringAsFixed(2);
      }
      if (inv.taxAmount != null) {
        _taxCtrl.text = inv.taxAmount!.toStringAsFixed(2);
      }
      _descriptionCtrl.text = inv.description ?? '';
      _referenceCtrl.text = inv.reference ?? '';
    }
  }

  @override
  void dispose() {
    _supplierIdCtrl.dispose();
    _supplierNameCtrl.dispose();
    _currencyCtrl.dispose();
    _netCtrl.dispose();
    _taxCtrl.dispose();
    _descriptionCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final v = double.tryParse(raw.replaceAll(',', '.'));
    if (v == null || v < 0) return null;
    return v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_canSave) return;

    final net = _parseAmount(_netCtrl.text);
    final tax = _parseAmount(_taxCtrl.text);
    if (net == null && tax == null) return;

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _service.updatePurchaseDraft(
          companyId: _companyId,
          invoiceId: widget.invoice!.id,
          supplierId: _supplierIdCtrl.text.trim(),
          supplierName: _supplierNameCtrl.text.trim(),
          currency: _currencyCtrl.text.trim(),
          netAmount: net ?? 0,
          taxAmount: tax ?? 0,
          description: _descriptionCtrl.text.trim(),
          reference: _referenceCtrl.text.trim(),
        );
      } else {
        await _service.createPurchaseDraft(
          companyId: _companyId,
          supplierId: _supplierIdCtrl.text.trim(),
          supplierName: _supplierNameCtrl.text.trim(),
          currency: _currencyCtrl.text.trim(),
          netAmount: net ?? 0,
          taxAmount: tax ?? 0,
          description: _descriptionCtrl.text.trim(),
          reference: _referenceCtrl.text.trim(),
        );
      }
      if (!mounted) return;
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
    final inv = widget.invoice;
    final erpLocked = inv?.isErpSynced == true;

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.purchaseInvoiceForm,
        tabKey: FinanceAssistantTabs.invoices,
        tabLabelKey: 'help_invoices_tab_title',
      ),
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? FinanceStrings.t(context, 'purchase_invoice_edit')
              : FinanceStrings.t(context, 'purchase_invoice_new'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (erpLocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  FinanceStrings.t(context, 'invoice_erp_readonly_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextFormField(
              controller: _supplierIdCtrl,
              readOnly: erpLocked,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'supplier_id'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierNameCtrl,
              readOnly: erpLocked,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'supplier_name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyCtrl,
              readOnly: erpLocked,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'currency'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? ' ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _netCtrl,
              readOnly: erpLocked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'net_amount'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _taxCtrl,
              readOnly: erpLocked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'tax_amount'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              readOnly: erpLocked,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'description'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceCtrl,
              readOnly: erpLocked,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'reference'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_canSave && !erpLocked)
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
