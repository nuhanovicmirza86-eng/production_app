import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_sales_invoice.dart';
import '../services/finance_invoices_service.dart';
import '../widgets/finance_invoice_widgets.dart';
import 'finance_sales_invoice_detail_screen.dart';
import 'finance_sales_invoice_form_screen.dart';

class FinanceSalesInvoicesScreen extends StatefulWidget {
  const FinanceSalesInvoicesScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceSalesInvoicesScreen> createState() =>
      _FinanceSalesInvoicesScreenState();
}

class _FinanceSalesInvoicesScreenState extends State<FinanceSalesInvoicesScreen> {
  final _service = FinanceInvoicesService();
  bool _loading = true;
  String? _error;
  List<FinanceSalesInvoice> _items = const [];
  String? _statusFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canCreate => FinancePermissions.canCreateFinanceInvoiceDraft(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listSalesInvoices(
        companyId: _companyId,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  Future<void> _openForm({FinanceSalesInvoice? invoice}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceSalesInvoiceFormScreen(
          companyData: widget.companyData,
          invoice: invoice,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openDetail(FinanceSalesInvoice invoice) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceSalesInvoiceDetailScreen(
          companyData: widget.companyData,
          invoice: invoice,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewFinanceInvoices(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'sales_invoices_title')),
        ),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'sales_invoices_title')),
        actions: [
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String?>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'filter_status'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(FinanceStrings.t(context, 'filter_all')),
                ),
                ...FinanceDisplayLabels.invoiceStatusCodes.map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(FinanceDisplayLabels.invoiceStatus(context, code)),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              FinanceStrings.t(context, 'sales_invoices_empty'),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final inv = _items[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(inv.invoiceNumber),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((inv.customerName ?? '').isNotEmpty)
                                          Text(inv.customerName!),
                                        Text(
                                          FinanceMoneyFormat.format(
                                            inv.openAmount,
                                            inv.currency,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FinanceInvoiceStatusChip(
                                          status: inv.status,
                                          isOverdue: inv.isOverdue,
                                          isErpSynced: inv.isErpSynced,
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    onTap: () => _openDetail(inv),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
