import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
import '../../shared/finance_scaffold.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_account.dart';
import '../services/finance_accounts_service.dart';
import 'finance_account_form_screen.dart';

class FinanceAccountsScreen extends StatefulWidget {
  const FinanceAccountsScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceAccountsScreen> createState() => _FinanceAccountsScreenState();
}

class _FinanceAccountsScreenState extends State<FinanceAccountsScreen> {
  final _service = FinanceAccountsService();
  bool _loading = true;
  String? _error;
  List<FinanceAccount> _accounts = const [];
  bool _activeOnly = false;
  String? _typeFilter;
  String? _currencyFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canManage => FinancePermissions.canManageCashFlowMasterData(
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
      final items = await _service.listAccounts(
        companyId: _companyId,
        activeOnly: _activeOnly,
      );
      if (!mounted) return;
      setState(() {
        _accounts = items;
        _loading = false;
        final codes = items
            .map((a) => a.currency)
            .where((c) => c.isNotEmpty)
            .toSet();
        if (_currencyFilter != null && !codes.contains(_currencyFilter)) {
          _currencyFilter = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FinanceErrorMapper.toMessage(e, context: context);
        _loading = false;
      });
    }
  }

  Future<void> _openForm({FinanceAccount? account}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FinanceAccountFormScreen(
          companyData: widget.companyData,
          account: account,
        ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deactivate(FinanceAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(FinanceStrings.t(ctx, 'deactivate_account')),
        content: Text(FinanceStrings.t(ctx, 'deactivate_account_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(FinanceStrings.t(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(FinanceStrings.t(ctx, 'deactivate_account')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.deactivateAccount(
        companyId: _companyId,
        accountId: account.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceStrings.t(context, 'deactivated'))),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FinanceErrorMapper.toMessage(e, context: context))),
      );
    }
  }

  String _formatMoney(FinanceAccount a) {
    final fmt = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    );
    return '${fmt.format(a.currentBalance)} ${a.currency}';
  }

  List<String> get _currencyOptions {
    final codes = <String>{};
    for (final a in _accounts) {
      if (a.currency.isNotEmpty) codes.add(a.currency);
    }
    final list = codes.toList()..sort();
    return list;
  }

  List<FinanceAccount> get _filteredAccounts {
    return _accounts.where((a) {
      if (_typeFilter != null &&
          a.accountType.trim().toLowerCase() != _typeFilter) {
        return false;
      }
      if (_currencyFilter != null && a.currency != _currencyFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _dropdownText(String text) {
    return Text(text, overflow: TextOverflow.ellipsis);
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(FinanceStrings.t(context, 'filter_active_only')),
            value: _activeOnly,
            onChanged: _loading
                ? null
                : (v) {
                    setState(() => _activeOnly = v);
                    _load();
                  },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            value: _typeFilter,
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'account_type'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: _dropdownText(FinanceStrings.t(context, 'filter_all')),
              ),
              ...FinanceDisplayLabels.accountTypeCodes.map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: _dropdownText(
                    FinanceDisplayLabels.accountType(context, code),
                  ),
                ),
              ),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() => _typeFilter = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            value: _currencyFilter,
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'currency'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: _dropdownText(FinanceStrings.t(context, 'filter_all')),
              ),
              ..._currencyOptions.map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: _dropdownText(code),
                ),
              ),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() => _currencyFilter = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canAccessCashFlowOperative(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return FinanceScaffold(
        assistantContext: FinanceAssistantContextFactory.fromCompany(
          context: context,
          companyData: widget.companyData,
          screenKey: FinanceAssistantScreens.accountsList,
          tabKey: FinanceAssistantTabs.cashFlow,
          tabLabelKey: 'help_cash_flow_tab_title',
        ),
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'accounts_title')),
        ),
        body: Center(
          child: Text(FinanceStrings.t(context, 'access_denied')),
        ),
      );
    }

    return FinanceScaffold(
      assistantContext: FinanceAssistantContextFactory.fromCompany(
        context: context,
        companyData: widget.companyData,
        screenKey: FinanceAssistantScreens.accountsList,
        tabKey: FinanceAssistantTabs.cashFlow,
        tabLabelKey: 'help_cash_flow_tab_title',
        actions: FinanceAssistantContextFactory.createAndRefresh(
          createKey: 'account_new',
          canCreate: _canManage,
        ),
      ),
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'accounts_title')),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: FinanceStrings.t(context, 'account_new'),
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final visible = _filteredAccounts;
    if (visible.isEmpty) {
      return Center(
        child: Text(FinanceStrings.t(context, 'accounts_empty')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final a = visible[index];
          return ListTile(
            title: Text(a.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.accountCode} · ${FinanceDisplayLabels.accountType(context, a.accountType)}'),
                const SizedBox(height: 4),
                Text(
                  '${FinanceStrings.t(context, 'current_balance')}: ${_formatMoney(a)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    a.active
                        ? FinanceStrings.t(context, 'active')
                        : FinanceStrings.t(context, 'inactive'),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (_canManage && a.active)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        _openForm(account: a);
                      } else if (v == 'deactivate') {
                        _deactivate(a);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(FinanceStrings.t(ctx, 'account_edit')),
                      ),
                      PopupMenuItem(
                        value: 'deactivate',
                        child: Text(FinanceStrings.t(ctx, 'deactivate_account')),
                      ),
                    ],
                  ),
              ],
            ),
            onTap: _canManage && a.active ? () => _openForm(account: a) : null,
          );
        },
      ),
    );
  }
}
