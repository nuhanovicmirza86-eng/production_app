import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../accounts/models/finance_account.dart';
import '../../accounts/services/finance_accounts_service.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_cash_transaction.dart';
import '../services/finance_cash_transactions_service.dart';
import 'finance_cash_transaction_detail_screen.dart';
import 'finance_cash_transaction_form_screen.dart';

class FinanceCashTransactionsScreen extends StatefulWidget {
  const FinanceCashTransactionsScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceCashTransactionsScreen> createState() =>
      _FinanceCashTransactionsScreenState();
}

class _FinanceCashTransactionsScreenState
    extends State<FinanceCashTransactionsScreen> {
  final _txService = FinanceCashTransactionsService();
  final _accountsService = FinanceAccountsService();

  bool _loading = true;
  String? _error;
  List<FinanceCashTransaction> _transactions = const [];
  List<FinanceAccount> _accounts = const [];

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _statusFilter;
  String? _accountFilter;
  String? _directionFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canCreate => FinancePermissions.canCreateCashTransactionDraft(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final accounts = await _accountsService.listAccounts(
        companyId: _companyId,
        activeOnly: false,
      );
      if (!mounted) return;
      setState(() => _accounts = accounts);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _txService.listTransactions(
        companyId: _companyId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        accountId: _accountFilter,
        status: _statusFilter,
        direction: _directionFilter,
      );
      if (!mounted) return;
      setState(() {
        _transactions = items;
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

  String _accountLabel(String accountId) {
    for (final a in _accounts) {
      if (a.id == accountId) {
        return '${a.accountCode} · ${a.name}';
      }
    }
    return accountId;
  }

  Future<void> _openForm() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceCashTransactionFormScreen(
          companyData: widget.companyData,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openDetail(FinanceCashTransaction tx) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceCashTransactionDetailScreen(
          companyData: widget.companyData,
          transaction: tx,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canAccessCashFlowOperative(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'transactions_title')),
        ),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'transactions_title')),
        actions: [
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: Text(FinanceStrings.t(context, 'transaction_new')),
            )
          : null,
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FinanceDatePickerField(
                  label: FinanceStrings.t(context, 'date_from'),
                  value: _dateFrom,
                  lastDate: _dateTo,
                  onChanged: (d) => setState(() => _dateFrom = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FinanceDatePickerField(
                  label: FinanceStrings.t(context, 'date_to'),
                  value: _dateTo,
                  firstDate: _dateFrom,
                  onChanged: (d) => setState(() => _dateTo = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'filter_status'),
              border: const OutlineInputBorder(),
            ),
            value: _statusFilter,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(FinanceStrings.t(context, 'filter_all')),
              ),
              ...FinanceDisplayLabels.transactionStatusCodes.map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: Text(
                    FinanceDisplayLabels.transactionStatus(context, code),
                  ),
                ),
              ),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'filter_account'),
              border: const OutlineInputBorder(),
            ),
            value: _accountFilter,
            items: [
              DropdownMenuItem(
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
            onChanged: _loading
                ? null
                : (v) => setState(() => _accountFilter = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'filter_direction'),
              border: const OutlineInputBorder(),
            ),
            value: _directionFilter,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(FinanceStrings.t(context, 'filter_all')),
              ),
              ...FinanceDisplayLabels.transactionDirectionCodes.map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: Text(
                    FinanceDisplayLabels.transactionDirection(context, code),
                  ),
                ),
              ),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() => _directionFilter = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.filter_alt_outlined),
            label: Text(FinanceStrings.t(context, 'refresh')),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: Text(FinanceStrings.t(context, 'refresh')),
              ),
            ],
          ),
        ),
      );
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Text(FinanceStrings.t(context, 'transactions_empty')),
      );
    }

    final dateFmt = DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _transactions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          final dateText = tx.transactionDate != null
              ? dateFmt.format(tx.transactionDate!)
              : '—';
          return ListTile(
            title: Text(
              tx.transactionCode.isNotEmpty
                  ? tx.transactionCode
                  : tx.id,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateText · ${_accountLabel(tx.accountId)}',
                ),
                Text(
                  FinanceDisplayLabels.transactionDirection(
                    context,
                    tx.direction,
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FinanceMoneyFormat.format(tx.amount, tx.currency),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Chip(
                  label: Text(
                    FinanceDisplayLabels.transactionStatus(context, tx.status),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            onTap: () => _openDetail(tx),
          );
        },
      ),
    );
  }
}
