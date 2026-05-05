import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../models/finance_ai_insight_doc.dart';
import '../models/finance_controlling_defaults_view.dart';
import '../models/finance_kpi_snapshot_model.dart';
import '../services/finance_ai_insight_service.dart';
import '../services/finance_ai_insights_list_service.dart';
import '../services/finance_company_operational_config_service.dart';
import '../services/finance_exchange_rate_service.dart';
import '../services/finance_kpi_recompute_service.dart';
import '../services/finance_kpi_snapshot_service.dart';
import '../../../core/company_plant_display_name.dart';
import '../utils/finance_currency_display.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../widgets/finance_screen_context_info.dart';
import 'finance_ai_assistant_screen.dart';

/// KPI kartice za root kolekciju [finance_kpi_snapshots] (pun controlling pretplata).
class FinanceControllingDashboardTab extends StatefulWidget {
  const FinanceControllingDashboardTab({
    super.key,
    required this.companyData,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    this.plantKey = '',
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;
  final bool debugUnlockModule;

  @override
  State<FinanceControllingDashboardTab> createState() =>
      _FinanceControllingDashboardTabState();
}

class _FinanceControllingDashboardTabState
    extends State<FinanceControllingDashboardTab> {
  final _recompute = FinanceKpiRecomputeService();
  final _aiInsight = FinanceAiInsightService();
  final _aiInsightsList = FinanceAiInsightsListService();
  final _ratesSvc = FinanceExchangeRateService();
  bool _recomputing = false;
  bool _aiRunning = false;
  Map<String, dynamic>? _ratesDoc;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _refreshRates();
  }

  Future<void> _refreshRates() async {
    try {
      final doc = await _ratesSvc.getRatesForLocalDate(DateTime.now());
      if (mounted) setState(() => _ratesDoc = doc);
    } catch (_) {
      if (mounted) setState(() => _ratesDoc = null);
    }
  }

  Future<void> _onRecompute(BuildContext context) async {
    if (_companyId.isEmpty || widget.businessYearId.trim().isEmpty) return;
    setState(() => _recomputing = true);
    try {
      await _recompute.recompute(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
        plantKey: widget.plantKey.trim(),
      );
      if (!context.mounted) return;
      await _refreshRates();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KPI preračunati.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Preračun nije uspio.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  Future<void> _showInsightMarkdownDialog(
    BuildContext context, {
    required String markdown,
    String title = 'AI uvid — KPI',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: markdown,
                selectable: true,
                shrinkWrap: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onFinanceAiInsight(BuildContext context) async {
    if (_companyId.isEmpty || widget.businessYearId.trim().isEmpty) return;
    final focusCtrl = TextEditingController();
    final focus = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('AI uvid na KPI'),
          content: SingleChildScrollView(
            child: TextField(
              controller: focusCtrl,
              decoration: const InputDecoration(
                labelText: 'Prioritet (opcionalno)',
                hintText: 'Npr. naglasi maržu, skart i zastoje',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, focusCtrl.text.trim()),
              child: const Text('Generiraj'),
            ),
          ],
        );
      },
    );
    focusCtrl.dispose();
    if (!context.mounted || focus == null) return;
    await _runFinanceAi(context, analysisFocus: focus);
  }

  Future<void> _runFinanceAi(
    BuildContext context, {
    required String analysisFocus,
  }) async {
    setState(() => _aiRunning = true);
    try {
      final result = await _aiInsight.runInsight(
        companyId: _companyId,
        businessYearId: widget.businessYearId.trim(),
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
        plantKey: widget.plantKey.trim(),
        analysisFocus: analysisFocus,
      );
      if (!context.mounted) return;
      await _showInsightMarkdownDialog(context, markdown: result.markdown);
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'AI uvid nije uspio.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _aiRunning = false);
    }
  }

  String _formatMoney(
    double amountBase,
    String amountBaseCurrency,
    FinanceControllingDefaultsView def,
    String locale,
  ) {
    return FinanceCurrencyDisplay.formatBaseAmountForDisplay(
      amountBase,
      baseCurrency: amountBaseCurrency,
      displayCurrency: def.displayCurrency,
      locale: locale,
      exchangeRatesDoc: _ratesDoc,
    );
  }

  Map<String, dynamic> _mergeCompanySnapshot(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> companySnap,
  ) {
    final merged = Map<String, dynamic>.from(widget.companyData);
    if (companySnap.hasData && companySnap.data!.exists) {
      final d = companySnap.data!.data();
      if (d != null) {
        merged.addAll(d);
      }
    }
    return merged;
  }

  Future<void> _showEditFinanceDefaultsDialog(
    BuildContext context, {
    required FinanceControllingDefaultsView def,
    required String companyId,
    required String plantKeyForEnergy,
  }) async {
    final baseCtrl = TextEditingController(text: def.baseCurrency);
    final dispCtrl = TextEditingController(text: def.displayCurrency);
    final mhrCtrl = TextEditingController(
      text: (def.machineHourlyRate ?? 85.5).toString(),
    );
    final copqScrapCtrl = TextEditingController(
      text: def.copqScrapUnitCostInBase != null
          ? def.copqScrapUnitCostInBase!.toString()
          : '',
    );
    final copqRwCtrl = TextEditingController(
      text: def.copqReworkUnitCostInBase != null
          ? def.copqReworkUnitCostInBase!.toString()
          : '',
    );
    final copqNcrCtrl = TextEditingController(
      text: def.copqClosedNcrEstimateInBase != null
          ? def.copqClosedNcrEstimateInBase!.toString()
          : '',
    );
    final maintFaultCtrl = TextEditingController(
      text: def.maintenanceCostPerClosedFaultInBase != null
          ? def.maintenanceCostPerClosedFaultInBase!.toString()
          : '',
    );
    final energyCtrl = TextEditingController(
      text: (() {
        final pk = plantKeyForEnergy.trim();
        if (pk.isEmpty) return '';
        final v = def.plantEnergyBudgetMonthlyFor(pk);
        return v != null ? v.toString() : '';
      })(),
    );
    final formKey = GlobalKey<FormState>();
    final svc = FinanceCompanyOperationalConfigService();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Financijske postavke tenanta'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: baseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bazna valuta (račun) · ISO 4217',
                          hintText: 'EUR',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 3,
                        validator: (v) {
                          final s = (v ?? '').trim().toUpperCase();
                          if (!RegExp(r'^[A-Z]{3}$').hasMatch(s)) {
                            return 'Točno tri slova (npr. EUR).';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: dispCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valuta prikaza · ISO 4217',
                          hintText: 'BAM',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 3,
                        validator: (v) {
                          final s = (v ?? '').trim().toUpperCase();
                          if (!RegExp(r'^[A-Z]{3}$').hasMatch(s)) {
                            return 'Točno tri slova (npr. BAM).';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: mhrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Satnica mašine (bazna valuta / h)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').trim());
                          if (n == null || !n.isFinite || n < 0 || n > 100000) {
                            return 'Broj 0–100000.';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: copqScrapCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'COPQ škart (bazna valuta / kom, opcionalno)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s);
                          if (n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              n > 10000000) {
                            return 'Broj 0–10000000 ili prazno.';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: copqRwCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'COPQ rework (bazna valuta / kom, opcionalno; prazno = kao škart)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s);
                          if (n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              n > 10000000) {
                            return 'Broj 0–10000000 ili prazno.';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: copqNcrCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Procjena po zatv. NCR (bazna valuta, opcionalno)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s);
                          if (n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              n > 10000000) {
                            return 'Broj 0–10000000 ili prazno.';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: maintFaultCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Održavanje po zatv. kvaru (bazna valuta, opcionalno)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s);
                          if (n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              n > 10000000) {
                            return 'Broj 0–10000000 ili prazno.';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: energyCtrl,
                        decoration: InputDecoration(
                          labelText:
                              plantKeyForEnergy.trim().isEmpty
                                  ? 'Energija: odaberi pogon u zaglavlju'
                                  : 'Mjesečni budžet energije · '
                                        '${plantKeyForEnergy.trim()} '
                                        '(${def.baseCurrency})',
                          hintText: 'Prazno = ukloni za ovaj pogon',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (plantKeyForEnergy.trim().isEmpty) return null;
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return null;
                          final n = double.tryParse(s.replaceAll(',', '.'));
                          if (n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              n > 10000000) {
                            return 'Broj 0–10000000 ili prazno.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Izmjena ide u Firestore preko zaštićenog Callabla. '
                        'Zatim ponovo preračunajte KPI da snimak dobije novu satnicu.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setLocal(() => saving = true);
                          try {
                            double? opt(String s) {
                              final t = s.trim();
                              if (t.isEmpty) return null;
                              return double.tryParse(t);
                            }

                            Map<String, dynamic>? energyPatch;
                            final pkEn = plantKeyForEnergy.trim();
                            if (pkEn.isNotEmpty) {
                              final te = energyCtrl.text.trim();
                              if (te.isEmpty) {
                                energyPatch = {pkEn: null};
                              } else {
                                final n = double.parse(te.replaceAll(',', '.'));
                                energyPatch = {pkEn: n};
                              }
                            }

                            await svc.updateFinanceControllingDefaults(
                              companyId: companyId,
                              baseCurrency: baseCtrl.text,
                              displayCurrency: dispCtrl.text,
                              machineHourlyRate:
                                  double.parse(mhrCtrl.text.trim()),
                              copqScrapUnitCostInBase: opt(copqScrapCtrl.text),
                              copqReworkUnitCostInBase: opt(copqRwCtrl.text),
                              copqClosedNcrEstimateInBase: opt(copqNcrCtrl.text),
                              maintenanceCostPerClosedFaultInBase:
                                  opt(maintFaultCtrl.text),
                              plantEnergyCostBudgetMonthlyInBasePatch:
                                  energyPatch,
                            );
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            if (!context.mounted) return;
                            await _refreshRates();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Postavke spremljene.'),
                              ),
                            );
                          } on FirebaseFunctionsException catch (e) {
                            setLocal(() => saving = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.message ?? 'Spremanje nije uspjelo.',
                                ),
                                backgroundColor:
                                    Theme.of(ctx).colorScheme.error,
                              ),
                            );
                          } catch (e) {
                            setLocal(() => saving = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor:
                                    Theme.of(ctx).colorScheme.error,
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );

    baseCtrl.dispose();
    dispCtrl.dispose();
    mhrCtrl.dispose();
    copqScrapCtrl.dispose();
    copqRwCtrl.dispose();
    copqNcrCtrl.dispose();
    maintFaultCtrl.dispose();
    energyCtrl.dispose();
  }

  Widget _financeDefaultsCard({
    required BuildContext context,
    required FinanceControllingDefaultsView def,
    required ThemeData theme,
    required ColorScheme cs,
    required String selectedPlantKey,
  }) {
    final canEdit = FinancePermissions.canEditFinanceControllingDefaults(
      _role,
    );
    final mhrBase = def.machineHourlyRate;
    final mhrDisplay = mhrBase == null
        ? null
        : FinanceCurrencyDisplay.toDisplayAmount(
            mhrBase,
            baseCurrency: def.baseCurrency,
            displayCurrency: def.displayCurrency,
            exchangeRatesDoc: _ratesDoc,
          );
    final rateText = FinanceCurrencyDisplay.describeDisplayRateSource(
      baseCurrency: def.baseCurrency,
      displayCurrency: def.displayCurrency,
      exchangeRatesDoc: _ratesDoc,
    );

    return Card(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Valute i satnica',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canEdit)
                  TextButton.icon(
                    onPressed: () => _showEditFinanceDefaultsDialog(
                      context,
                      def: def,
                      companyId: _companyId,
                      plantKeyForEnergy: selectedPlantKey,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Uredi'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Baza (iznosi u engineu / Firestore): ${def.baseCurrency} · '
              'Prikaz: ${def.displayCurrency}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(rateText, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              mhrBase == null
                  ? 'Satnica mašine u bazi: — (postavite za monetarni gubitak zastoja).'
                  : 'Satnica: ${mhrBase.toStringAsFixed(2)} ${def.baseCurrency}/h'
                      '${mhrDisplay != null && def.baseCurrency != def.displayCurrency ? '  ·  ${mhrDisplay.toStringAsFixed(2)} ${def.displayCurrency}/h (samo prikaz)' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (selectedPlantKey.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Energija (mjesečno, ${def.baseCurrency}): '
                '${def.plantEnergyBudgetMonthlyFor(selectedPlantKey)?.toStringAsFixed(2) ?? '—'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (def.copqScrapUnitCostInBase != null ||
                def.copqReworkUnitCostInBase != null ||
                def.copqClosedNcrEstimateInBase != null ||
                def.maintenanceCostPerClosedFaultInBase != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ulazi za COPQ / održavanje (${def.baseCurrency}): škart/kom '
                  '${def.copqScrapUnitCostInBase?.toStringAsFixed(2) ?? "—"} · '
                  'rework/kom ${def.copqReworkUnitCostInBase?.toStringAsFixed(2) ?? "—"} · '
                  'NCR zatv. ${def.copqClosedNcrEstimateInBase?.toStringAsFixed(2) ?? "—"} · '
                  'kvar zatv. ${def.maintenanceCostPerClosedFaultInBase?.toStringAsFixed(2) ?? "—"}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Samo tenant admin, super_admin ili accounting_manager '
                  'može mijenjati ove postavke.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_companyId.isEmpty || widget.businessYearId.trim().isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: cs.errorContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Odaberite poslovnu godinu u zaglavlju iznad.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  FinanceScreenContextInfo(
                    title: 'Za administratore',
                    body:
                        'Poslovne godine se dodaju u postavkama kompanije. Bez toga nije '
                        'moguće uspoređivati plan i ostvarenje u kontroling pregledu.',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final svc = FinanceKpiSnapshotService();
    final companyRef =
        FirebaseFirestore.instance.collection('companies').doc(_companyId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: companyRef.snapshots(),
      builder: (context, companySnap) {
        final merged = _mergeCompanySnapshot(companySnap);
        final def = FinanceControllingDefaultsView.fromCompanyData(merged);

        final canAi = FinancePermissions.canRunFinanceControllingAiInsight(
          companyData: merged,
          role: _role,
          debugUnlockModule: widget.debugUnlockModule,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<String>(
                    key: ValueKey<String>(
                      '${widget.plantKey.trim()}-$_companyId',
                    ),
                    future: widget.plantKey.trim().isEmpty
                        ? Future.value('svi pogoni')
                        : CompanyPlantDisplayName.resolve(
                            companyId: _companyId,
                            plantKey: widget.plantKey.trim(),
                          ),
                    builder: (context, snap) {
                      final plantLine = widget.plantKey.trim().isEmpty
                          ? 'Preračun za: svi pogoni'
                          : 'Preračun za: ${snap.connectionState == ConnectionState.waiting ? '…' : (snap.data ?? widget.plantKey.trim())}';
                      return Text(
                        plantLine,
                        style: theme.textTheme.bodySmall,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (canAi)
                          FilledButton.tonalIcon(
                            onPressed: _aiRunning || _recomputing
                                ? null
                                : () => _onFinanceAiInsight(context),
                            icon: _aiRunning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 18,
                                  ),
                            label: Text(_aiRunning ? 'AI…' : 'AI uvid'),
                          ),
                        FilledButton.tonal(
                          onPressed:
                              _recomputing || _aiRunning
                                  ? null
                                  : () => _onRecompute(context),
                          child: _recomputing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Preračunaj KPI'),
                        ),
                      ],
                    ),
                  ),
                  if (canAi) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FinanceAiAssistantScreen(
                                companyData: widget.companyData,
                                businessYearId: widget.businessYearId.trim(),
                                periodYear: widget.periodYear,
                                periodMonth: widget.periodMonth,
                                plantKey: widget.plantKey.trim(),
                                debugUnlockModule: widget.debugUnlockModule,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.smart_toy_outlined, size: 18),
                        label: const Text(
                          'AI centar — upozorenja i memorija kompanije',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canAi)
              StreamBuilder<List<FinanceAiInsightDoc>>(
                stream: _aiInsightsList.watchRecentForPeriod(
                  companyId: _companyId,
                  businessYearId: widget.businessYearId.trim(),
                  periodYear: widget.periodYear,
                  periodMonth: widget.periodMonth,
                  plantKey: widget.plantKey.trim(),
                ),
                builder: (context, histSnap) {
                  if (histSnap.hasError) return const SizedBox.shrink();
                  final list = histSnap.data;
                  if (list == null || list.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final locale = Localizations.localeOf(context).toString();
                  final fmt = DateFormat.yMMMd(locale).add_Hm();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Card(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 12, top: 8, right: 12),
                              child: Text(
                                'Zadnji AI uvidi (ovaj period)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: (56 * list.length).clamp(56, 240).toDouble(),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: list.length,
                                itemBuilder: (ctx, i) {
                                  final e = list[i];
                                  final when = e.createdAt != null
                                      ? fmt.format(e.createdAt!.toLocal())
                                      : '—';
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.history_edu_outlined,
                                      size: 22,
                                    ),
                                    title: Text(
                                      when,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    subtitle: Text(
                                      '${e.insightKind == FinanceAiInsightService.insightKindWatchlist ? 'Watchlist' : 'Analiza'}'
                                      '${e.sourceTrigger == 'scheduled_nightly' ? ' · noćni' : ''} · '
                                      '${e.analysisFocus ?? 'Opći uvid (bez dodatnog fokusa)'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _showInsightMarkdownDialog(
                                      context,
                                      markdown: e.analysisMarkdown,
                                      title: 'AI uvid · $when',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            Expanded(
              child: StreamBuilder<FinanceKpiSnapshotModel?>(
                stream: svc.watchSnapshot(
                  companyId: _companyId,
                  businessYearId: widget.businessYearId.trim(),
                  periodYear: widget.periodYear,
                  periodMonth: widget.periodMonth,
                  plantKey: widget.plantKey.trim(),
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
                                style: TextStyle(color: cs.error),
                              ),
                            ),
                            FinanceTechnicalInfoIcon(
                              detail: '${snap.error}',
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final m = snap.data;
                  final locale = Localizations.localeOf(context).toString();

                  if (m == null) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _financeDefaultsCard(
                          context: context,
                          def: def,
                          theme: theme,
                          cs: cs,
                          selectedPlantKey: widget.plantKey.trim(),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Za ovaj period još nema spremljenog sažetka.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                FinanceScreenContextInfo(
                                  title: 'Kada se podaci pojave',
                                  body:
                                      'Koristite gumb „Preračunaj KPI” iznad ili pričekajte '
                                      'automatski noćni proračun. Potrebni su operativni podaci '
                                      '(npr. zastoji) i postavke valute/satnice u postavkama kompanije.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final snapBase = m.canonicalBaseCurrency;
                  final mhr = m.effectiveMachineHourlyRate;
                  final rateNoteShort = mhr == null
                      ? 'Satnica za proračun zastoja nije postavljena.'
                      : 'Zastoj: ${m.downtimeOeeMinutes} min × $mhr $snapBase/h.';
                  final rateNoteDetail = mhr == null
                      ? 'U postavkama kompanije uneste satnicu radnog sata u baznoj valuti. '
                          'Bez toga novčani iznos gubitka zastoja ostaje nula; minute se i dalje prikazuju.'
                      : 'Procjena temelji se na OEE minutama zastoja i postavljenoj satnici. '
                          'Prikaz u aplikaciji koristi odabranu prikaznu valutu i tečajeve ako su dostupni.';

                  final displayShort = snapBase == def.displayCurrency
                      ? 'Iznosi u valuti $snapBase.'
                      : 'Baza: $snapBase · prikaz: ${def.displayCurrency}.';
                  final displayDetail = snapBase == def.displayCurrency
                      ? 'Svi iznosi u ovom sažetku čitaju se u istoj valuti.'
                      : 'Snimak se sprema u baznoj valuti tenant-a; aplikacija pretvara u valutu prikaza '
                          'prema postavkama i dostupnim tečajevima.';

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _financeDefaultsCard(
                        context: context,
                        def: def,
                        theme: theme,
                        cs: cs,
                        selectedPlantKey: widget.plantKey.trim(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Sažetak · ${widget.periodYear} / ${widget.periodMonth}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          FinanceScreenContextInfo(
                            title: 'Valuta i prikaz',
                            body: '$displayShort\n\n$displayDetail',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              rateNoteShort,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          FinanceScreenContextInfo(
                            title: 'Zastoj u novcu',
                            body: rateNoteDetail,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _KpiCard(
                            title: 'Prihod',
                            value: _formatMoney(
                              m.revenue,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.trending_up_outlined,
                            subtitle: m.orderProfitabilityAvailable || m.revenue > 0
                                ? null
                                : 'Prihod nije dostupan za prikaz.',
                          ),
                          _KpiCard(
                            title: 'Ukupni trošak',
                            value: _formatMoney(
                              m.totalCost,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          _KpiCard(
                            title: 'Bruto marža',
                            value: _formatMoney(
                              m.grossMargin,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.pie_chart_outline,
                          ),
                          _KpiCard(
                            title: 'Trošak scrappa',
                            value: _formatMoney(
                              m.scrapCost,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.recycling_outlined,
                          ),
                          _KpiCard(
                            title: 'Gubitak zastoja',
                            value: _formatMoney(
                              m.downtimeLoss,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.timer_off_outlined,
                          ),
                          _KpiCard(
                            title: 'Održavanje',
                            value: _formatMoney(
                              m.maintenanceCost,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.build_circle_outlined,
                          ),
                          _KpiCard(
                            title: 'Energija',
                            value: _formatMoney(
                              m.energyCost,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.bolt_outlined,
                          ),
                          _KpiCard(
                            title: 'Trošak po komadu',
                            value: _formatMoney(
                              m.costPerProduct,
                              snapBase,
                              def,
                              locale,
                            ),
                            icon: Icons.inventory_2_outlined,
                          ),
                        ],
                      ),
                      if (m.scrapCost > 0 ||
                          m.maintenanceCost > 0 ||
                          m.copqQualityNcrClosedCount > 0 ||
                          m.maintenanceClosedFaultCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'COPQ / održavanje (izvor): škart ${m.copqProductionScrapQty.toStringAsFixed(0)} kom · '
                            'rework ${m.copqProductionReworkQty.toStringAsFixed(0)} kom · '
                            'NCR zatvoreno ${m.copqQualityNcrClosedCount} · '
                            'kvarovi zatvoreni ${m.maintenanceClosedFaultCount}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 172,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
