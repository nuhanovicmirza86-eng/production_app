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
import '../models/finance_realized_cash_flow_summary.dart';
import '../services/finance_cash_transactions_service.dart';

class FinanceRealizedCashFlowScreen extends StatefulWidget {
  const FinanceRealizedCashFlowScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceRealizedCashFlowScreen> createState() =>
      _FinanceRealizedCashFlowScreenState();
}

class _FinanceRealizedCashFlowScreenState
    extends State<FinanceRealizedCashFlowScreen> {
  final _service = FinanceCashTransactionsService();
  final _accountsService = FinanceAccountsService();

  bool _loading = false;
  String? _error;
  FinanceRealizedCashFlowSummary? _summary;
  List<FinanceAccount> _accounts = const [];

  late DateTime _dateFrom;
  late DateTime _dateTo;
  String? _accountFilter;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountsService.listAccounts(
        companyId: _companyId,
        activeOnly: true,
      );
      if (!mounted) return;
      setState(() => _accounts = accounts);
    } catch (_) {
      // Filter računa je opcionalan.
    }
  }

  Future<void> _load() async {
    if (!FinancePermissions.canViewRealizedCashFlow(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _service.getRealizedSummary(
        companyId: _companyId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        accountId: _accountFilter,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
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

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .format(d);
  }

  Widget _metricCard(String label, double value, String? currency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              FinanceMoneyFormat.format(value, currency),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _activitySection(
    String title,
    FinanceActivityCashFlow activity,
    String? currency,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _row(
              FinanceStrings.t(context, 'realized_inflows'),
              FinanceMoneyFormat.format(activity.inflows, currency),
            ),
            _row(
              FinanceStrings.t(context, 'realized_outflows'),
              FinanceMoneyFormat.format(activity.outflows, currency),
            ),
            _row(
              FinanceStrings.t(context, 'realized_net'),
              FinanceMoneyFormat.format(activity.net, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewRealizedCashFlow(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(title: Text(FinanceStrings.t(context, 'realized_title'))),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    final currency = _summary?.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'realized_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assessment_outlined),
            label: Text(FinanceStrings.t(context, 'load_report')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_summary != null) ...[
            const SizedBox(height: 24),
            Text(
              '${FinanceStrings.t(context, 'realized_period')}: ${_formatDate(_summary!.dateFrom)} – ${_formatDate(_summary!.dateTo)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _metricCard(
              FinanceStrings.t(context, 'opening_balance'),
              _summary!.openingBalance,
              currency,
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'realized_total_inflows'),
              _summary!.totalInflows,
              currency,
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'realized_total_outflows'),
              _summary!.totalOutflows,
              currency,
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'realized_net_cash_flow'),
              _summary!.netCashFlow,
              currency,
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'realized_closing_balance'),
              _summary!.closingBalance,
              currency,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(FinanceStrings.t(context, 'realized_transaction_count')),
                trailing: Text('${_summary!.transactionCount}'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              FinanceStrings.t(context, 'realized_by_activity'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _activitySection(
              FinanceDisplayLabels.activityType(context, 'operating'),
              _summary!.operating,
              currency,
            ),
            const SizedBox(height: 8),
            _activitySection(
              FinanceDisplayLabels.activityType(context, 'investing'),
              _summary!.investing,
              currency,
            ),
            const SizedBox(height: 8),
            _activitySection(
              FinanceDisplayLabels.activityType(context, 'financing'),
              _summary!.financing,
              currency,
            ),
          ],
        ],
      ),
    );
  }
}
