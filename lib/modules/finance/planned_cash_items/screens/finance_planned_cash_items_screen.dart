import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_planned_cash_item.dart';
import '../services/finance_planned_cash_items_service.dart';
import 'finance_planned_cash_item_detail_screen.dart';
import 'finance_planned_cash_item_form_screen.dart';

class FinancePlannedCashItemsScreen extends StatefulWidget {
  const FinancePlannedCashItemsScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinancePlannedCashItemsScreen> createState() =>
      _FinancePlannedCashItemsScreenState();
}

class _FinancePlannedCashItemsScreenState
    extends State<FinancePlannedCashItemsScreen> {
  final _service = FinancePlannedCashItemsService();
  bool _loading = true;
  String? _error;
  List<FinancePlannedCashItem> _items = const [];
  String? _statusFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canCreate => FinancePermissions.canCreatePlannedCashItemDraft(
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
      final items = await _service.listItems(
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

  Future<void> _openForm({FinancePlannedCashItem? item}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinancePlannedCashItemFormScreen(
          companyData: widget.companyData,
          item: item,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openDetail(FinancePlannedCashItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinancePlannedCashItemDetailScreen(
          companyData: widget.companyData,
          item: item,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewPlannedCashFlow(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'planned_items_title')),
        ),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'planned_items_title')),
        actions: [
          if (_canCreate)
            IconButton(
              tooltip: FinanceStrings.t(context, 'planned_item_new'),
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
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
                ...FinanceDisplayLabels.plannedCashItemStatusCodes.map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(
                      FinanceDisplayLabels.plannedCashItemStatus(context, code),
                    ),
                  ),
                ),
              ],
              onChanged: _loading
                  ? null
                  : (v) {
                      setState(() => _statusFilter = v);
                      _load();
                    },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Text(
                      FinanceStrings.t(context, 'planned_items_empty'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openDetail(item),
                            title: Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${FinanceDisplayLabels.transactionDirection(context, item.direction)} · '
                              '${FinanceDisplayLabels.plannedCashItemStatus(context, item.status)} · '
                              '${_formatDate(item.expectedDate)}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  FinanceMoneyFormat.format(
                                    item.nominalAmount,
                                    item.currency,
                                  ),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  FinanceMoneyFormat.format(
                                    item.weightedAmount,
                                    item.currency,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
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
