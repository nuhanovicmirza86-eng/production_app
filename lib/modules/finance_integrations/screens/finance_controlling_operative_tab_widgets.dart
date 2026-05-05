import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_controlling_defaults_view.dart';
import '../models/finance_kpi_snapshot_model.dart';
import '../models/finance_machine_cost_doc.dart';
import '../models/finance_order_profitability_doc.dart';
import '../models/finance_product_cost_doc.dart';
import '../models/finance_quality_cost_doc.dart';
import '../services/finance_derived_aggregates_service.dart';
import '../services/finance_exchange_rate_service.dart';
import '../services/finance_kpi_snapshot_service.dart';
import '../utils/finance_currency_display.dart';
import '../utils/finance_load_error_presenter.dart';
import '../widgets/finance_screen_context_info.dart';

/// Poruka kad korisnik nema odabran pogon — izvedeni agregati su po pogonu.
class FinancePlantRequiredNotice extends StatelessWidget {
  const FinancePlantRequiredNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Za ove podatke potrebno je odabrati jedan pogon u profilu ili putem administratora.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FinanceScreenContextInfo(
                title: 'Zašto je pogon potreban',
                body:
                    'Troškovi i marže u ovom dijelu controllinga prikazuju se po lokaciji. '
                    'Ako ste globalni administrator, na pregledu možete vidjeti zbirne KPI '
                    'bez odabira pogona; ovdje odaberite pogon za detalje.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab **Proizvodnja**: profitabilnost naloga + trošak po proizvodu.
class FinanceControllingProductionTabBody extends StatefulWidget {
  const FinanceControllingProductionTabBody({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.plantKey,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;

  @override
  State<FinanceControllingProductionTabBody> createState() =>
      _FinanceControllingProductionTabBodyState();
}

class _FinanceControllingProductionTabBodyState
    extends State<FinanceControllingProductionTabBody> {
  final _derived = FinanceDerivedAggregatesService();
  Map<String, dynamic>? _ratesDoc;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void didUpdateWidget(covariant FinanceControllingProductionTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodYear != widget.periodYear ||
        oldWidget.periodMonth != widget.periodMonth) {
      _loadRates();
    }
  }

  Future<void> _loadRates() async {
    try {
      final doc = await FinanceExchangeRateService().getRatesForLocalDate(
        DateTime(widget.periodYear, widget.periodMonth, 1),
      );
      if (mounted) setState(() => _ratesDoc = doc);
    } catch (_) {
      if (mounted) setState(() => _ratesDoc = null);
    }
  }

  String _fmt(double amountBase, FinanceControllingDefaultsView def) {
    return FinanceCurrencyDisplay.formatBaseAmountForDisplay(
      amountBase,
      baseCurrency: def.baseCurrency,
      displayCurrency: def.displayCurrency,
      locale: Localizations.localeOf(context).toString(),
      exchangeRatesDoc: _ratesDoc,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.plantKey.trim();
    final def = FinanceControllingDefaultsView.fromCompanyData(
      widget.companyData,
    );
    if (pk.isEmpty) {
      return const SingleChildScrollView(
        child: FinancePlantRequiredNotice(),
      );
    }
    if (widget.businessYearId.trim().isEmpty) {
      return const Center(child: Text('Odaberite poslovnu godinu.'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Profitabilnost proizvodnih naloga',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FinanceScreenContextInfo(
              title: 'O ovom izvještaju',
              body:
                  'Prikazuje se marža i troškovi po proizvodnom nalogu za odabrani '
                  'pogon i period. Podaci dolaze iz financijskog proračuna koji se '
                  'ažurira s kartice Pregled.',
            ),
          ],
        ),
        StreamBuilder<List<FinanceOrderProfitabilityDoc>>(
          stream: _derived.watchOrderProfitability(
            companyId: _companyId,
            businessYearId: widget.businessYearId.trim(),
            periodYear: widget.periodYear,
            periodMonth: widget.periodMonth,
            plantKey: pk,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(financeUserFacingLoadError(snap.error)),
                    ),
                    FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snap.data!;
            if (rows.isEmpty) {
              return const ListTile(
                title: Text('Nema podataka za ovaj odabir'),
                subtitle: Text('Ažurirajte sažetak na kartici Pregled.'),
              );
            }
            return Column(
              children: rows
                  .map(
                    (r) => ListTile(
                      dense: true,
                      title: Text(
                        r.orderCode.isNotEmpty ? r.orderCode : r.productionOrderId,
                      ),
                      subtitle: Text('PN ${r.productionOrderId}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Marža ${_fmt(r.margin, def)}',
                            style: TextStyle(
                              color: r.margin >= 0
                                  ? Colors.green.shade700
                                  : Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Prihod ${_fmt(r.revenue, def)} · trošak ${_fmt(r.totalCost, def)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const Divider(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Trošak po proizvodu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FinanceScreenContextInfo(
              title: 'O trošku po proizvodu',
              body:
                  'Agregat po artiklu za isti pogon i period. Prikazna valuta '
                  'slijedi postavke kompanije.',
            ),
          ],
        ),
        StreamBuilder<List<FinanceProductCostDoc>>(
          stream: _derived.watchProductCosts(
            companyId: _companyId,
            businessYearId: widget.businessYearId.trim(),
            periodYear: widget.periodYear,
            periodMonth: widget.periodMonth,
            plantKey: pk,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(financeUserFacingLoadError(snap.error)),
                    ),
                    FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snap.data!;
            if (rows.isEmpty) {
              return const ListTile(title: Text('Nema podataka za ovaj odabir'));
            }
            return Column(
              children: rows.map((r) {
                final label = r.productCode.isNotEmpty
                    ? '${r.productCode} · ${r.productId}'
                    : r.productId;
                return ListTile(
                  dense: true,
                  title: Text(label),
                  subtitle: Text(
                    'Količina ${NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(r.quantityProduced)} · JNT ${_fmt(r.costPerUnit, def)} / kom',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(r.totalCost, def),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Marža ${_fmt(r.margin, def)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/// Tab **Nabava**: sažetak otpada materijala / jedinični trošak iz KPI + lista troška po proizvodu.
class FinanceControllingProcurementTabBody extends StatefulWidget {
  const FinanceControllingProcurementTabBody({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.plantKey,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;

  @override
  State<FinanceControllingProcurementTabBody> createState() =>
      _FinanceControllingProcurementTabBodyState();
}

class _FinanceControllingProcurementTabBodyState
    extends State<FinanceControllingProcurementTabBody> {
  final _derived = FinanceDerivedAggregatesService();
  final _kpi = FinanceKpiSnapshotService();
  Map<String, dynamic>? _ratesDoc;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void didUpdateWidget(
    covariant FinanceControllingProcurementTabBody oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodYear != widget.periodYear ||
        oldWidget.periodMonth != widget.periodMonth) {
      _loadRates();
    }
  }

  Future<void> _loadRates() async {
    try {
      final doc = await FinanceExchangeRateService().getRatesForLocalDate(
        DateTime(widget.periodYear, widget.periodMonth, 1),
      );
      if (mounted) setState(() => _ratesDoc = doc);
    } catch (_) {
      if (mounted) setState(() => _ratesDoc = null);
    }
  }

  String _fmt(double amountBase, FinanceControllingDefaultsView def) {
    return FinanceCurrencyDisplay.formatBaseAmountForDisplay(
      amountBase,
      baseCurrency: def.baseCurrency,
      displayCurrency: def.displayCurrency,
      locale: Localizations.localeOf(context).toString(),
      exchangeRatesDoc: _ratesDoc,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.plantKey.trim();
    final def = FinanceControllingDefaultsView.fromCompanyData(
      widget.companyData,
    );
    if (pk.isEmpty) {
      return const SingleChildScrollView(
        child: FinancePlantRequiredNotice(),
      );
    }
    if (widget.businessYearId.trim().isEmpty) {
      return const Center(child: Text('Odaberite poslovnu godinu.'));
    }

    final loc = Localizations.localeOf(context).toString();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Materijal i trošak po komadu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FinanceScreenContextInfo(
              title: 'Nabava i materijal',
              body:
                  'Sažeci u novcu dolaze iz istog financijskog proračuna kao na pregledu. '
                  'Detalji skladišta i prijema robe ostaju u modulu logistike.',
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<FinanceKpiSnapshotModel?>(
          stream: _kpi.watchSnapshot(
            companyId: _companyId,
            businessYearId: widget.businessYearId.trim(),
            periodYear: widget.periodYear,
            periodMonth: widget.periodMonth,
            plantKey: pk,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(financeUserFacingLoadError(snap.error)),
                    ),
                    FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final m = snap.data;
            if (m == null) {
              return const ListTile(
                title: Text('Nema podataka za ovaj odabir'),
                subtitle: Text('Ažurirajte sažetak na kartici Pregled.'),
              );
            }
            return Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('Materijal u otpadu (scrap)'),
                  subtitle: const Text('Procjena'),
                  trailing: Text(
                    _fmt(m.scrapCost, def),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Prosječni trošak po komadu'),
                  subtitle: Text(
                    'Proizvedeno dobrih: '
                    '${NumberFormat.decimalPattern(loc).format(m.kpiProducedGoodQty)}',
                  ),
                  trailing: Text(
                    _fmt(m.costPerProduct, def),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Energija'),
                  trailing: Text(_fmt(m.energyCost, def)),
                ),
              ],
            );
          },
        ),
        const Divider(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Trošak po proizvodu',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FinanceScreenContextInfo(
              title: 'Po artiklu',
              body:
                  'Isti agregat kao u kartici Proizvodnja — korisno kad gledate nabavu '
                  'u kontekstu artikla.',
            ),
          ],
        ),
        StreamBuilder<List<FinanceProductCostDoc>>(
          stream: _derived.watchProductCosts(
            companyId: _companyId,
            businessYearId: widget.businessYearId.trim(),
            periodYear: widget.periodYear,
            periodMonth: widget.periodMonth,
            plantKey: pk,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(financeUserFacingLoadError(snap.error)),
                    ),
                    FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snap.data!;
            if (rows.isEmpty) {
              return const ListTile(
                title: Text('Nema podataka za ovaj odabir'),
                subtitle: Text('Ažurirajte sažetak na kartici Pregled.'),
              );
            }
            return Column(
              children: rows.map((r) {
                final label = r.productCode.isNotEmpty
                    ? '${r.productCode} · ${r.productId}'
                    : r.productId;
                return ListTile(
                  dense: true,
                  title: Text(label),
                  subtitle: Text(
                    'Količina ${NumberFormat.decimalPattern(loc).format(r.quantityProduced)} · JNT ${_fmt(r.costPerUnit, def)} / kom',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(r.totalCost, def),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Marža ${_fmt(r.margin, def)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/// Tab **Zastoji**: sažetak iz KPI snimka (novčani gubitak OEE zastoja).
class FinanceControllingDowntimeKpiTabBody extends StatelessWidget {
  const FinanceControllingDowntimeKpiTabBody({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.plantKey,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final kpi = FinanceKpiSnapshotService();
    final pk = plantKey.trim();
    if (businessYearId.trim().isEmpty) {
      return const Center(child: Text('Odaberite poslovnu godinu.'));
    }

    return StreamBuilder<FinanceKpiSnapshotModel?>(
      stream: kpi.watchSnapshot(
        companyId: _companyId,
        businessYearId: businessYearId.trim(),
        periodYear: periodYear,
        periodMonth: periodMonth,
        plantKey: pk,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      financeUserFacingLoadError(snap.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final m = snap.data;
        if (m == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pk.isEmpty) const FinancePlantRequiredNotice(),
              const ListTile(
                title: Text('Nema podataka za ovaj odabir'),
                subtitle: Text('Ažurirajte sažetak na kartici Pregled.'),
              ),
            ],
          );
        }
        final loc = Localizations.localeOf(context).toString();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Financijski učinak zastoja',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FinanceScreenContextInfo(
                  title: 'Kako se računa',
                  body:
                      'Procjena temelji na minutama OEE zastoja i postavljenoj satnici u '
                      'postavkama kompanije. Valuta slijedi bazu snimka; aplikacija može '
                      'prikazati drugu valutu prema postavkama.',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Gubitak zastoja (procjena)'),
              subtitle: Text(
                '${NumberFormat.decimalPattern(loc).format(m.downtimeLoss)} ${m.baseCurrency ?? m.currency} · ${m.downtimeOeeMinutes} min OEE · satnica ${m.machineHourlyRate != null ? NumberFormat.decimalPattern(loc).format(m.machineHourlyRate) : '—'}',
              ),
            ),
            ListTile(
              title: const Text('Ukupni operativni trošak u periodu'),
              subtitle: Text(
                NumberFormat.decimalPattern(loc).format(m.totalCost),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tab **Kvalitet**: redovi iz `finance_quality_costs`.
class FinanceControllingQualityAggregatesTabBody extends StatefulWidget {
  const FinanceControllingQualityAggregatesTabBody({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.plantKey,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;

  @override
  State<FinanceControllingQualityAggregatesTabBody> createState() =>
      _FinanceControllingQualityAggregatesTabBodyState();
}

class _FinanceControllingQualityAggregatesTabBodyState
    extends State<FinanceControllingQualityAggregatesTabBody> {
  final _derived = FinanceDerivedAggregatesService();
  Map<String, dynamic>? _ratesDoc;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void didUpdateWidget(
    covariant FinanceControllingQualityAggregatesTabBody oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodYear != widget.periodYear ||
        oldWidget.periodMonth != widget.periodMonth) {
      _loadRates();
    }
  }

  Future<void> _loadRates() async {
    try {
      final doc = await FinanceExchangeRateService().getRatesForLocalDate(
        DateTime(widget.periodYear, widget.periodMonth, 1),
      );
      if (mounted) setState(() => _ratesDoc = doc);
    } catch (_) {
      if (mounted) setState(() => _ratesDoc = null);
    }
  }

  String _fmt(double amountBase, FinanceControllingDefaultsView def) {
    return FinanceCurrencyDisplay.formatBaseAmountForDisplay(
      amountBase,
      baseCurrency: def.baseCurrency,
      displayCurrency: def.displayCurrency,
      locale: Localizations.localeOf(context).toString(),
      exchangeRatesDoc: _ratesDoc,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.plantKey.trim();
    final def = FinanceControllingDefaultsView.fromCompanyData(
      widget.companyData,
    );
    if (pk.isEmpty) {
      return const SingleChildScrollView(child: FinancePlantRequiredNotice());
    }
    if (widget.businessYearId.trim().isEmpty) {
      return const Center(child: Text('Odaberite poslovnu godinu.'));
    }

    return StreamBuilder<List<FinanceQualityCostDoc>>(
      stream: _derived.watchQualityCosts(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
        plantKey: pk,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      financeUserFacingLoadError(snap.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Trošak slabog kvaliteta (COPQ)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FinanceScreenContextInfo(
                  title: 'COPQ u controllingu',
                  body:
                      'Sažetak po kategorijama iz financijskog proračuna. Detalji NCR-a i '
                      'kontrola ostaju u modulu kvalitete.',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...rows.map((r) {
              final loc = Localizations.localeOf(context).toString();
              String subtitle = r.category;
              if (r.scrapQty > 0 || r.reworkQty > 0) {
                subtitle +=
                    ' · skrap ${NumberFormat.decimalPattern(loc).format(r.scrapQty)} · rework ${NumberFormat.decimalPattern(loc).format(r.reworkQty)}';
              }
              if (r.ncrClosedCount > 0) {
                subtitle += ' · NCR zatv. ${r.ncrClosedCount}';
              }
              return ListTile(
                title: Text(_fmt(r.amount, def)),
                subtitle: Text(subtitle),
              );
            }),
            if (rows.isEmpty)
              const ListTile(
                title: Text('Nema podataka za ovaj odabir'),
                subtitle: Text('Ažurirajte sažetak na kartici Pregled.'),
              ),
          ],
        );
      },
    );
  }
}

/// Tab **Održavanje**: radni centri / zastoj + održavanje (`finance_machine_costs`).
class FinanceControllingMaintenanceAggregatesTabBody extends StatefulWidget {
  const FinanceControllingMaintenanceAggregatesTabBody({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    required this.plantKey,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;

  @override
  State<FinanceControllingMaintenanceAggregatesTabBody> createState() =>
      _FinanceControllingMaintenanceAggregatesTabBodyState();
}

class _FinanceControllingMaintenanceAggregatesTabBodyState
    extends State<FinanceControllingMaintenanceAggregatesTabBody> {
  final _derived = FinanceDerivedAggregatesService();
  Map<String, dynamic>? _ratesDoc;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void didUpdateWidget(
    covariant FinanceControllingMaintenanceAggregatesTabBody oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodYear != widget.periodYear ||
        oldWidget.periodMonth != widget.periodMonth) {
      _loadRates();
    }
  }

  Future<void> _loadRates() async {
    try {
      final doc = await FinanceExchangeRateService().getRatesForLocalDate(
        DateTime(widget.periodYear, widget.periodMonth, 1),
      );
      if (mounted) setState(() => _ratesDoc = doc);
    } catch (_) {
      if (mounted) setState(() => _ratesDoc = null);
    }
  }

  String _fmt(double amountBase, FinanceControllingDefaultsView def) {
    return FinanceCurrencyDisplay.formatBaseAmountForDisplay(
      amountBase,
      baseCurrency: def.baseCurrency,
      displayCurrency: def.displayCurrency,
      locale: Localizations.localeOf(context).toString(),
      exchangeRatesDoc: _ratesDoc,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.plantKey.trim();
    final def = FinanceControllingDefaultsView.fromCompanyData(
      widget.companyData,
    );
    if (pk.isEmpty) {
      return const SingleChildScrollView(child: FinancePlantRequiredNotice());
    }
    if (widget.businessYearId.trim().isEmpty) {
      return const Center(child: Text('Odaberite poslovnu godinu.'));
    }

    return StreamBuilder<List<FinanceMachineCostDoc>>(
      stream: _derived.watchMachineCosts(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
        plantKey: pk,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      financeUserFacingLoadError(snap.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Trošak po radnom centru',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FinanceScreenContextInfo(
                  title: 'Zastoj i održavanje',
                  body:
                      'Procjena uključuje zastoje i povezani dio troška održavanja po '
                      'radnom centru za odabrani period.',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...rows.map((r) {
              final wcLabel = r.workCenterName.isNotEmpty
                  ? r.workCenterName
                  : r.workCenterCode.isNotEmpty
                      ? r.workCenterCode
                      : r.workCenterId.isNotEmpty
                          ? r.workCenterId
                          : '—';
              return ListTile(
                title: Text(wcLabel),
                subtitle: Text(
                  '${r.downtimeOeeMinutes} min OEE · zastoj ${_fmt(r.downtimeCost, def)} · održ. ${_fmt(r.maintenanceCost, def)}',
                ),
                trailing: Text(
                  _fmt(r.totalCost, def),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }),
            if (rows.isEmpty)
              const ListTile(
                title: Text('Nema podataka za ovaj odabir'),
                subtitle: Text('Ažurirajte sažetak na kartici Pregled.'),
              ),
          ],
        );
      },
    );
  }
}
