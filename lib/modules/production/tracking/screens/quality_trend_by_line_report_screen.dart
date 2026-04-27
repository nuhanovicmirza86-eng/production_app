import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../export/waste_quality_report_csv_share.dart';
import '../export/waste_quality_report_excel_export.dart';
import '../models/production_operator_tracking_entry.dart';
import '../services/production_operator_tracking_service.dart';
import '../services/production_tracking_analytics_service.dart';
import '../services/tracking_effective_plant_key.dart';
import '../services/waste_quality_reports_aggregator.dart';
import '../widgets/defect_pct_sparkline.dart';
import '../widgets/waste_report_error_panel.dart';
import '../widgets/waste_report_period_summary_card.dart';
import '../../work_centers/services/work_center_service.dart';

/// Trend kvaliteta (otpad % ) po proizvodnoj liniji = po [workCenterId] u unosima, uz šifarnik RC.
class QualityTrendByLineReportScreen extends StatefulWidget {
  const QualityTrendByLineReportScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<QualityTrendByLineReportScreen> createState() =>
      _QualityTrendByLineReportScreenState();
}

class _QualityTrendByLineReportScreenState
    extends State<QualityTrendByLineReportScreen> {
  final _tracking = ProductionOperatorTrackingService();
  final _workCenters = WorkCenterService();
  ProductionTrackingRangeMode _mode = ProductionTrackingRangeMode.thisWeek;
  bool _loading = true;
  bool _ready = false;
  Object? _error;
  List<ProductionOperatorTrackingEntry> _entries = const [];
  Map<String, String> _wcTitles = const {};
  List<String> _dateKeys = const [];
  String _plantDisplay = '—';
  String _rangeLabel = '';
  String _rangeFileStamp = '';
  bool _anyUnknownCenter = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime start, DateTime end) _rangeForMode() {
    final now = DateTime.now();
    switch (_mode) {
      case ProductionTrackingRangeMode.thisWeek:
        return ProductionTrackingAnalyticsService.currentWeekRange(now);
      case ProductionTrackingRangeMode.thisMonth:
        return ProductionTrackingAnalyticsService.monthToDateRange(now);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final cid = _companyId;
    try {
      final plantKey = await resolveEffectiveTrackingPlantKey(widget.companyData);
      if (plantKey == null || plantKey.isEmpty) {
        throw StateError('Nije odabran pogon. Odaberi pogon u postavkama stanice ili profilu.');
      }
      final (start, end) = _rangeForMode();
      final sKey = ProductionTrackingAnalyticsService.workDateKey(start);
      final eKey = ProductionTrackingAnalyticsService.workDateKey(end);
      if (!mounted) return;
      setState(() {
        _rangeLabel =
            '${BaFormattedDate.formatFullDate(start)} – ${BaFormattedDate.formatFullDate(end)}';
        _dateKeys = enumerateWorkDateKeysInRange(start, end);
        _rangeFileStamp = sKey;
      });

      var titles = <String, String>{};
      final wcs = await _workCenters.listWorkCentersForPlant(
        companyId: cid,
        plantKey: plantKey,
        onlyActive: false,
        limit: 500,
      );
      for (final w in wcs) {
        final t = '${w.workCenterCode} — ${w.name}'.trim();
        if (t.isNotEmpty) titles[w.id] = t;
      }

      final list = await _tracking.fetchAllPhasesDateRangeMerged(
        companyId: cid,
        plantKey: plantKey,
        startWorkDate: sKey,
        endWorkDate: eKey,
      );

      final missing = <String>{};
      for (final e in list) {
        final id = (e.workCenterId ?? '').trim();
        if (id.isNotEmpty && !titles.containsKey(id)) {
          missing.add(id);
        }
      }
      if (missing.isNotEmpty) {
        final ids = missing.toList()..sort();
        final resolved = await Future.wait(
          ids.map(
            (id) => _workCenters.getById(
              companyId: cid,
              plantKey: plantKey,
              workCenterId: id,
            ),
          ),
        );
        for (var i = 0; i < ids.length; i++) {
          final wc = resolved[i];
          if (wc != null) {
            final t = '${wc.workCenterCode} — ${wc.name}'.trim();
            if (t.isNotEmpty) titles = {...titles, ids[i]: t};
          }
        }
      }

      var unknown = false;
      for (final e in list) {
        final id = (e.workCenterId ?? '').trim();
        if (id.isNotEmpty && !titles.containsKey(id)) {
          unknown = true;
        }
      }

      final plantLabel = await CompanyPlantDisplayName.resolve(
        companyId: cid,
        plantKey: plantKey,
      );
      if (!mounted) return;
      setState(() {
        _entries = list;
        _plantDisplay = plantLabel;
        _wcTitles = titles;
        _anyUnknownCenter = unknown;
        _loading = false;
        _error = null;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _ready = true;
      });
    }
  }

  String _resolveLineTitle(String? workCenterId) {
    if (workCenterId == null || workCenterId.isEmpty) {
      return 'Bez radnog centra (linija nije povezana u unosu)';
    }
    return _wcTitles[workCenterId] ?? 'Radni centar nije u šifarniku';
  }

  static String _dayShort(String ymd) {
    final p = ymd.split('-');
    if (p.length == 3) {
      return '${p[2]}.${p[1]}.';
    }
    return ymd;
  }

  Future<void> _exportCsv() async {
    try {
      final series = aggregateQualityTrendByLine(
        entries: _entries,
        workDateKeysChronological: _dateKeys,
        resolveLineTitle: _resolveLineTitle,
      );
      final period = summarizeWasteQualityPeriod(_entries);
      final csv = WasteQualityReportCsvShare.buildQualityTrendCsv(
        plantLabel: _plantDisplay,
        rangeLabel: _rangeLabel,
        series: series,
        period: period,
      );
      await WasteQualityReportCsvShare.share(
        fileBaseName: 'trend_kvaliteta_rc_$_rangeFileStamp',
        csvBody: csv,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Izvoz nije uspio: $e')),
      );
    }
  }

  Future<void> _exportXlsx() async {
    try {
      final series = aggregateQualityTrendByLine(
        entries: _entries,
        workDateKeysChronological: _dateKeys,
        resolveLineTitle: _resolveLineTitle,
      );
      final period = summarizeWasteQualityPeriod(_entries);
      final bytes = WasteQualityReportExcelExport.buildQualityTrendXlsx(
        plantLabel: _plantDisplay,
        rangeLabel: _rangeLabel,
        series: series,
        period: period,
      );
      await WasteQualityReportExcelExport.share(
        fileBaseName: 'trend_kvaliteta_rc_$_rangeFileStamp',
        xlsxBytes: bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Izvoz nije uspio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = aggregateQualityTrendByLine(
      entries: _entries,
      workDateKeysChronological: _dateKeys,
      resolveLineTitle: _resolveLineTitle,
    );
    final period = summarizeWasteQualityPeriod(_entries);
    final hasExportable = _ready && _error == null;
    final sparkLabels = _dateKeys.map(_dayShort).toList();

    if (!_ready && _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trend kvaliteta po proizvodnoj liniji')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trend kvaliteta po proizvodnoj liniji'),
        actions: [
          if (hasExportable)
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: 'Izvoz (CSV / Excel)',
              onSelected: (v) {
                if (v == 'csv') {
                  _exportCsv();
                } else if (v == 'xlsx') {
                  _exportXlsx();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'csv', child: Text('Dijeli CSV')),
                PopupMenuItem(
                  value: 'xlsx',
                  child: Text('Dijeli Excel (.xlsx)'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? WasteReportErrorPanel(message: _error, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          'Pogon: $_plantDisplay. Povezivanje: polje radnog centra (MES) u unosima operativnog praćenja.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_anyUnknownCenter) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Dio unosa povezuje se na zapis u šifarniku koji trenutno nije učitan — linija se prikazuje kao nepoznata (bez tehničkog ID-a u sučelju).',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(_rangeLabel, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 12),
                        SegmentedButton<ProductionTrackingRangeMode>(
                          segments: const [
                            ButtonSegment<ProductionTrackingRangeMode>(
                              value: ProductionTrackingRangeMode.thisWeek,
                              label: Text('Ovaj tjedan'),
                            ),
                            ButtonSegment<ProductionTrackingRangeMode>(
                              value: ProductionTrackingRangeMode.thisMonth,
                              label: Text('Ovaj mjesec'),
                            ),
                          ],
                          selected: <ProductionTrackingRangeMode>{_mode},
                          onSelectionChanged: (s) {
                            if (s.isEmpty) return;
                            setState(() => _mode = s.first);
                            _load();
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'KPI: prosjek dnevnog otpada % po liniji; naglašeno kad je u danu otpad % ≥ 5 i iznad 120% prosjeka te linije (samo dani s proizvodnjom u broju).',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        WasteReportPeriodSummaryCard(summary: period),
                        if (series.isEmpty)
                          const Text('Nema operativnih unosa u tom periodu.')
                        else
                          for (final s in series)
                            _LineCard(
                              series: s,
                              dayLabel: _dayShort,
                              sparkLabels: sparkLabels,
                            ),
                        const SizedBox(height: 8),
                        Text(
                          'Graf: dnevni otpad % (Y) u cijelom prozoru. Tablica: dani s proizvodnjom. '
                          'Prosjek linije = srednja vrijednost dnevnog otpada % na danima s proizvodnjom (dobro+škart > 0).',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.series,
    required this.dayLabel,
    required this.sparkLabels,
  });

  final QualityLineSeries series;
  final String Function(String ymd) dayLabel;
  final List<String> sparkLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = series.periodAvgDefect;
    final values = [for (final p in series.points) p.defectPct];
    final dayRows = <Widget>[];
    for (final p in series.points) {
      if (p.goodQty + p.scrapQty <= 0) continue;
      final dev = QualityLineSeries.isDeviation(
        dayDefectPct: p.defectPct,
        periodAvg: avg,
      );
      dayRows.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          dense: true,
          title: Text(dayLabel(p.workDateKey)),
          trailing: Text(
            '${p.defectPct.toStringAsFixed(1)}% '
            '(${_fmtP(p.scrapQty)} / ${_fmtP(p.goodQty + p.scrapQty)})',
            style: TextStyle(
              color: dev ? theme.colorScheme.tertiary : null,
              fontWeight: dev ? FontWeight.w600 : null,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              series.lineTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text('Prosj. otpad u periodu: ${avg.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            if (values.isNotEmpty) ...[
              DefectPctSparkline(values: values, labels: sparkLabels),
              const SizedBox(height: 4),
            ],
            if (dayRows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nema dana s proizvodnjom u periodu za ovu liniju.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: dayRows,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _fmtP(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
