import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../config/platform_defect_codes.dart';
import '../export/waste_quality_report_csv_share.dart';
import '../export/waste_quality_report_excel_export.dart';
import '../models/production_operator_tracking_entry.dart';
import '../services/production_operator_tracking_service.dart';
import '../services/production_tracking_analytics_service.dart';
import '../services/tracking_effective_plant_key.dart';
import '../services/waste_quality_reports_aggregator.dart';
import '../widgets/waste_report_error_panel.dart';
import '../widgets/waste_report_period_summary_card.dart';

/// Otpad po tipu škarta — agregacija [`scrapBreakdown`] u odabranom periodu za pogon.
class WasteByScrapTypeReportScreen extends StatefulWidget {
  const WasteByScrapTypeReportScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WasteByScrapTypeReportScreen> createState() =>
      _WasteByScrapTypeReportScreenState();
}

class _WasteByScrapTypeReportScreenState
    extends State<WasteByScrapTypeReportScreen> {
  final _tracking = ProductionOperatorTrackingService();
  ProductionTrackingRangeMode _mode = ProductionTrackingRangeMode.thisWeek;
  bool _loading = true;
  bool _ready = false;
  Object? _error;
  List<ProductionOperatorTrackingEntry> _entries = const [];
  String _plantDisplay = '—';
  String _rangeLabel = '';
  String _rangeFileStamp = '';

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
        _rangeFileStamp = sKey;
      });

      final list = await _tracking.fetchAllPhasesDateRangeMerged(
        companyId: cid,
        plantKey: plantKey,
        startWorkDate: sKey,
        endWorkDate: eKey,
      );
      final plantLabel = await CompanyPlantDisplayName.resolve(
        companyId: cid,
        plantKey: plantKey,
      );
      if (!mounted) return;
      setState(() {
        _entries = list;
        _plantDisplay = plantLabel;
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

  Future<void> _exportCsv() async {
    try {
      final names = parseDefectDisplayNamesMap(widget.companyData);
      final rows = aggregateWasteByScrapType(
        entries: _entries,
        defectDisplayNames: names,
      );
      final period = summarizeWasteQualityPeriod(_entries);
      final csv = WasteQualityReportCsvShare.buildScrapTypeCsv(
        plantLabel: _plantDisplay,
        rangeLabel: _rangeLabel,
        rows: rows,
        period: period,
      );
      await WasteQualityReportCsvShare.share(
        fileBaseName: 'otpad_po_tipu_$_rangeFileStamp',
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
      final names = parseDefectDisplayNamesMap(widget.companyData);
      final rows = aggregateWasteByScrapType(
        entries: _entries,
        defectDisplayNames: names,
      );
      final period = summarizeWasteQualityPeriod(_entries);
      final bytes = WasteQualityReportExcelExport.buildScrapTypeXlsx(
        plantLabel: _plantDisplay,
        rangeLabel: _rangeLabel,
        rows: rows,
        period: period,
      );
      await WasteQualityReportExcelExport.share(
        fileBaseName: 'otpad_po_tipu_$_rangeFileStamp',
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
    final names = parseDefectDisplayNamesMap(widget.companyData);
    final rows = aggregateWasteByScrapType(
      entries: _entries,
      defectDisplayNames: names,
    );
    final period = summarizeWasteQualityPeriod(_entries);
    var totalScrap = 0.0;
    for (final e in _entries) {
      totalScrap += e.scrapTotalQty;
    }
    final hasExportable = _ready && _error == null;

    if (!_ready && _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Otpad po tipu škarta')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otpad po tipu škarta'),
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
                PopupMenuItem(
                  value: 'csv',
                  child: Text('Dijeli CSV'),
                ),
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
                ? WasteReportErrorPanel(
                    message: _error,
                    onRetry: _load,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          'Pogon: $_plantDisplay.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _rangeLabel,
                          style: theme.textTheme.titleSmall,
                        ),
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
                            setState(() {
                              _mode = s.first;
                            });
                            _load();
                          },
                        ),
                        const SizedBox(height: 20),
                        WasteReportPeriodSummaryCard(summary: period),
                        if (rows.isEmpty) ...[
                          if (period.entryCount == 0)
                            Text(
                              'Nema operativnih unosa u tom periodu.',
                              style: theme.textTheme.bodyMedium,
                            )
                          else
                            Text(
                              'Postoje unosi, ali nema evidentiranog škarta (ukupno škart: ${_fmtNum(totalScrap)}).',
                              style: theme.textTheme.bodyMedium,
                            ),
                        ] else ...[
                          Text(
                            'Ukupno škarta po tipu: ${_fmtNum(totalScrap)} (udio po redu ispod odnosi se na taj zbroj).',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          _BarList(rows: rows, maxQty: rows.first.qty),
                          const SizedBox(height: 16),
                          const Divider(),
                          for (final r in rows)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(r.label),
                              trailing: Text(
                                '${_fmtNum(r.qty)} · ${r.pctOfTotalScrap.toStringAsFixed(1)}%',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Izvor: sva tri toka (pripremna, prva, završna kontrola) u operativnom praćenju.',
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

class _BarList extends StatelessWidget {
  const _BarList({required this.rows, required this.maxQty});

  final List<WasteByScrapTypeRow> rows;
  final double maxQty;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxQty > 0 ? (r.qty / maxQty).clamp(0.0, 1.0) : 0,
                    minHeight: 10,
                    backgroundColor: color.withValues(alpha: 0.12),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
