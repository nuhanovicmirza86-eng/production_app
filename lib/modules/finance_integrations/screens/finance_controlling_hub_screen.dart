import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../../core/company_plant_display_name.dart';
import '../../../core/operational_business_year_context.dart';
import '../models/finance_budget_doc.dart';
import '../models/finance_controlling_defaults_view.dart';
import '../services/company_financial_years_service.dart';
import '../services/finance_budgets_service.dart';
import '../services/finance_exchange_rate_service.dart';
import '../utils/finance_currency_display.dart';
import '../utils/finance_permissions.dart';
import '../widgets/finance_erp_hub_tab_body.dart';
import '../widgets/finance_screen_context_info.dart';
import 'finance_ai_assistant_screen.dart';
import 'finance_controlling_dashboard_tab.dart';
import 'finance_controlling_operative_tab_widgets.dart';

/// Hub **Finance & Controlling**: obavezni filter poslovne godine + modulski tabovi i ERP sloj.
class FinanceControllingHubScreen extends StatefulWidget {
  const FinanceControllingHubScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceControllingHubScreen> createState() =>
      _FinanceControllingHubScreenState();
}

class _FinanceControllingHubScreenState extends State<FinanceControllingHubScreen>
    with SingleTickerProviderStateMixin {
  final _yearsSvc = CompanyFinancialYearsService();
  late TabController _tabController;
  bool _showControlling = false;

  String _businessYearId = '';
  int _periodYear = 0;
  int _periodMonth = 1;
  bool _didAutoSelectFy = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _showControlling = FinancePermissions.canViewControllingAnalytics(
      companyData: widget.companyData,
      role: _role,
      debugUnlockModule: widget.debugUnlockModule,
    );
    _tabController = TabController(
      length: _showControlling ? 8 : 1,
      vsync: this,
    );
    final now = DateTime.now();
    _periodYear = now.year;
    _periodMonth = now.month;
    _bootstrapPeriod();
  }

  Future<void> _bootstrapPeriod() async {
    final id = await OperationalBusinessYearContext.resolveFinancialYearIdForCompany(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() => _businessYearId = id.trim());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_showControlling) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Financije · ERP integracije'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            Card(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Aktivna je pretplata na ERP sloj. Potpuni financijski '
                        'controlling zahtijeva modul financijskog nadzora na razini kompanije.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    FinanceScreenContextInfo(
                      title: 'Zašto vidim samo ERP',
                      body:
                          'Potpuni prikaz troškova i KPI zahtijeva pretplatu na financijski '
                          'nadzor za vašu organizaciju. Administrator kompanije provjerava '
                          'uključene module; povezivanje s ERP-om ostaje kroz zaštićene '
                          'server funkcije.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FinanceErpHubTabBody(
              companyData: widget.companyData,
              debugUnlockModule: widget.debugUnlockModule,
              shrinkWrapped: true,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Controlling'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pregled'),
            Tab(text: 'Proizvodnja'),
            Tab(text: 'Zastoji'),
            Tab(text: 'Kvalitet'),
            Tab(text: 'Održavanje'),
            Tab(text: 'Nabava'),
            Tab(text: 'Budžeti'),
            Tab(text: 'ERP'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodHeader(
            companyId: _companyId,
            plantKey: _plantKey,
            yearsStream: _yearsSvc.watchYears(_companyId),
            businessYearId: _businessYearId,
            periodYear: _periodYear,
            periodMonth: _periodMonth,
            onYearChanged: (v) => setState(() => _businessYearId = v),
            onPeriodYearChanged: (v) => setState(() => _periodYear = v),
            onMonthChanged: (v) => setState(() => _periodMonth = v),
            onAutoSelectFirstYear: (id) {
              if (_didAutoSelectFy || _businessYearId.isNotEmpty) return;
              _didAutoSelectFy = true;
              setState(() => _businessYearId = id);
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                FinanceControllingDashboardTab(
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                  plantKey: _plantKey,
                  debugUnlockModule: widget.debugUnlockModule,
                ),
                FinanceControllingProductionTabBody(
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                  plantKey: _plantKey,
                ),
                FinanceControllingDowntimeKpiTabBody(
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                  plantKey: _plantKey,
                ),
                FinanceControllingQualityAggregatesTabBody(
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                  plantKey: _plantKey,
                ),
                FinanceControllingMaintenanceAggregatesTabBody(
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                  plantKey: _plantKey,
                ),
                FinanceControllingProcurementTabBody(
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                  plantKey: _plantKey,
                ),
                _BudgetTabBody(
                  role: _role,
                  companyData: widget.companyData,
                  businessYearId: _businessYearId,
                  periodYear: _periodYear,
                  periodMonth: _periodMonth,
                ),
                FinanceErpHubTabBody(
                  companyData: widget.companyData,
                  debugUnlockModule: widget.debugUnlockModule,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          FinancePermissions.canRunFinanceControllingAiInsight(
            companyData: widget.companyData,
            role: _role,
            debugUnlockModule: widget.debugUnlockModule,
          )
              ? FloatingActionButton.extended(
                  onPressed: () {
                    if (_businessYearId.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Odaberite poslovnu godinu u zaglavlju.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => FinanceAiAssistantScreen(
                          companyData: widget.companyData,
                          businessYearId: _businessYearId,
                          periodYear: _periodYear,
                          periodMonth: _periodMonth,
                          plantKey: _plantKey,
                          debugUnlockModule: widget.debugUnlockModule,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('AI asistent'),
                )
              : null,
    );
  }
}

class _PeriodHeader extends StatefulWidget {
  const _PeriodHeader({
    required this.companyId,
    required this.plantKey,
    required this.yearsStream,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.onYearChanged,
    required this.onPeriodYearChanged,
    required this.onMonthChanged,
    required this.onAutoSelectFirstYear,
  });

  final String companyId;
  final String plantKey;
  final Stream<List<FinancialYearListItem>> yearsStream;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<int> onPeriodYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<String> onAutoSelectFirstYear;

  @override
  State<_PeriodHeader> createState() => _PeriodHeaderState();
}

class _PeriodHeaderState extends State<_PeriodHeader> {
  bool _didSuggestFinancialYear = false;

  static List<int> _yearChoices() {
    final y = DateTime.now().toLocal().year;
    return List<int>.generate(11, (i) => y - 5 + i);
  }

  Widget _plantCaption(BuildContext context) {
    final pk = widget.plantKey.trim();
    final theme = Theme.of(context);
    if (pk.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Pogon: svi pogoni',
              style: theme.textTheme.labelMedium,
            ),
          ),
          FinanceScreenContextInfo(
            title: 'Više o pogledu',
            body:
                'Za financijske agregate u odabranom periodu, odaberite pogon u profilu '
                'ili kroz administratorske postavke. Ovaj prikaz objedinjuje cijelu kompaniju.',
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FutureBuilder<String>(
            key: ValueKey<String>('fin-plant-$pk'),
            future: CompanyPlantDisplayName.resolve(
              companyId: widget.companyId,
              plantKey: pk,
            ),
            builder: (context, snap) {
              final label = snap.connectionState == ConnectionState.waiting
                  ? '…'
                  : (snap.data ?? pk);
              return Text(
                'Pogon: $label',
                style: theme.textTheme.labelMedium,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: StreamBuilder<List<FinancialYearListItem>>(
          stream: widget.yearsStream,
          builder: (context, snap) {
            final years = snap.data ?? [];
            if (years.isNotEmpty &&
                widget.businessYearId.isEmpty &&
                snap.connectionState == ConnectionState.active &&
                !_didSuggestFinancialYear) {
              _didSuggestFinancialYear = true;
              FinancialYearListItem? active;
              for (final y in years) {
                if (y.status == 'active') {
                  active = y;
                  break;
                }
              }
              active ??= years.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                widget.onAutoSelectFirstYear(active!.id);
              });
            }

            if (widget.companyId.isEmpty) {
              return Text(
                'Prijava nije uredna. Odjavite se i pokušajte ponovo.',
                style: TextStyle(color: cs.error),
              );
            }

            final items = years
                .map(
                  (y) => DropdownMenuItem(
                    value: y.id,
                    child: Text(y.displayLabel),
                  ),
                )
                .toList();
            if (widget.businessYearId.isNotEmpty &&
                !years.any((y) => y.id == widget.businessYearId)) {
              items.insert(
                0,
                DropdownMenuItem(
                  value: widget.businessYearId,
                  child: const Text('Trenutni izbor (provjerite šifrarnik)'),
                ),
              );
            }

            final fyValue = widget.businessYearId.isEmpty
                ? null
                : widget.businessYearId;

            if (items.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _plantCaption(context),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Još nema definiranih poslovnih godina.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      FinanceScreenContextInfo(
                        title: 'Kako unijeti godine',
                        body:
                            'Administrator kompanije u postavkama dodaje dokumente '
                            'poslovnih godina za ovu organizaciju. Bez toga financijski '
                            'modul nema referentni period.',
                      ),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _plantCaption(context),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'fy-$fyValue-${items.length}',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Poslovna godina',
                    isDense: true,
                  ),
                  initialValue: fyValue,
                  isExpanded: true,
                  items: items,
                  onChanged: (v) {
                    if (v != null) widget.onYearChanged(v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<int>(
                          widget.periodYear,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Godina',
                          isDense: true,
                        ),
                        initialValue:
                            _yearChoices().contains(widget.periodYear)
                            ? widget.periodYear
                            : _yearChoices().first,
                        isExpanded: true,
                        items: _yearChoices()
                            .map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) widget.onPeriodYearChanged(v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<int>(
                          widget.periodMonth,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Mjesec',
                          isDense: true,
                        ),
                        initialValue: widget.periodMonth,
                        isExpanded: true,
                        items: List.generate(12, (i) {
                          final m = i + 1;
                          return DropdownMenuItem(
                            value: m,
                            child: Text('$m'),
                          );
                        }),
                        onChanged: (v) {
                          if (v != null) widget.onMonthChanged(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BudgetSummaryChip extends StatelessWidget {
  const _BudgetSummaryChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasize
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Usporedba plan / ostvarenje na istoj skali (max(plan, ostvarenje)).
class _BudgetTotalsBars extends StatelessWidget {
  const _BudgetTotalsBars({
    required this.plan,
    required this.actual,
    required this.colorScheme,
  });

  final double plan;
  final double actual;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = max(max(plan, actual), 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grafikon (relativno na max od plana i ostvarenja)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        Text('Plan', style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (plan / m).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 12),
        Text('Ostvarenje', style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (actual / m).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: actual <= plan ? colorScheme.primary : colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _BudgetTabBody extends StatefulWidget {
  const _BudgetTabBody({
    required this.role,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
  });

  final String role;
  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;

  @override
  State<_BudgetTabBody> createState() => _BudgetTabBodyState();
}

class _BudgetTabBodyState extends State<_BudgetTabBody> {
  final _budgets = FinanceBudgetsService();
  final _ratesSvc = FinanceExchangeRateService();
  Map<String, dynamic>? _ratesDoc;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final doc = await _ratesSvc.getRatesForLocalDate(DateTime.now());
      if (mounted) setState(() => _ratesDoc = doc);
    } catch (_) {
      if (mounted) setState(() => _ratesDoc = null);
    }
  }

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String _formatMoney(
    double? v,
    String rowCurrency,
    FinanceControllingDefaultsView def,
    String locale,
  ) {
    if (v == null) return '—';
    final bc = rowCurrency.isEmpty ? def.baseCurrency : rowCurrency;
    return FinanceCurrencyDisplay.formatBaseAmountForDisplay(
      v,
      baseCurrency: bc,
      displayCurrency: def.displayCurrency,
      locale: locale,
      exchangeRatesDoc: _ratesDoc,
    );
  }

  String? _variancePercentLabel(FinanceBudgetDoc b) {
    final p = b.plannedAmount;
    if (p == null || p.abs() < 1e-9) return null;
    final a = b.actualAmount ?? 0;
    final pct = (a - p) / p * 100;
    return 'Odstupanje od plana: ${pct.toStringAsFixed(1)} %';
  }

  @override
  Widget build(BuildContext context) {
    if (!FinancePermissions.canViewBudgetWorkspace(role: widget.role)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Budžeti i zaključavanje poslovne godine dostupni su ulozi '
            'šef računovodstva, referentu, adminu i voditelju projekta.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.businessYearId.trim().isEmpty) {
      return const Center(
        child: Text('Odaberite poslovnu godinu za budžete.'),
      );
    }

    final def = FinanceControllingDefaultsView.fromCompanyData(
      widget.companyData,
    );
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);

    return StreamBuilder<List<FinanceBudgetDoc>>(
      stream: _budgets.watchForPeriod(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Učitavanje budžeta nije uspjelo (pravila ili indeks).',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snap.data ?? [];

        if (list.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Budžet vs ostvarenje',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Nema zapisa u '
                '`companies/$_companyId/finance_budgets` za '
                'FY ${widget.businessYearId}, '
                '${widget.periodYear}-${widget.periodMonth.toString().padLeft(2, '0')}.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadRates,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Osvježi tečaj za prikaz'),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: _loadRates,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                final rollup = FinanceBudgetRollup.summarize(
                  list,
                  def.baseCurrency,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budžet vs ostvarenje',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'FY ${widget.businessYearId} · '
                            '${widget.periodYear}/${widget.periodMonth} · '
                            'prikaz u ${def.displayCurrency}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sažetak perioda (${rollup.includedCount} stavki u ${def.baseCurrency})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (rollup.excludedOtherCurrency > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${rollup.excludedOtherCurrency} stavki u drugoj valuti nisu uključene u zbroj.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _BudgetSummaryChip(
                                  label: 'Plan (zbir)',
                                  value: _formatMoney(
                                    rollup.sumPlanned,
                                    def.baseCurrency,
                                    def,
                                    locale,
                                  ),
                                ),
                                _BudgetSummaryChip(
                                  label: 'Ostvarenje (zbir)',
                                  value: _formatMoney(
                                    rollup.sumActual,
                                    def.baseCurrency,
                                    def,
                                    locale,
                                  ),
                                ),
                                _BudgetSummaryChip(
                                  label: 'Varijanca (zbir)',
                                  value: _formatMoney(
                                    rollup.sumVariance,
                                    def.baseCurrency,
                                    def,
                                    locale,
                                  ),
                                  emphasize: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _BudgetTotalsBars(
                              plan: max(rollup.sumPlanned, 0),
                              actual: max(rollup.sumActual, 0),
                              colorScheme: theme.colorScheme,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 8, 4),
                      child: Text(
                        'Stavke',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final b = list[i - 1];
              final title = b.name.isNotEmpty
                  ? b.name
                  : (b.costCenterId.isNotEmpty
                      ? b.costCenterId
                      : b.id);
              final sub = <String>[
                if (b.plantKey.isNotEmpty) 'Pogon: ${b.plantKey}',
                if (b.costCenterId.isNotEmpty && b.name.isNotEmpty)
                  'Cost center: ${b.costCenterId}',
              ].join(' · ');

              final pct = _variancePercentLabel(b);
              final varColor = b.effectiveVariance == null
                  ? null
                  : (b.effectiveVariance! <= 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (sub.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                sub,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (pct != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                pct,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: varColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 168),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Plan: ${_formatMoney(b.plannedAmount, b.currency, def, locale)}',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.end,
                            ),
                            Text(
                              'Ostv.: ${_formatMoney(b.actualAmount, b.currency, def, locale)}',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.end,
                            ),
                            Text(
                              'Var.: ${_formatMoney(b.effectiveVariance, b.currency, def, locale)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: varColor,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
