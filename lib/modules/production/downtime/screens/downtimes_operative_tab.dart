import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../work_centers/models/work_center_model.dart';
import '../../work_centers/services/work_center_service.dart';
import '../../production_orders/screens/production_order_details_screen.dart';
import '../models/downtime_event_model.dart';
import '../services/downtime_service.dart';
import 'downtime_details_screen.dart';

/// Lista zastoja, KPI za „danas“, filteri — sadržaj bez [Scaffold] (roditelj: tab).
class DowntimesOperativeTab extends StatefulWidget {
  const DowntimesOperativeTab({
    super.key,
    required this.companyData,
    this.initialWorkCenterIdOrCode,
    this.initialEventRangeStart,
    this.initialEventRangeEndExclusive,
    this.startWithFiltersExpanded = false,
  });

  final Map<String, dynamic> companyData;

  /// Predfilter (npr. s Operonix Analytics) — pokušava se uskladiti s `workCenterId` ili `workCenterCode` događaja.
  final String? initialWorkCenterIdOrCode;

  /// Filtar „početak zastoja u [initialEventRangeStart, initialEventRangeEndExclusive)“ (lokalno), kao u analitici.
  final DateTime? initialEventRangeStart;
  final DateTime? initialEventRangeEndExclusive;

  /// Odmah prikaži panel filtera (npr. nakon deep linka).
  final bool startWithFiltersExpanded;

  @override
  State<DowntimesOperativeTab> createState() => _DowntimesOperativeTabState();
}

class _DowntimesOperativeTabState extends State<DowntimesOperativeTab> {
  final DowntimeService _service = DowntimeService();
  final WorkCenterService _wcService = WorkCenterService();

  String? _filterStatus;
  String? _filterCategory;
  /// Prazno = svi; inače događaj mora imati isti [DowntimeEventModel.workCenterId] **ili** [workCenterCode].
  String? _filterWorkCenterToken;
  DateTime? _filterEventRangeStart;
  DateTime? _filterEventRangeEndExclusive;
  bool _filtersExpanded = false;
  bool _appliedInitialFromParent = false;

  void _openProductionOrder(
    BuildContext context,
    String orderId,
  ) {
    final id = orderId.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionOrderDetailsScreen(
          companyData: widget.companyData,
          productionOrderId: id,
        ),
      ),
    );
  }

  List<WorkCenter> _workCenters = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  static String _fmtDay(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.'
        '${l.year}';
  }

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.downtime,
  );

  bool get _canViewOrders => ProductionAccessHelper.canView(
    role: _role,
    card: ProductionDashboardCard.productionOrders,
  );

  /// Vrijednost za [DropdownButtonFormField] — `id` retka ako se token i dalje podudara s šifrarnikom.
  String? get _workCenterDropdownValue {
    final t = _filterWorkCenterToken;
    if (t == null || t.isEmpty) return null;
    for (final w in _workCenters) {
      if (w.id == t) return w.id;
    }
    for (final w in _workCenters) {
      if (w.workCenterCode == t) return w.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadWorkCenters();
  }

  Future<void> _loadWorkCenters() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    final list = await _wcService.listWorkCentersForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    if (!mounted) return;
    setState(() {
      _workCenters = list;
      if (!_appliedInitialFromParent) {
        _appliedInitialFromParent = true;
        final wk = (widget.initialWorkCenterIdOrCode ?? '').trim();
        if (wk.isNotEmpty && wk != '—') {
          _filterWorkCenterToken = wk;
        }
        if (widget.initialEventRangeStart != null &&
            widget.initialEventRangeEndExclusive != null) {
          _filterEventRangeStart = widget.initialEventRangeStart;
          _filterEventRangeEndExclusive = widget.initialEventRangeEndExclusive;
        }
        if (widget.startWithFiltersExpanded) {
          _filtersExpanded = true;
        }
      }
    });
  }

  Iterable<DowntimeEventModel> _applyFilters(List<DowntimeEventModel> raw) sync* {
    for (final e in raw) {
      if (_filterStatus != null && _filterStatus!.isNotEmpty) {
        if (_filterStatus == '__open__') {
          if (!DowntimeEventStatus.isOpenLike(e.status)) continue;
        } else if (e.status != _filterStatus) {
          continue;
        }
      }
      if (_filterCategory != null &&
          _filterCategory!.isNotEmpty &&
          e.downtimeCategory != _filterCategory) {
        continue;
      }
      if (_filterWorkCenterToken != null && _filterWorkCenterToken!.isNotEmpty) {
        final t = _filterWorkCenterToken!;
        if (e.workCenterId != t && e.workCenterCode != t) {
          continue;
        }
      }
      if (_filterEventRangeStart != null && _filterEventRangeEndExclusive != null) {
        final tl = e.startedAt.toLocal();
        if (tl.isBefore(_filterEventRangeStart!) ||
            !tl.isBefore(_filterEventRangeEndExclusive!)) {
          continue;
        }
      }
      yield e;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case DowntimeEventStatus.open:
        return Colors.orange.shade700;
      case DowntimeEventStatus.inProgress:
        return Colors.blue.shade700;
      case DowntimeEventStatus.resolved:
        return Colors.teal.shade700;
      case DowntimeEventStatus.verified:
        return Colors.green.shade800;
      case DowntimeEventStatus.rejected:
        return Colors.red.shade800;
      case DowntimeEventStatus.archived:
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _kpiCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Card(
      shape: operonixProductionCardShape(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: kOperonixScadaAccentBlue),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
      return const Center(
        child: Text('Nedostaje kontekst kompanije ili pogona.'),
      );
    }

    return StreamBuilder<List<DowntimeEventModel>>(
      stream: _service.watchDowntimeEvents(
        companyId: _companyId,
        plantKey: _plantKey,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(AppErrorMapper.toMessage(snap.error!)),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data!;
        final filtered = _applyFilters(all).toList();
        final now = DateTime.now();
        final kpi = DowntimeKpiSummary.compute(events: all, nowLocal: now);

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
                  final tileW = (w - (cols - 1) * 8) / cols;
                  Widget gridKpi(List<Widget> children) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: children
                          .map(
                            (e) => SizedBox(
                              width: tileW,
                              child: e,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return gridKpi([
                    _kpiCard(
                      title: 'Zastoji danas',
                      value: '${kpi.countToday}',
                      icon: Icons.event_note_outlined,
                    ),
                    _kpiCard(
                      title: 'Minute zastoja (danas)',
                      value: '${kpi.downtimeMinutesToday} min',
                      icon: Icons.timer_outlined,
                    ),
                    _kpiCard(
                      title: 'Otvoreni zastoji',
                      value: '${kpi.openCount}',
                      icon: Icons.warning_amber_outlined,
                    ),
                    _kpiCard(
                      title: 'Prosjek trajanja (danas)',
                      value: kpi.countToday == 0
                          ? '—'
                          : '${kpi.avgDurationMinutesToday.toStringAsFixed(1)} min',
                      icon: Icons.av_timer_outlined,
                    ),
                    _kpiCard(
                      title: 'Top radni centar (danas)',
                      value: kpi.topWorkCenterLabel,
                      icon: Icons.precision_manufacturing_outlined,
                    ),
                    _kpiCard(
                      title: 'Top razlog (danas)',
                      value: kpi.topReasonLabel,
                      icon: Icons.label_outline,
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 12),
              Card(
                shape: operonixProductionCardShape(),
                child: ExpansionTile(
                  initiallyExpanded: _filtersExpanded,
                  onExpansionChanged: (x) => setState(() => _filtersExpanded = x),
                  title: const Text('Filteri'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    if (_filterEventRangeStart != null &&
                        _filterEventRangeEndExclusive != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Period liste: događaj započeo u [${_fmtDay(_filterEventRangeStart!)}, '
                          '${_fmtDay(_filterEventRangeEndExclusive!.subtract(const Duration(milliseconds: 1)))}] '
                          '(lokalno, kao analitika).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    if (_filterWorkCenterToken != null &&
                        _filterWorkCenterToken!.isNotEmpty &&
                        _workCenterDropdownValue == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Aktivno filtriranje po centru: ${_filterWorkCenterToken!} '
                          '(nema u trenutnom padajućem popisu; po događajima: ID ili šifra).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      value: _filterStatus,
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('Svi')),
                        DropdownMenuItem<String?>(
                          value: '__open__',
                          child: Text('Otvoreni / u tijeku'),
                        ),
                        DropdownMenuItem<String?>(
                          value: DowntimeEventStatus.open,
                          child: Text('Otvoren'),
                        ),
                        DropdownMenuItem<String?>(
                          value: DowntimeEventStatus.inProgress,
                          child: Text('U tijeku'),
                        ),
                        DropdownMenuItem<String?>(
                          value: DowntimeEventStatus.resolved,
                          child: Text('Riješen'),
                        ),
                        DropdownMenuItem<String?>(
                          value: DowntimeEventStatus.verified,
                          child: Text('Verificiran'),
                        ),
                        DropdownMenuItem<String?>(
                          value: DowntimeEventStatus.rejected,
                          child: Text('Odbijen'),
                        ),
                        DropdownMenuItem<String?>(
                          value: DowntimeEventStatus.archived,
                          child: Text('Arhiviran'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Kategorija',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      value: _filterCategory,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sve'),
                        ),
                        ...DowntimeCategoryKeys.all.map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(DowntimeCategoryKeys.labelHr(k)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterCategory = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Radni centar',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      value: _workCenterDropdownValue,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Svi'),
                        ),
                        ..._workCenters.map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              '${w.workCenterCode} — ${w.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _filterWorkCenterToken = (v == null || v.isEmpty) ? null : v;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Nema zastoja za prikaz. ${_canManage ? 'Pritisnite + za prijavu.' : ''}',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...filtered.map((e) {
                  final mins = e.effectiveDurationMinutesNow(now);
                  final durLabel = mins == null
                      ? '—'
                      : DowntimeEventStatus.isOpenLike(e.status)
                      ? '$mins min (u tijeku)'
                      : '$mins min';
                  return Card(
                    shape: operonixProductionCardShape(),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      isThreeLine: true,
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => DowntimeDetailsScreen(
                              companyData: widget.companyData,
                              downtimeId: e.id,
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(e.status).withOpacity(0.15),
                        child: Icon(
                          Icons.pause_circle_outline,
                          color: _statusColor(e.status),
                        ),
                      ),
                      title: Text(
                        '${e.downtimeCode} · ${DowntimeEventStatus.labelHr(e.status)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${e.workCenterCode.isNotEmpty ? e.workCenterCode : '—'} · '
                        '${e.processCode.isNotEmpty ? e.processCode : '—'}\n'
                        '${e.downtimeReason.isNotEmpty ? e.downtimeReason : e.downtimeCategory} · '
                        '$durLabel · ${e.reportedByName.isNotEmpty ? e.reportedByName : e.reportedBy}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (e.productionOrderId.isNotEmpty && _canViewOrders)
                            IconButton(
                              tooltip: 'Nalog ${e.productionOrderCode.isNotEmpty ? e.productionOrderCode : e.productionOrderId}',
                              onPressed: () {
                                _openProductionOrder(
                                  context,
                                  e.productionOrderId,
                                );
                              },
                              icon: const Icon(Icons.assignment_outlined),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
