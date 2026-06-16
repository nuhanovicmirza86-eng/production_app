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
import '../models/finance_cash_flow_forecast.dart';
import '../services/finance_cash_flow_forecast_service.dart';

class FinanceCashFlowForecastScreen extends StatefulWidget {
  const FinanceCashFlowForecastScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceCashFlowForecastScreen> createState() =>
      _FinanceCashFlowForecastScreenState();
}

class _FinanceCashFlowForecastScreenState
    extends State<FinanceCashFlowForecastScreen> {
  final _service = FinanceCashFlowForecastService();
  final _accountsService = FinanceAccountsService();

  static const _horizonPresets = [7, 30, 60, 90, 180, 365];

  bool _loading = false;
  String? _error;
  FinanceCashFlowForecast? _forecast;
  List<FinanceAccount> _accounts = const [];

  bool _useCustomPeriod = false;
  int _horizonDays = 30;
  String _bucketType = 'day';
  String? _accountFilter;

  late DateTime _periodFrom;
  late DateTime _periodTo;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodFrom = DateTime(now.year, now.month, now.day);
    _periodTo = _periodFrom.add(const Duration(days: 29));
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
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!FinancePermissions.canViewPlannedCashFlow(
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
      final forecast = await _service.getForecast(
        companyId: _companyId,
        bucketType: _bucketType,
        horizonDays: _useCustomPeriod ? null : _horizonDays,
        periodFrom: _useCustomPeriod ? _periodFrom : null,
        periodTo: _useCustomPeriod ? _periodTo : null,
        accountIds: _accountFilter != null ? [_accountFilter!] : null,
      );
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
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

  String _yesNo(bool v) {
    return FinanceStrings.t(context, v ? 'forecast_yes' : 'forecast_no');
  }

  Widget _metricCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _bucketCard(FinanceCashFlowForecastBucket bucket, String currency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatDate(bucket.periodStart)} – ${_formatDate(bucket.periodEnd)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 24),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_opening_balance'),
              FinanceMoneyFormat.format(bucket.openingBalance, currency),
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_actual_inflows'),
              FinanceMoneyFormat.format(bucket.actualInflows, currency),
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_actual_outflows'),
              FinanceMoneyFormat.format(bucket.actualOutflows, currency),
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_planned_nominal_inflows'),
              FinanceMoneyFormat.format(bucket.plannedNominalInflows, currency),
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_planned_nominal_outflows'),
              FinanceMoneyFormat.format(bucket.plannedNominalOutflows, currency),
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_planned_weighted_inflows'),
              FinanceMoneyFormat.format(bucket.plannedWeightedInflows, currency),
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_planned_weighted_outflows'),
              FinanceMoneyFormat.format(bucket.plannedWeightedOutflows, currency),
            ),
            const Divider(height: 16),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_nominal_closing'),
              FinanceMoneyFormat.format(bucket.nominalClosingBalance, currency),
              bold: true,
            ),
            _bucketRow(
              FinanceStrings.t(context, 'forecast_weighted_closing'),
              FinanceMoneyFormat.format(bucket.weightedClosingBalance, currency),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bucketRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: bold ? Theme.of(context).textTheme.titleSmall : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewPlannedCashFlow(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(title: Text(FinanceStrings.t(context, 'forecast_title'))),
        body: Center(child: Text(FinanceStrings.t(context, 'access_denied'))),
      );
    }

    final currency = _forecast?.baseCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(FinanceStrings.t(context, 'forecast_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(FinanceStrings.t(context, 'forecast_use_horizon')),
              ),
              ButtonSegment(
                value: true,
                label: Text(FinanceStrings.t(context, 'forecast_use_custom')),
              ),
            ],
            selected: {_useCustomPeriod},
            onSelectionChanged: _loading
                ? null
                : (s) => setState(() => _useCustomPeriod = s.first),
          ),
          const SizedBox(height: 12),
          if (!_useCustomPeriod)
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _horizonDays,
              decoration: InputDecoration(
                labelText: FinanceStrings.t(context, 'forecast_horizon'),
                border: const OutlineInputBorder(),
              ),
              items: _horizonPresets
                  .map(
                    (d) => DropdownMenuItem(value: d, child: Text('$d')),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _horizonDays = v ?? 30),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FinanceDatePickerField(
                    label: FinanceStrings.t(context, 'date_from'),
                    value: _periodFrom,
                    lastDate: _periodTo,
                    onChanged: (d) => setState(() => _periodFrom = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FinanceDatePickerField(
                    label: FinanceStrings.t(context, 'date_to'),
                    value: _periodTo,
                    firstDate: _periodFrom,
                    onChanged: (d) => setState(() => _periodTo = d),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _bucketType,
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'forecast_bucket_type'),
              border: const OutlineInputBorder(),
            ),
            items: FinanceDisplayLabels.forecastBucketTypeCodes.map(
              (code) => DropdownMenuItem(
                value: code,
                child: Text(
                  FinanceDisplayLabels.forecastBucketType(context, code),
                ),
              ),
            ).toList(),
            onChanged: _loading
                ? null
                : (v) => setState(() => _bucketType = v ?? 'day'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            decoration: InputDecoration(
              labelText: FinanceStrings.t(context, 'filter_account'),
              border: const OutlineInputBorder(),
            ),
            value: _accountFilter,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  FinanceStrings.t(context, 'filter_all_accounts'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._accounts.map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.accountCode} · ${a.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
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
                : const Icon(Icons.insights_outlined),
            label: Text(FinanceStrings.t(context, 'forecast_load')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_forecast != null) ...[
            const SizedBox(height: 24),
            Text(
              '${FinanceStrings.t(context, 'forecast_period_label')}: '
              '${_formatDate(_forecast!.periodFrom)} – ${_formatDate(_forecast!.periodTo)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _metricCard(
              FinanceStrings.t(context, 'forecast_opening_balance'),
              FinanceMoneyFormat.format(_forecast!.openingBalance, currency),
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_minimum_cash_reserve'),
              FinanceMoneyFormat.format(_forecast!.minimumCashReserve, currency),
            ),
            const SizedBox(height: 16),
            _metricCard(
              FinanceStrings.t(context, 'forecast_first_below_reserve_nominal'),
              _forecast!.liquidityThreshold.firstNominalBelowReserveDate ?? '—',
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_first_below_reserve_weighted'),
              _forecast!.liquidityThreshold.firstWeightedBelowReserveDate ?? '—',
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_min_nominal_balance'),
              FinanceMoneyFormat.format(
                _forecast!.liquidityThreshold.minimumNominalBalance ?? 0,
                currency,
              ),
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_min_nominal_balance_date'),
              _forecast!.liquidityThreshold.minimumNominalBalanceDate ?? '—',
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_min_weighted_balance'),
              FinanceMoneyFormat.format(
                _forecast!.liquidityThreshold.minimumWeightedBalance ?? 0,
                currency,
              ),
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_min_weighted_balance_date'),
              _forecast!.liquidityThreshold.minimumWeightedBalanceDate ?? '—',
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_negative_nominal_expected'),
              _yesNo(_forecast!.liquidityThreshold.nominalNegativeBalanceExpected),
            ),
            const SizedBox(height: 8),
            _metricCard(
              FinanceStrings.t(context, 'forecast_negative_weighted_expected'),
              _yesNo(_forecast!.liquidityThreshold.weightedNegativeBalanceExpected),
            ),
            const SizedBox(height: 24),
            if (_forecast!.buckets.isEmpty)
              Text(FinanceStrings.t(context, 'forecast_buckets_empty'))
            else
              ..._forecast!.buckets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _bucketCard(b, currency ?? ''),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
