import 'package:flutter/material.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../../invoices/models/finance_open_items_summary.dart';
import '../../invoices/models/finance_sales_invoice.dart';
import '../../invoices/services/finance_invoices_service.dart';
import '../../invoices/widgets/finance_invoice_widgets.dart';
import '../../invoices/screens/finance_sales_invoice_detail_screen.dart';

class FinanceReceivablesScreen extends StatefulWidget {
  const FinanceReceivablesScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceReceivablesScreen> createState() =>
      _FinanceReceivablesScreenState();
}

class _FinanceReceivablesScreenState extends State<FinanceReceivablesScreen> {
  final _service = FinanceInvoicesService();
  bool _loading = true;
  String? _error;
  FinanceOpenItemsSummary? _summary;
  List<FinanceSalesInvoice> _items = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

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
      final summary = await _service.getOpenReceivablesSummary(
        companyId: _companyId,
      );
      final items = await _service.listSalesInvoices(
        companyId: _companyId,
        openOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
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

  Future<void> _openDetail(FinanceSalesInvoice invoice) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceSalesInvoiceDetailScreen(
          companyData: widget.companyData,
          invoice: invoice,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewReceivables(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: FinanceAssistantScreens.receivablesList,
          tabKey: FinanceAssistantTabs.invoices,
          tabLabelKey: 'help_invoices_tab_title',
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'receivables_title')),
        ),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    final summary = _summary;
    final currencyHint = _items.isNotEmpty ? _items.first.currency : null;

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.receivablesList,
        tabKey: FinanceAssistantTabs.invoices,
        tabLabelKey: 'help_invoices_tab_title',
        actions: FinanceAssistantContextFactory.refreshOnly(),
      ),
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'receivables_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (summary != null)
                        FinanceInvoiceSummaryCard(
                          summary: summary,
                          currencyHint: currencyHint,
                        ),
                      const SizedBox(height: 16),
                      Text(
                        FinanceStrings.t(context, 'receivables_open_list'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        Text(FinanceStrings.t(context, 'receivables_empty'))
                      else
                        ..._items.map(
                          (inv) => Card(
                            child: ListTile(
                              title: Text(inv.invoiceNumber),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((inv.customerName ?? '').isNotEmpty)
                                    Text(inv.customerName!),
                                  Text(
                                    FinanceMoneyFormat.format(
                                      inv.openAmount,
                                      inv.currency,
                                    ),
                                  ),
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
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
