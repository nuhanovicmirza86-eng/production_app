import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/operational_business_year_context.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../ooe/screens/ooe_daily_overview_screen.dart';
import '../../ooe/screens/ooe_dashboard_screen.dart';
import '../../ooe/services/ooe_machine_target_service.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../../work_centers/services/work_center_service.dart';
import '../analytics/downtime_analytics_engine.dart';
import '../analytics/downtime_machine_target_row.dart';
import '../export/downtime_analytics_budget_store.dart';
import '../export/downtime_analytics_export.dart';
import '../export/downtime_analytics_pdf.dart';
import '../models/downtime_event_model.dart';
import '../services/downtime_service.dart';

enum _RangePreset {
  d7('7 dana'),
  d30('30 dana'),
  d90('90 dana'),
  mtd('Mjesec do danas'),
  operationalFy('Poslovna godina'),
  custom('Prilagođeno…');

  final String label;
  const _RangePreset(this.label);
}

/// Puna analitika zastoja: period, OEE/OOE/TEEP, Pareto, radni centri, dnevni graf, CSV.
class DowntimeAnalyticsTab extends StatefulWidget {
  const DowntimeAnalyticsTab({
    super.key,
    required this.companyData,
    this.initialRangeStart,
    this.initialRangeEndExclusive,
    this.initialIncludeRejected,
  });

  final Map<String, dynamic> companyData;

  /// Ako su oba zadana (npr. s Operonix Analytics), učitava se [custom] s ovim [rangeStart, rangeEndExclusive) lokalno.
  final DateTime? initialRangeStart;
  final DateTime? initialRangeEndExclusive;

  /// Uskladi s Operonix (filterčip) kad je prosljeđeno.
  final bool? initialIncludeRejected;

  @override
  State<DowntimeAnalyticsTab> createState() => _DowntimeAnalyticsTabState();
}

class _DowntimeAnalyticsTabState extends State<DowntimeAnalyticsTab> {
  final _service = DowntimeService();
  final _budgetCtrl = TextEditingController();

  _RangePreset _preset = _RangePreset.d30;
  DateTimeRange? _customRange;
  bool _includeRejected = false;
  OperationalFyBounds? _operationalFyBounds;
  bool _loading = false;
  Object? _loadError;
  DowntimeAnalyticsReport? _report;
  List<DowntimeMachineTargetRow> _machineTargetRows = const [];
  String _plantDisplayName = '';
  int? _oeeBudgetMinutes;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canViewOoe =>
      ProductionAccessHelper.canView(role: _role, card: ProductionDashboardCard.ooe);

  @override
  void initState() {
    super.initState();
    final rs = widget.initialRangeStart;
    final re = widget.initialRangeEndExclusive;
    if (rs != null && re != null) {
      if (widget.initialIncludeRejected != null) {
        _includeRejected = widget.initialIncludeRejected!;
      }
      _preset = _RangePreset.custom;
      final s = _dayStart(rs.toLocal());
      final lastInc = re.toLocal().subtract(const Duration(milliseconds: 1));
      _customRange = DateTimeRange(
        start: s,
        end: _dayStart(lastInc),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final b = await OperationalBusinessYearContext.resolveBoundsForCompany(
        companyId: _companyId,
      );
      if (!mounted) return;
      setState(() => _operationalFyBounds = b);
      // ignore: discarded_futures
      _load();
    });
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTimeRange _resolveRange() {
    final now = DateTime.now();
    final todayStart = _dayStart(now);
    final tomorrow = todayStart.add(const Duration(days: 1));

    switch (_preset) {
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
      case _RangePreset.mtd:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: tomorrow,
        );
      case _RangePreset.operationalFy:
        final b = _operationalFyBounds;
        if (b == null) {
          return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 29)),
            end: tomorrow,
          );
        }
        return DateTimeRange(
          start: _dayStart(b.startLocalInclusive),
          end: b.endLocalExclusive,
        );
      case _RangePreset.custom:
        final c = _customRange;
        if (c == null) {
          return DateTimeRange(start: todayStart.subtract(const Duration(days: 29)), end: tomorrow);
        }
        return DateTimeRange(
          start: _dayStart(c.start),
          end: _dayStart(c.end).add(const Duration(days: 1)),
        );
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
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

  Future<void> _load() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = _resolveRange();
      final raw = await _service.fetchEventsForAnalytics(
        companyId: _companyId,
        plantKey: _plantKey,
        rangeStartLocal: r.start,
        rangeEndExclusiveLocal: r.end,
      );
      final rep = DowntimeAnalyticsReport.compute(
        events: raw,
        rangeStart: r.start,
        rangeEndExclusive: r.end,
        now: DateTime.now(),
        includeRejected: _includeRejected,
      );

      final ooeTargets = OoeMachineTargetService();
      final wcSvc = WorkCenterService();
      final assetsSvc = ProductionTrackingAssetsService();

      final targets = await ooeTargets.loadTargetOoeByMachineForPlant(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      final wcs = await wcSvc.listWorkCentersForPlant(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      final assets = await assetsSvc.loadForPlant(
        companyId: _companyId,
        plantKey: _plantKey,
        limit: 128,
      );
      final plantLabel = await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      final budget = await DowntimeAnalyticsBudgetStore.load(
        companyId: _companyId,
        plantKey: _plantKey,
      );

      final machineLabels = <String, String>{
        for (final m in assets.machines) m.id: m.title,
      };
      final wcRecords = wcs
          .map(
            (w) => (
              id: w.id,
              linkedAssetId: w.linkedAssetId,
              label: '${w.workCenterCode} · ${w.name}',
            ),
          )
          .toList();
      final mtRows = buildDowntimeMachineTargetRows(
        report: rep,
        targetOoeByMachineId: targets,
        workCenters: wcRecords,
        machineLabelById: machineLabels,
      );

      if (!mounted) return;
      if (budget != null && _budgetCtrl.text.trim().isEmpty) {
        _budgetCtrl.text = '$budget';
      }
      setState(() {
        _report = rep;
        _machineTargetRows = mtRows;
        _plantDisplayName = plantLabel;
        _oeeBudgetMinutes = budget;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Widget _kpi(String title, String value, {IconData? icon}) {
    return Card(
      shape: operonixProductionCardShape(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: kOperonixScadaAccentBlue),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return const Center(child: Text('Nedostaje kontekst kompanije ili pogona.'));
    }

    if (_loading && _report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppErrorMapper.toMessage(_loadError!)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
            ],
          ),
        ),
      );
    }

    final rep = _report;
    if (rep == null) {
      return const SizedBox.shrink();
    }

    final range = _resolveRange();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Period: ${_fmtDate(range.start)} — ${_fmtDate(range.end.subtract(const Duration(days: 1)))}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _RangePreset.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _preset == p,
                  onSelected: (s) async {
                    if (!s) return;
                    if (p == _RangePreset.custom) {
                      await _pickCustomRange();
                    } else {
                      setState(() => _preset = p);
                      await _load();
                    }
                  },
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Uključi odbijene u analitiku'),
            value: _includeRejected,
            onChanged: (v) async {
              setState(() => _includeRejected = v);
              await _load();
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Osvježi'),
              ),
              OutlinedButton.icon(
                onPressed: () => DowntimeAnalyticsPdf.sharePdf(
                  report: rep,
                  companyId: _companyId,
                  plantKey: _plantKey,
                  plantDisplayName: _plantDisplayName,
                  machineTargetRows: _machineTargetRows,
                  oeeBudgetMinutes: _oeeBudgetMinutes,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => DowntimeAnalyticsExport.shareCsv(
                  report: rep,
                  companyId: _companyId,
                  plantKey: _plantKey,
                ),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('CSV'),
              ),
              if (_canViewOoe) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => OoeDailyOverviewScreen(
                          companyData: widget.companyData,
                          initialDay: range.start,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_view_day_outlined),
                  label: const Text('OOE dnevno'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => OoeDashboardScreen(
                          companyData: widget.companyData,
                          analyticsContextHint:
                              'Zastoji: ${_fmtDate(range.start)} — ${_fmtDate(range.end.subtract(const Duration(days: 1)))}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.speed_outlined),
                  label: const Text('OOE live'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Buffer dohvata: 120 dana prije početka perioda (dugi otvoreni zastoji).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: operonixProductionCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referentni cilj — gubitak OEE (minute u periodu)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Interni budžet za „cilj vs ostvareno“; sprema se po pogonu.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _budgetCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cilj (minute OEE gubitka)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final v = int.tryParse(_budgetCtrl.text.trim());
                          await DowntimeAnalyticsBudgetStore.save(
                            companyId: _companyId,
                            plantKey: _plantKey,
                            budgetMinutes: v,
                          );
                          if (!context.mounted) return;
                          setState(() {
                            _oeeBudgetMinutes = v != null && v > 0 ? v : null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cilj spremljen.')),
                          );
                        },
                        child: const Text('Spremi'),
                      ),
                    ],
                  ),
                  if (_oeeBudgetMinutes != null && _oeeBudgetMinutes! > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ostvareno: ${rep.minutesOeeLoss} / $_oeeBudgetMinutes min',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (ctx) {
                        final b = _oeeBudgetMinutes!;
                        final r = b > 0 ? rep.minutesOeeLoss / b : 0.0;
                        final over = r > 1.0;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: r.clamp(0.0, 1.0),
                            minHeight: 10,
                            color: over ? Colors.red.shade700 : null,
                            backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          ),
                        );
                      },
                    ),
                    if (rep.minutesOeeLoss > _oeeBudgetMinutes!)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Prekoračenje cilja za ${rep.minutesOeeLoss - _oeeBudgetMinutes!} min.',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 1000 ? 4 : (w >= 700 ? 3 : (w >= 440 ? 2 : 1));
              final tileW = (w - (cols - 1) * 8) / cols;
              Widget grid(List<Widget> ch) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ch
                    .map((e) => SizedBox(width: tileW, child: e))
                    .toList(),
              );
              return grid([
                _kpi('Zastoja (min. u periodu)', '${rep.eventsTouchingPeriod}', icon: Icons.event_busy_outlined),
                _kpi('Ukupno min', '${rep.totalMinutesClipped}', icon: Icons.timer_outlined),
                _kpi('Gubitak OEE (min)', '${rep.minutesOeeLoss}', icon: Icons.percent_outlined),
                _kpi('Gubitak OOE (min)', '${rep.minutesOoeLoss}', icon: Icons.speed_outlined),
                _kpi('Gubitak TEEP (min)', '${rep.minutesTeepLoss}', icon: Icons.calendar_month_outlined),
                _kpi('Planirano (min)', '${rep.plannedMinutes}', icon: Icons.event_available_outlined),
                _kpi('Neplanirano (min)', '${rep.unplannedMinutes}', icon: Icons.warning_amber_outlined),
                _kpi(
                  'MTTR (min, prosjek)',
                  rep.mttrMinutesResolved == null
                      ? '—'
                      : rep.mttrMinutesResolved!.toStringAsFixed(1),
                  icon: Icons.build_outlined,
                ),
                _kpi('Verificirano (zapisi)', '${rep.verifiedCount}', icon: Icons.verified_outlined),
                _kpi('CAPA flag', '${rep.correctiveActionFlagged}', icon: Icons.assignment_turned_in_outlined),
              ]);
            },
          ),
          if (_machineTargetRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(title: 'Cilj OOE (stroj) i OEE gubitak (zastoji)'),
            const SizedBox(height: 4),
            Text(
              'Cilj iz OOE kataloga; zastoji agregirani preko radnog centra povezanog s assetom.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: operonixProductionCardShape(),
              child: Column(
                children: [
                  for (final row in _machineTargetRows)
                    ListTile(
                      dense: true,
                      title: Text(row.machineLabel),
                      subtitle: Text(
                        'Cilj OOE ${downtimeMachineTargetOoeLabel(row.targetOoeFraction)} · ${row.workCenterLabel}',
                      ),
                      trailing: Text(
                        '${row.oeeLossMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_canViewOoe) ...[
            const SizedBox(height: 8),
            Text(
              'OOE dnevno otvara isti početni datum kao period analize; OOE live vodi na live pregled pogona.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SectionTitle(title: 'Dnevno — ukupno minuta (u periodu)'),
          const SizedBox(height: 8),
          Card(
            shape: operonixProductionCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: rep.byDay.isEmpty
                  ? const Text('Nema podataka za graf.')
                  : SizedBox(
                      height: 200,
                      child: _DailyMinutesBarChart(buckets: rep.byDay),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Pareto — kategorije (minuta)'),
          const SizedBox(height: 8),
          Card(
            shape: operonixProductionCardShape(),
            child: rep.paretoCategories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nema podataka.'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rep.paretoCategories.length && i < 12; i++)
                        _paretoRow(rep.paretoCategories[i], rep.totalMinutesClipped),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Radni centri'),
          const SizedBox(height: 8),
          _groupCard(rep.byWorkCenter.take(12).toList()),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Procesi'),
          const SizedBox(height: 8),
          _groupCard(rep.byProcess.take(12).toList()),
          if (rep.byShift.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(title: 'Smjene'),
            const SizedBox(height: 8),
            _groupCard(rep.byShift.take(12).toList()),
          ],
          if (rep.repeatReasons.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(title: 'Ponavljajući razlozi'),
            const SizedBox(height: 8),
            Card(
              shape: operonixProductionCardShape(),
              child: Column(
                children: [
                  for (final r in rep.repeatReasons.take(15))
                    ListTile(
                      dense: true,
                      title: Text(r.reason),
                      subtitle: Text('${r.occurrences}× · ${r.totalMinutesClipped} min'),
                    ),
                ],
              ),
            ),
          ],
          if (rep.minutesBySeverity.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(title: 'Kritičnost (minuta u periodu)'),
            const SizedBox(height: 8),
            Card(
              shape: operonixProductionCardShape(),
              child: Column(
                children: [
                  for (final e in rep.minutesBySeverity.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                    ListTile(
                      dense: true,
                      title: Text(DowntimeSeverity.labelHr(e.key)),
                      trailing: Text('${e.value} min'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Widget _paretoRow(DowntimeParetoRow row, int total) {
    final w = total > 0 ? row.minutes / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.label, maxLines: 2, overflow: TextOverflow.ellipsis)),
              Text('${row.minutes} min'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: w.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
          Text(
            '${row.pctOfTotalMinutes.toStringAsFixed(1)}% · kumulativno ${row.cumulativePct.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(List<DowntimeGroupStats> items) {
    if (items.isEmpty) {
      return Card(
        shape: operonixProductionCardShape(),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nema podataka.'),
        ),
      );
    }
    return Card(
      shape: operonixProductionCardShape(),
      child: Column(
        children: [
          for (final g in items)
            ListTile(
              dense: true,
              title: Text(g.label, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${g.events} zastoja · OEE ${g.minutesOee} · OOE ${g.minutesOoe} · TEEP ${g.minutesTeep}',
              ),
              trailing: Text(
                '${g.minutesClipped} min',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DailyMinutesBarChart extends StatelessWidget {
  const _DailyMinutesBarChart({required this.buckets});

  final List<DowntimeDailyBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final vals = buckets.map((e) => e.minutesClipped.toDouble()).toList();
    final labels = buckets
        .map(
          (e) =>
              '${e.dayLocal.day.toString().padLeft(2, '0')}.${e.dayLocal.month.toString().padLeft(2, '0')}',
        )
        .toList();
    return CustomPaint(
      painter: _VerticalBarPainter(
        values: vals,
        labels: labels,
        color: kOperonixScadaAccentBlue,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _VerticalBarPainter extends CustomPainter {
  _VerticalBarPainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV * 1.08;
    final barW = n > 0 ? (size.width - 16) / n : 0.0;
    final h = size.height - 22;

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final bh = top > 0 ? (v / top) * h : 0.0;
      final x = 8 + i * barW;
      final paint = Paint()..color = color.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + barW * 0.12, h - bh, barW * 0.76, bh),
          const Radius.circular(3),
        ),
        paint,
      );

      if (n <= 31) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: n > 18 ? 7 : 9,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barW);
        tp.paint(
          canvas,
          Offset(x + (barW - tp.width) / 2, h + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarPainter oldDelegate) =>
      oldDelegate.values != values;
}
