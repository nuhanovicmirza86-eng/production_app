import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_load_error_presenter.dart';
import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../accounts/models/finance_account.dart';
import '../../accounts/services/finance_accounts_service.dart';
import '../../shared/finance_date_picker_field.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_labeled_filter_field.dart';
import '../../shared/finance_money_format.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_statement_transaction.dart';
import '../services/finance_bank_reconciliation_service.dart';
import '../widgets/finance_bank_import_dialog.dart';
import 'finance_bank_statement_detail_screen.dart';

class FinanceBankStatementsScreen extends StatefulWidget {
  const FinanceBankStatementsScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceBankStatementsScreen> createState() =>
      _FinanceBankStatementsScreenState();
}

class _FinanceBankStatementsScreenState extends State<FinanceBankStatementsScreen> {
  final _service = FinanceBankReconciliationService();
  final _accountsService = FinanceAccountsService();

  bool _loading = true;
  bool _filtersExpanded = true;
  String? _error;
  List<FinanceBankStatementTransaction> _allItems = const [];
  List<FinanceAccount> _accounts = const [];

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _statusFilter;
  String? _accountFilter;
  String? _directionFilter;
  String? _currencyFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canView => FinancePermissions.canViewBankReconciliation(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  bool get _canImport => FinancePermissions.canImportBankStatements(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  List<FinanceBankStatementTransaction> get _filteredItems {
    return _allItems.where((item) {
      if (_statusFilter != null &&
          _statusFilter!.isNotEmpty &&
          item.status.toLowerCase() != _statusFilter!.toLowerCase()) {
        return false;
      }
      if (_accountFilter != null &&
          _accountFilter!.isNotEmpty &&
          item.bankAccountId != _accountFilter) {
        return false;
      }
      if (_directionFilter != null &&
          _directionFilter!.isNotEmpty &&
          item.direction != _directionFilter!.toLowerCase()) {
        return false;
      }
      if (_currencyFilter != null &&
          _currencyFilter!.isNotEmpty &&
          item.currency != _currencyFilter!.toUpperCase()) {
        return false;
      }
      final booking = item.bookingDate;
      if (booking != null) {
        final day = DateTime(booking.year, booking.month, booking.day);
        final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
        final to = DateTime(_dateTo.year, _dateTo.month, _dateTo.day);
        if (day.isBefore(from) || day.isAfter(to)) return false;
      }
      return true;
    }).toList();
  }

  Set<String> get _currencyOptions {
    final codes = <String>{};
    for (final item in _allItems) {
      final c = item.currency.trim();
      if (c.isNotEmpty) codes.add(c.toUpperCase());
    }
    for (final account in _accounts) {
      final c = account.currency.trim();
      if (c.isNotEmpty) codes.add(c.toUpperCase());
    }
    return codes;
  }

  List<String> get _sortedCurrencyOptions {
    final list = _currencyOptions.toList()..sort();
    return list;
  }

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
      if (_companyId.isNotEmpty) {
        final accounts = await _accountsService.listAccounts(
          companyId: _companyId,
          activeOnly: false,
        );
        if (mounted) setState(() => _accounts = accounts);
      }
    } catch (_) {
      // Računi su opcionalni za filter; lista stavki može raditi bez njih.
    }
    await _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = FinanceStrings.t(context, 'error_missing_company');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listBankTransactions(
        companyId: _companyId,
        bankAccountId: _accountFilter,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _loading = false;
        _filtersExpanded = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  String _formatDateRequired(DateTime d) => _formatDate(d);

  String _accountLabel(String? accountId) {
    if (accountId == null || accountId.isEmpty) return '—';
    for (final a in _accounts) {
      if (a.id == accountId) return '${a.accountCode} · ${a.name}';
    }
    return accountId;
  }

  Widget _dropdownText(String text) {
    return Text(text, overflow: TextOverflow.ellipsis, maxLines: 1);
  }

  String _filterLabel(String? code, String Function(String) labelFor) {
    if (code == null || code.isEmpty) {
      return FinanceStrings.t(context, 'filter_all');
    }
    return labelFor(code);
  }

  String _filtersSubtitle() {
    final period = '${_formatDateRequired(_dateFrom)} – ${_formatDateRequired(_dateTo)}';
    final status = _filterLabel(
      _statusFilter,
      (code) => FinanceDisplayLabels.bankStatementStatus(context, code),
    );
    final account = _accountFilter == null
        ? FinanceStrings.t(context, 'filter_all_accounts')
        : _accountLabel(_accountFilter);
    final direction = _filterLabel(
      _directionFilter,
      (code) => FinanceDisplayLabels.transactionDirection(context, code),
    );
    return '$period · $status · $account · $direction';
  }

  Future<void> _openImport() async {
    final successMessage = await showFinanceBankImportDialog(
      context: context,
      companyId: _companyId,
      service: _service,
    );
    if (!mounted) return;
    if (successMessage != null && successMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    }
  }

  void _openDetail(FinanceBankStatementTransaction item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinanceBankStatementDetailScreen(
          companyData: widget.companyData,
          debugUnlockModule: widget.debugUnlockModule,
          transactionId: item.id,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContext(
          companyId: _companyId,
          screenKey: FinanceAssistantScreens.bankStatementsList,
          tabKey: FinanceAssistantTabs.cashFlow,
          tabLabelKey: 'help_cash_flow_tab_title',
          role: _role,
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'bank_statements_title')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              FinanceStrings.t(context, 'access_denied'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final items = _filteredItems;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FinanceScaffold(
      assistantContext: FinanceAssistantContext(
        companyId: _companyId,
        screenKey: FinanceAssistantScreens.bankStatementsList,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
        role: _role,
        availableActions: [
          if (_canImport) FinanceStrings.t(context, 'bank_import'),
          FinanceStrings.t(context, 'refresh'),
        ],
        disabledActions: [
          if (!_canImport) FinanceStrings.t(context, 'bank_import'),
        ],
      ),
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'bank_statements_title')),
        actions: [
          PopupMenuButton<_BankMenuAction>(
            tooltip: FinanceStrings.t(context, 'more_actions'),
            onSelected: (action) {
              switch (action) {
                case _BankMenuAction.import:
                  _openImport();
                case _BankMenuAction.refresh:
                  if (!_loading) _load();
              }
            },
            itemBuilder: (context) => [
              if (_canImport)
                PopupMenuItem(
                  value: _BankMenuAction.import,
                  child: ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: Text(FinanceStrings.t(context, 'bank_import')),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              PopupMenuItem(
                value: _BankMenuAction.refresh,
                enabled: !_loading,
                child: ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(FinanceStrings.t(context, 'refresh')),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 0,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
            child: ExpansionTile(
              key: ValueKey<bool>(_filtersExpanded),
              maintainState: true,
              initiallyExpanded: _filtersExpanded,
              onExpansionChanged: (v) => setState(() => _filtersExpanded = v),
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: Icon(
                Icons.tune_outlined,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
              title: Text(
                FinanceStrings.t(context, 'filter_period'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _filtersSubtitle(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                FinanceLabeledFilterField(
                  label: FinanceStrings.t(context, 'filter_account'),
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _accountFilter,
                    decoration: financeFilterInputDecoration(),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: _dropdownText(
                          FinanceStrings.t(context, 'filter_all_accounts'),
                        ),
                      ),
                      ..._accounts.map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: _dropdownText('${a.accountCode} · ${a.name}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _accountFilter = v),
                  ),
                ),
                const SizedBox(height: 12),
                FinanceLabeledFilterField(
                  label: FinanceStrings.t(context, 'filter_status'),
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _statusFilter,
                    decoration: financeFilterInputDecoration(),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: _dropdownText(
                          FinanceStrings.t(context, 'filter_all'),
                        ),
                      ),
                      ...FinanceDisplayLabels.bankStatementStatusCodes.map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: _dropdownText(
                            FinanceDisplayLabels.bankStatementStatus(
                              context,
                              code,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FinanceLabeledFilterField(
                        label: FinanceStrings.t(context, 'filter_direction'),
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: _directionFilter,
                          decoration: financeFilterInputDecoration(),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: _dropdownText(
                                FinanceStrings.t(context, 'filter_all'),
                              ),
                            ),
                            ...FinanceDisplayLabels.transactionDirectionCodes
                                .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: _dropdownText(
                                  FinanceDisplayLabels.transactionDirection(
                                    context,
                                    code,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _directionFilter = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FinanceLabeledFilterField(
                        label: FinanceStrings.t(context, 'filter_currency'),
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: _currencyFilter,
                          decoration: financeFilterInputDecoration(),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: _dropdownText(
                                FinanceStrings.t(context, 'filter_all'),
                              ),
                            ),
                            for (final c in _sortedCurrencyOptions)
                              DropdownMenuItem(
                                value: c,
                                child: _dropdownText(c),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _currencyFilter = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _loading ? null : _load,
                    child: Text(FinanceStrings.t(context, 'refresh')),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              FinanceStrings.t(context, 'retry'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : items.isEmpty
                ? Center(
                    child: Text(
                      FinanceStrings.t(context, 'bank_statements_empty'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          onTap: () => _openDetail(item),
                          title: Text(
                            FinanceMoneyFormat.format(
                              item.amount,
                              item.currency,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatDate(item.bookingDate)} · '
                            '${FinanceDisplayLabels.transactionDirection(context, item.direction)} · '
                            '${FinanceDisplayLabels.bankStatementStatus(context, item.status)}\n'
                            '${item.counterpartyName ?? item.rawDescription ?? '—'} · '
                            '${_accountLabel(item.bankAccountId)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

enum _BankMenuAction { import, refresh }
