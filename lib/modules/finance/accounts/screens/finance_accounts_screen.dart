import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../finance_integrations/utils/finance_permissions.dart';
import '../../shared/finance_display_labels.dart';
import '../../shared/finance_error_mapper.dart';
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
      final items = await _service.listAccounts(companyId: _companyId);
      if (!mounted) return;
      setState(() {
        _accounts = items;
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

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canAccessCashFlowOperative(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(
          title: Text(FinanceStrings.t(context, 'accounts_title')),
        ),
        body: Center(
          child: Text(FinanceStrings.t(context, 'access_denied')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'accounts_title')),
        actions: [
          IconButton(
            tooltip: FinanceStrings.t(context, 'refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(FinanceStrings.t(context, 'account_new')),
            )
          : null,
      body: _buildBody(),
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
    if (_accounts.isEmpty) {
      return Center(
        child: Text(FinanceStrings.t(context, 'accounts_empty')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _accounts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final a = _accounts[index];
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
