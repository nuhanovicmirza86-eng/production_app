import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:production_app/core/access/production_access_helper.dart';
import 'package:production_app/core/branding/operonix_ai_branding.dart';
import 'package:production_app/core/errors/app_error_mapper.dart' show AppErrorMapper;
import 'package:production_app/core/saas/production_module_keys.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';

import '../../ai_analysis/screens/ai_analysis_screen.dart' show aiStructuredAnalysisVisibleForRole;

import '../../downtime/analytics/downtime_analytics_engine.dart';
import '../models/analytics_downtime_daily_model.dart';
import '../models/analytics_summary_model.dart';
import '../services/ai_insight_service.dart';
import '../services/operonix_analytics_backend_ai_service.dart';
import '../services/analytics_downtime_daily_callable_service.dart';
import '../services/operonix_analytics_service.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/analytics_kpi_card.dart';
import '../widgets/downtime_daily_bars.dart';
import '../widgets/downtime_pareto_chart.dart';
import '../widgets/oee_trend_line_chart.dart';
import '../widgets/shift_loss_heatmap_strip.dart';
import '../widgets/work_center_ranking_table.dart';
import '../../downtime/screens/downtimes_screen.dart';
import 'analytics_work_center_details_screen.dart';

enum _RangePreset {
  d0('Danas'),
  d7('7 dana'),
  d30('30 dana'),
  d90('90 dana'),
  custom('Prilagođeno…');

  final String label;
  const _RangePreset(this.label);
}

/// Glavni analitički centar: KPI, Pareto, OEE trend (TEEP), zastoji, smjene, OperonixAI (rules).
class OperonixAnalyticsDashboardScreen extends StatefulWidget {
  const OperonixAnalyticsDashboardScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<OperonixAnalyticsDashboardScreen> createState() =>
      _OperonixAnalyticsDashboardScreenState();
}

class _OperonixAnalyticsDashboardScreenState
    extends State<OperonixAnalyticsDashboardScreen> {
  final _service = OperonixAnalyticsService();
  final _narrator = AiInsightService();
  final _downtimeDailyCallable = AnalyticsDowntimeDailyCallableService();

  _RangePreset _preset = _RangePreset.d7;
  DateTimeRange? _customRange;
  bool _includeRejected = false;
  bool _loading = false;
  Object? _error;
  OperonixAnalyticsSnapshot? _snap;
  OeeTrendMode _trendMode = OeeTrendMode.oee;

  String? _backendAnalysisMarkdown;
  bool _loadingBackendAnalysis = false;
  Object? _backendAnalysisError;
  final _backendAi = OperonixAnalyticsBackendAiService();

  DateTime? _recomputeDowntimeTargetDay;
  bool _recomputingDowntimeSummary = false;
  Object? _recomputeDowntimeError;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canView => ProductionAccessHelper.canView(
        role: _role,
        card: ProductionDashboardCard.operonixAnalytics,
      );

  /// Isti pristup kao ekran „AI analiza — strukturirani podaci“ (pretplata + uloga).
  bool get _canRunBackendAnalysis =>
      _canView &&
      ProductionModuleKeys.hasAiProductionAnalyticsModule(widget.companyData) &&
      aiStructuredAnalysisVisibleForRole(widget.companyData['role']);

  bool get _canOpenDowntimeFromHere => ProductionAccessHelper.canView(
    role: _role,
    card: ProductionDashboardCard.downtime,
  );

  void _openLinkedDowntimeOperativa() {
    if (!_canOpenDowntimeFromHere) return;
    final r = _resolveRange();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DowntimesScreen(
          companyData: widget.companyData,
          initialTabIndex: 0,
          initialEventRangeStart: r.start,
          initialEventRangeEndExclusive: r.end,
          openOperativeFiltersOnOpen: true,
        ),
      ),
    );
  }

  void _openLinkedDowntimeAnalitika() {
    if (!_canOpenDowntimeFromHere) return;
    final r = _resolveRange();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DowntimesScreen(
          companyData: widget.companyData,
          initialTabIndex: 1,
          initialAnalyticsRangeStart: r.start,
          initialAnalyticsRangeEndExclusive: r.end,
          initialAnalyticsIncludeRejected: _includeRejected,
        ),
      ),
    );
  }

  /// Isti skup kao Cloud Function [recomputeDowntimeAnalyticsDaily].
  bool get _canRecomputeServerDowntimeSummary {
    final r = ProductionAccessHelper.normalizeRole(_role);
    return r == ProductionAccessHelper.roleSuperAdmin ||
        r == ProductionAccessHelper.roleAdmin ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleMaintenanceManager ||
        r == ProductionAccessHelper.roleLogisticsManager;
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Zadnji uključeni lokalni dan u trenutno odabranom periodu analitike.
  DateTime _lastLocalDayInSelectedRange() {
    final r = _resolveRange();
    final t = r.end.toLocal().subtract(const Duration(milliseconds: 1));
    return _dayStart(t);
  }

  DateTime _recomputeDowntimeDayResolved() {
    final range = _resolveRange();
    final last = _lastLocalDayInSelectedRange();
    final picked = _recomputeDowntimeTargetDay;
    if (picked == null) return last;
    final p = _dayStart(picked.toLocal());
    final first = _dayStart(range.start);
    if (p.isBefore(first) || p.isAfter(last)) return last;
    return p;
  }

  DateTimeRange _resolveRange() {
    final now = DateTime.now();
    final todayStart = _dayStart(now);
    final tomorrow = todayStart.add(const Duration(days: 1));

    switch (_preset) {
      case _RangePreset.d0:
        return DateTimeRange(start: todayStart, end: tomorrow);
      case _RangePreset.d7:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 6)),
          end: tomorrow,
        );
      case _RangePreset.d30:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 29)),
          end: tomorrow,
        );
      case _RangePreset.d90:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 89)),
          end: tomorrow,
        );
      case _RangePreset.custom:
        final c = _customRange;
        if (c == null) {
          return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 6)),
            end: tomorrow,
          );
        }
        return DateTimeRange(
          start: _dayStart(c.start),
          end: _dayStart(c.end).add(const Duration(days: 1)),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    if (_canView) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = _resolveRange();
      final snap = await _service.load(
        companyId: _companyId,
        plantKey: _plantKey,
        rangeStart: r.start,
        rangeEndExclusive: r.end,
        includeRejected: _includeRejected,
      );
      if (mounted) {
        setState(() {
          _snap = snap;
          _loading = false;
          _backendAnalysisMarkdown = null;
          _backendAnalysisError = null;
          _recomputeDowntimeError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _runBackendAnalysis() async {
    final snap = _snap;
    if (snap == null || !_canRunBackendAnalysis) return;
    setState(() {
      _loadingBackendAnalysis = true;
      _backendAnalysisError = null;
    });
    try {
      final md = await _backendAi.runAnalysis(
        companyId: _companyId,
        plantKey: _plantKey,
        snapshot: snap,
      );
      if (mounted) {
        setState(() {
          _backendAnalysisMarkdown = md;
          _loadingBackendAnalysis = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendAnalysisError = e;
          _loadingBackendAnalysis = false;
        });
      }
    }
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked != null && mounted) {
      setState(() {
        _preset = _RangePreset.custom;
        _customRange = picked;
      });
      await _load();
    }
  }

  String _rangeLabel(OperonixAnalyticsSnapshot s) {
    final a = s.rangeStart;
    final b = s.rangeEndExclusive.subtract(const Duration(milliseconds: 1));
    return '${a.day.toString().padLeft(2, '0')}.'
        '${a.month.toString().padLeft(2, '0')}.'
        '${a.year} – '
        '${b.day.toString().padLeft(2, '0')}.'
        '${b.month.toString().padLeft(2, '0')}.'
        '${b.year}';
  }

  String _dayLabelDmy(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.'
        '${l.year}';
  }

  Widget? _serverDowntimeListSubtitle(
    AnalyticsDowntimeDailyModel e,
    ThemeData theme,
  ) {
    final parts = <String>[];
    if (e.computedAt != null) {
      final t = e.computedAt!.toLocal();
      parts.add(
        'Zadnji preračun: ${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}, ${_dayLabelDmy(e.computedAt!)}',
      );
    }
    final src = (e.recomputeSource ?? '').trim().toLowerCase();
    if (src == 'scheduled') {
      parts.add('Izvor: noćni raspored');
    } else if (src == 'callable') {
      parts.add('Izvor: Callable (ručno)');
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _pickRecomputeDowntimeDay() async {
    final range = _resolveRange();
    final first = _dayStart(range.start);
    final last = _lastLocalDayInSelectedRange();
    final now = DateTime.now();
    final lastCap = last.isAfter(now) ? _dayStart(now) : last;
    final initial = _recomputeDowntimeDayResolved();
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: lastCap,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(lastCap) ? lastCap : initial),
    );
    if (picked != null && mounted) {
      setState(() {
        _recomputeDowntimeTargetDay = _dayStart(picked);
      });
    }
  }

  Future<void> _recomputeDowntimeSummary() async {
    if (!_canRecomputeServerDowntimeSummary) return;
    if (_loading || _recomputingDowntimeSummary) return;
    setState(() {
      _recomputingDowntimeSummary = true;
      _recomputeDowntimeError = null;
    });
    try {
      final day = _recomputeDowntimeDayResolved();
      final ymd = AnalyticsDowntimeDailyCallableService.dateYmd(day);
      await _downtimeDailyCallable.recomputeDaily(
        companyId: _companyId,
        plantKey: _plantKey,
        summaryDateYmd: ymd,
        includeRejected: _includeRejected,
      );
      if (mounted) {
        await _load();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _recomputeDowntimeError = e;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recomputeDowntimeError = e;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _recomputingDowntimeSummary = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operonix Analytics')),
        body: const Center(
          child: Text(
            'Operonix Analytics je dostupan menadžeru proizvodnje, menadžeru održavanja, '
            'menadžeru logistike, adminu i super adminu.',
          ),
        ),
      );
    }

    final snap = _snap;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operonix Analytics'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && snap == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && snap == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(AppErrorMapper.toMessage(_error!)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'OperonixAI — jedan ekran za učinak, zastoje i kvalitet (TEEP + zastoji).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final p in _RangePreset.values)
                        ChoiceChip(
                          label: Text(p.label),
                          selected: _preset == p,
                          onSelected: (v) async {
                            if (!v) return;
                            if (p == _RangePreset.custom) {
                              await _pickCustom();
                              return;
                            }
                            setState(() => _preset = p);
                            await _load();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Uključi odbijene'),
                        selected: _includeRejected,
                        onSelected: (v) {
                          setState(() => _includeRejected = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                  if (snap != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Period: ${_rangeLabel(snap)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_canOpenDowntimeFromHere) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openLinkedDowntimeOperativa,
                            icon: const Icon(Icons.list_alt_outlined, size: 20),
                            label: const Text('Zastoji — operativa (ovaj period)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openLinkedDowntimeAnalitika,
                            icon: const Icon(Icons.analytics_outlined, size: 20),
                            label: const Text('Zastoji — puna analitika'),
                          ),
                        ],
                      ),
                    ],
                  ],
                  if (snap != null) ...[
                    if (snap.teepLoadFailed) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Napomena: TEEP dnevni sažetci nisu učitani (mreža / pravila). '
                        'Kartice OEE/OOE/TEEP mogu biti prazne; zastoji su i dalje iz izvornih događaja.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ] else if (snap.teepFromRecentScan) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Napomena: TEEP je učitan rezervnim putem (zadnjih 200 dokumenata). '
                        'Za duge periode otvori Firestore indeks (deploy) ili osloni se na zastoje.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'KPI (TEEP plant/day kada postoji; ostalo iz zastoja / količina)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _kpiRow(snap),
                    const SizedBox(height: 20),
                    AiInsightCard(insight: _narrator.buildInsight(snap)),
                    if (_canRunBackendAnalysis) ...[
                      const SizedBox(height: 16),
                      Card(
                        shape: operonixProductionCardShape(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.cloud_outlined,
                                    size: 22,
                                    color: kOperonixScadaAccentBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Gemini analiza (Callable runAiAnalysis)',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Isti backend kao „AI analiza — strukturirani podaci“. '
                                'Šalje se TEEP + Pareto zastoja u jedan OEE prompt (kvota pretplate).',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed:
                                    _loading || _loadingBackendAnalysis ? null : _runBackendAnalysis,
                                child: Text(
                                  _loadingBackendAnalysis
                                      ? 'Analiziram…'
                                      : 'Generiraj dublju analizu',
                                ),
                              ),
                              if (_backendAnalysisError != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  AppErrorMapper.toMessage(_backendAnalysisError!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                              if (_backendAnalysisMarkdown != null) ...[
                                const SizedBox(height: 12),
                                MarkdownBody(
                                  data: _backendAnalysisMarkdown!,
                                  selectable: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Trend OEE / OOE / TEEP (dnevno, pogon)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<OeeTrendMode>(
                      segments: const [
                        ButtonSegment(
                          value: OeeTrendMode.oee,
                          label: Text('OEE'),
                        ),
                        ButtonSegment(
                          value: OeeTrendMode.ooe,
                          label: Text('OOE'),
                        ),
                        ButtonSegment(
                          value: OeeTrendMode.teep,
                          label: Text('TEEP'),
                        ),
                      ],
                      selected: {_trendMode},
                      onSelectionChanged: (s) {
                        setState(() => _trendMode = s.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: OeeTrendLineChart(
                          plantDaysAsc: snap.plantDayTeepAsc,
                          mode: _trendMode,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pareto — kategorije zastoja (minute)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: DowntimeParetoChart(
                        rows: snap.report.paretoCategories,
                        totalMinutes: snap.report.totalMinutesClipped,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dnevno — minute zastoja (agregat)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: DowntimeDailyBars(buckets: snap.report.byDay),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Serverski dnevni sažetak (Firestore)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kolekcija analytics_downtime_daily — preračun u Europi (Callable). '
                      'Klijentski Pareto iznad i dalje čita live događaje; ovo je cache / izvještaji.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (snap.serverDowntimeDailyLoadFailed) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Sažetci za period nisu učitani (mreža, indeks ili pravila).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (snap.serverDowntimeDaily.isEmpty &&
                                !snap.serverDowntimeDailyLoadFailed)
                              Text(
                                'Nema sačuvanih dnevnih sažetaka u ovom periodu.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            else
                              for (final e in snap.serverDowntimeDaily.take(12))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    '${e.summaryDateYmd}  ·  ${e.totalMinutesClipped} min zastoja',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  subtitle: _serverDowntimeListSubtitle(e, theme),
                                ),
                            if (snap.serverDowntimeDaily.length > 12)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${snap.serverDowntimeDaily.length - 12} dana (skraćen prikaz)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (_canRecomputeServerDowntimeSummary) ...[
                              const SizedBox(height: 10),
                              const Divider(),
                              const SizedBox(height: 4),
                              Text(
                                'Preračun za jedan kalendar-dan (admin, menadžer proizvodnje, '
                                'menadžer održavanja, menadžer logistike)',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: _recomputingDowntimeSummary ? null : _pickRecomputeDowntimeDay,
                                    child: Text('Dan: ${_dayLabelDmy(_recomputeDowntimeDayResolved())}'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: (_loading || _recomputingDowntimeSummary)
                                        ? null
                                        : _recomputeDowntimeSummary,
                                    child: Text(
                                      _recomputingDowntimeSummary
                                          ? 'Preračunavam…'
                                          : 'Generiši / osvježi sažetak',
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Koriste se isti filtri kao gore (npr. uključeni odbijeni kada je uključeno).',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (_recomputeDowntimeError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppErrorMapper.toMessage(_recomputeDowntimeError!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Škart / količine (TEEP, agregat perioda)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Procjena FPY i scrap rate iz dnevnih TEEP dokumenata (dobro / ukupno).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: _scrapProcessList(snap.report),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Planirano vs stvarno (TEEP, prosjek dana s planom)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: ListTile(
                        title: Text(
                          snap.teepRollup.planVsActualPct == null
                              ? 'Nema dovoljno planiranih minuta u TEEP sažecima'
                              : '${snap.teepRollup.planVsActualPct!.toStringAsFixed(1)} % ostvarenja u odnosu na plan (run/plan, prosjek)',
                        ),
                        subtitle: const Text(
                          'Izvor: dnevni teep_summaries (pogon) — runTimeSeconds / plannedProductionTimeSeconds, '
                          'samo dani s planom > 0. Univerzalni poslovni „jedan dnevni dokument” za više KPI '
                          'ostaje u enterprise backlogu, ne u ovom ekranu.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Smjene — udio zastoja',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: operonixProductionCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ShiftLossHeatmapStrip(
                          byShift: snap.report.byShift,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Radni centri (rang po minutama zastoja — drill-down)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    WorkCenterRankingTable(
                      rows: snap.report.byWorkCenter,
                      onSelect: (g) {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AnalyticsWorkCenterDetailsScreen(
                              companyData: widget.companyData,
                              group: g,
                              rangeLabel: _rangeLabel(snap),
                              rangeStart: snap.rangeStart,
                              rangeEndExclusive: snap.rangeEndExclusive,
                              includeRejectedForDowntimeLinks: _includeRejected,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'IATF / kontinuirano poboljšanje',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ovaj ekran daje vidljiv trend, Pareto i akcije; zapis korektivnih aktivnosti ostaje u QMS (NCR / CAPA) kada je modul uključen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$kOperonixAiShortLabel: strukturirana analiza i chat s podacima u „OperonixAI“ hubu (pretplata).',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _kpiRow(OperonixAnalyticsSnapshot s) {
    final tr = s.teepRollup;
    final rep = s.report;
    String pct(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';
    String pcts(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AnalyticsKpiCard(
          label: 'OEE (TEEP prosjek)',
          value: tr.hasTeepData ? pct(tr.avgOee) : '—',
          subtitle: 'Plant / dan',
          icon: Icons.percent,
        ),
        AnalyticsKpiCard(
          label: 'OOE',
          value: tr.hasTeepData ? pct(tr.avgOoe) : '—',
          icon: Icons.speed,
        ),
        AnalyticsKpiCard(
          label: 'TEEP',
          value: tr.hasTeepData ? pct(tr.avgTeep) : '—',
          icon: Icons.calendar_month,
        ),
        AnalyticsKpiCard(
          label: 'Availability (OEE)',
          value: tr.hasTeepData ? pct(tr.avgAvailabilityOee) : '—',
          icon: Icons.timer_outlined,
        ),
        AnalyticsKpiCard(
          label: 'Performance',
          value: tr.hasTeepData ? pct(tr.avgPerformance) : '—',
          icon: Icons.trending_up,
        ),
        AnalyticsKpiCard(
          label: 'Quality',
          value: tr.hasTeepData ? pct(tr.avgQuality) : '—',
          icon: Icons.verified_outlined,
        ),
        AnalyticsKpiCard(
          label: 'Minute zastoja (ukupno)',
          value: '${rep.totalMinutesClipped}',
          subtitle: '${rep.eventsTouchingPeriod} događaja',
          icon: Icons.warning_amber_outlined,
        ),
        AnalyticsKpiCard(
          label: 'OEE gubitak (min)',
          value: '${rep.minutesOeeLoss}',
          icon: Icons.vertical_align_bottom,
        ),
        AnalyticsKpiCard(
          label: 'FPY (TEEP količine)',
          value: tr.fpy == null ? '—' : pcts(tr.fpy! * 100),
          subtitle: 'Dobro / ukupno (TEEP, suma dana)',
          icon: Icons.check_circle_outline,
        ),
        AnalyticsKpiCard(
          label: 'Scrap rate',
          value: tr.scrapRate == null ? '—' : pcts(tr.scrapRate! * 100),
          icon: Icons.delete_outline,
        ),
        AnalyticsKpiCard(
          label: 'MTTR (min, zatvoreno)',
          value: rep.mttrMinutesResolved == null
              ? '—'
              : rep.mttrMinutesResolved!.toStringAsFixed(0),
          icon: Icons.build_outlined,
        ),
        AnalyticsKpiCard(
          label: 'COPQ (€)',
          value: '—',
          subtitle: 'Fin. sloj (uskoro)',
          icon: Icons.euro,
        ),
        AnalyticsKpiCard(
          label: 'Plan / actual (%)',
          value: tr.planVsActualPct == null
              ? '—'
              : '${tr.planVsActualPct!.toStringAsFixed(1)}%',
          icon: Icons.compare_arrows,
        ),
      ],
    );
  }

  static Widget _scrapProcessList(DowntimeAnalyticsReport rep) {
    final items = rep.byProcess.take(10).toList();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nema agregata po procesu (povežite zastoje s procesom).'),
      );
    }
    return Column(
      children: [
        for (final p in items)
          ListTile(
            dense: true,
            title: Text(
              p.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${p.events} zastoja'),
            trailing: Text(
              '${p.minutesClipped} min',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
