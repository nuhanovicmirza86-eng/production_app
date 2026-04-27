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
import '../widgets/waste_report_error_panel.dart';
import '../widgets/waste_report_period_summary_card.dart';

/// Otpad po proizvodu (dnevna agregacija: dobar komad vs. škart).
class WasteByProductReportScreen extends StatefulWidget {
  const WasteByProductReportScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WasteByProductReportScreen> createState() =>
      _WasteByProductReportScreenState();
}

class _WasteByProductReportScreenState extends State<WasteByProductReportScreen> {
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

  static String _dateShortLabel(String ymd) {
    final p = ymd.split('-');
    if (p.length == 3) {
      return '${p[2]}.${p[1]}.';
    }
    return ymd;
  }

  Future<void> _exportCsv() async {
    try {
      final rows = aggregateWasteByProductPerDay(_entries);
      final period = summarizeWasteQualityPeriod(_entries);
      final csv = WasteQualityReportCsvShare.buildProductCsv(
        plantLabel: _plantDisplay,
        rangeLabel: _rangeLabel,
        rows: rows,
        period: period,
      );
      await WasteQualityReportCsvShare.share(
        fileBaseName: 'otpad_po_proizvodu_$_rangeFileStamp',
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
      final rows = aggregateWasteByProductPerDay(_entries);
      final period = summarizeWasteQualityPeriod(_entries);
      final bytes = WasteQualityReportExcelExport.buildProductXlsx(
        plantLabel: _plantDisplay,
        rangeLabel: _rangeLabel,
        rows: rows,
        period: period,
      );
      await WasteQualityReportExcelExport.share(
        fileBaseName: 'otpad_po_proizvodu_$_rangeFileStamp',
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
    final rows = aggregateWasteByProductPerDay(_entries);
    final period = summarizeWasteQualityPeriod(_entries);
    final hasExportable = _ready && _error == null;

    if (!_ready && _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Otpad po proizvodu (dnevna proizvodnja)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otpad po proizvodu (dnevna proizvodnja)'),
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
                          'Pogon: $_plantDisplay · svi točni unosi u operativnom praćenju (tri faze) za taj pogon i period.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                        const SizedBox(height: 16),
                        WasteReportPeriodSummaryCard(summary: period),
                        if (rows.isEmpty)
                          Text(
                            'Nema operativnih unosa u tom periodu.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 520),
                              child: DataTable(
                                columnSpacing: 20,
                                columns: const [
                                  DataColumn(label: Text('Dan')),
                                  DataColumn(label: Text('Proizvod')),
                                  DataColumn(
                                    label: Text('Dobro'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Škart'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Otpad %'),
                                    numeric: true,
                                  ),
                                ],
                                rows: [
                                  for (final r in rows)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            _dateShortLabel(r.workDateKey),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 200,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  r.productLine,
                                                ),
                                                if (r.subLine != null)
                                                  Text(
                                                    r.subLine!,
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(_fmt(r.goodQty))),
                                        DataCell(Text(_fmt(r.scrapQty))),
                                        DataCell(
                                          Text(
                                            '${r.defectPct.toStringAsFixed(1)}%',
                                            style: r.defectPct >= 5
                                                ? TextStyle(
                                                    color: theme
                                                        .colorScheme.error,
                                                    fontWeight: FontWeight.w600,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Dobro = pripremljena količina (ukupno minus škart). '
                          'Agregacija je po radnom danu: smjene nisu u zasebnom polju, '
                          'pa usporedba „po danu“ znači po datumu unosa (radni list).',
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

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
