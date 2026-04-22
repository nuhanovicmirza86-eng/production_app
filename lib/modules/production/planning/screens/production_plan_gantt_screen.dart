import 'dart:async';

import 'package:flutter/material.dart';

import '../../tracking/services/production_asset_display_lookup.dart';
import '../services/planning_gantt_dto.dart';
import '../services/planning_gantt_zoom_prefs.dart';
import '../services/production_plan_persistence_service.dart';

/// Prikaz vremenske trake po resursu (red); u blokovima se prikazuje **šifra naloga**, ne interni ID.
class ProductionPlanGanttScreen extends StatefulWidget {
  ProductionPlanGanttScreen({
    super.key,
    required this.companyData,
    this.gantt,
    this.planId,
  }) : assert(
         gantt != null || (planId != null && planId.isNotEmpty),
         'Ili gantt (memorija) ili planId (Firestore) mora biti zadan.',
       );

  final Map<String, dynamic> companyData;
  final PlanningGanttDto? gantt;
  final String? planId;

  @override
  State<ProductionPlanGanttScreen> createState() =>
      _ProductionPlanGanttScreenState();
}

class _ProductionPlanGanttScreenState extends State<ProductionPlanGanttScreen> {
  final _persistence = ProductionPlanPersistenceService();
  PlanningGanttDto? _data;
  String? _error;
  bool _loading = false;
  /// Doc id asseta (stroj) → prikazni naziv iz `assets` (nema golih ID-eva u UI).
  Map<String, String> _machineLabels = const {};

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _pk => (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    if (widget.gantt != null) {
      _data = widget.gantt;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveMachineLabels();
      });
    } else {
      _load();
    }
  }

  Future<Map<String, String>> _labelsFor(PlanningGanttDto d) async {
    if (d.operations.isEmpty) return const {};
    final lookup = await ProductionAssetDisplayLookup.loadForPlant(
      companyId: _cid,
      plantKey: _pk,
      limit: 500,
    );
    final ids = <String>{for (final o in d.operations) o.machineId};
    final m = <String, String>{};
    for (final id in ids) {
      m[id] = id.isEmpty
          ? 'Nije dodijeljen stroj'
          : lookup.resolve(id);
    }
    return m;
  }

  Future<void> _resolveMachineLabels() async {
    final d = _data;
    if (d == null || d.operations.isEmpty) return;
    final labels = await _labelsFor(d);
    if (mounted) setState(() => _machineLabels = labels);
  }

  Future<void> _load() async {
    final id = widget.planId;
    if (id == null || id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _persistence.loadGantt(
        planId: id,
        companyId: _cid,
        plantKey: _pk,
      );
      final labels = await _labelsFor(d);
      if (mounted) {
        setState(() {
          _data = d;
          _machineLabels = labels;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Učitavanje plana nije uspjelo. Provjera prava i mreže.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gantt (plan)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gantt (plan)')),
        body: Center(
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    final d = _data;
    if (d == null || d.operations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gantt (plan)')),
        body: const Center(
          child: Text('Nema zakazanih operacija za prikaz.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Gantt: ${d.planCode}'),
      ),
      body: PlanningGanttChart(
        data: d,
        machineLabels: _machineLabels,
        showNowLine: true,
        preferenceCompanyId: _cid,
        preferencePlantKey: _pk,
      ),
    );
  }
}

/// Boje blokova: setup (priprema) i rad — usklađeno s [_GanttRow._block].
class _GanttLegendBar extends StatelessWidget {
  const _GanttLegendBar({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final c = theme.colorScheme;
    Widget leg(Color bg, Color fg, String t) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 12,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            t,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        leg(
          c.secondaryContainer,
          c.onSurfaceVariant,
          'Priprema (setup) — uključeno u interval od početka do početka rada',
        ),
        leg(
          c.primaryContainer,
          c.onSurfaceVariant,
          'Rad (trajanje) — s planiranim krajem operacije; ako nema rastava, cijeli blok je rad',
        ),
      ],
    );
  }
}

/// Dijeljeni Gantt tijelo (embed u hub, puni ekran, itd.); opcionalna **vertikalna linija „sad”** preko vremenske trake.
class PlanningGanttChart extends StatefulWidget {
  const PlanningGanttChart({
    super.key,
    required this.data,
    required this.machineLabels,
    this.showNowLine = true,
    this.preferenceCompanyId,
    this.preferencePlantKey,
  });

  final PlanningGanttDto data;
  final Map<String, String> machineLabels;
  final bool showNowLine;
  /// Ako su oba zadana, zoom (sat/smjena/dan/tjedan) se pamti u [PlanningGanttZoomPrefs].
  final String? preferenceCompanyId;
  final String? preferencePlantKey;

  static String _fmtDateTime(DateTime d) {
    final t = d.toLocal();
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year}  '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  State<PlanningGanttChart> createState() => _PlanningGanttChartState();
}

class _PlanningGanttChartState extends State<PlanningGanttChart> {
  Timer? _nowTick;
  PlanningGanttZoomPreset _zoom = PlanningGanttZoomPreset.day;

  @override
  void initState() {
    super.initState();
    _nowTick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.showNowLine) setState(() {});
    });
    final cid = widget.preferenceCompanyId?.trim() ?? '';
    final pk = widget.preferencePlantKey?.trim() ?? '';
    if (cid.isNotEmpty || pk.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final z = await PlanningGanttZoomPrefs.read(cid, pk);
        if (mounted && z != null) {
          setState(() => _zoom = z);
        }
      });
    }
  }

  @override
  void dispose() {
    _nowTick?.cancel();
    super.dispose();
  }

  static Widget? _buildNowMarker({
    required ThemeData theme,
    required PlanningGanttDto data,
    required double pxPerMinute,
    required double width,
    required double chartH,
    required bool showNowLine,
  }) {
    if (!showNowLine || chartH <= 0) return null;
    final now = DateTime.now();
    if (now.isBefore(data.windowStart) || now.isAfter(data.windowEnd)) {
      return null;
    }
    final x = now.difference(data.windowStart).inMinutes * pxPerMinute;
    if (x < 0 || x > width) return null;
    return Positioned(
      left: x,
      top: 0,
      width: 2,
      height: chartH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            color: theme.colorScheme.error,
            child: Text(
              'sad',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onError,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: theme.colorScheme.error.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final mKeys = <String>{for (final o in data.operations) o.machineId}.toList()..sort();

    final totalMin = data.windowEnd.difference(data.windowStart).inMinutes
        .clamp(1, 1 << 30);
    const minChartWidth = 720.0;
    final width = (minChartWidth * _zoom.widthMultiplier).clamp(360.0, 2800.0);
    final pxPerMinute = width / totalMin;
    final rowH = 64.0;
    final chartH = mKeys.length * rowH;
    final theme = Theme.of(context);
    final nowMarker = _PlanningGanttChartState._buildNowMarker(
      theme: theme,
      data: data,
      pxPerMinute: pxPerMinute,
      width: width,
      chartH: chartH,
      showNowLine: widget.showNowLine,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text('Zoom vremenske ljestvice:', style: Theme.of(context).textTheme.labelLarge),
              SegmentedButton<PlanningGanttZoomPreset>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PlanningGanttZoomPreset.hour,
                    label: Text('Sat'),
                    icon: Icon(Icons.schedule, size: 16),
                  ),
                  ButtonSegment(
                    value: PlanningGanttZoomPreset.shift,
                    label: Text('Smjena'),
                    icon: Icon(Icons.view_day, size: 16),
                  ),
                  ButtonSegment(
                    value: PlanningGanttZoomPreset.day,
                    label: Text('Dan'),
                    icon: Icon(Icons.calendar_view_day, size: 16),
                  ),
                  ButtonSegment(
                    value: PlanningGanttZoomPreset.week,
                    label: Text('Tjedan'),
                    icon: Icon(Icons.date_range, size: 16),
                  ),
                ],
                selected: {_zoom},
                onSelectionChanged: (s) async {
                  if (s.isEmpty) return;
                  final next = s.first;
                  setState(() => _zoom = next);
                  final cid = widget.preferenceCompanyId?.trim() ?? '';
                  final pk = widget.preferencePlantKey?.trim() ?? '';
                  if (cid.isNotEmpty || pk.isNotEmpty) {
                    await PlanningGanttZoomPrefs.write(cid, pk, next);
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Vodoravno pomicanje. Lijevo: strojevi (iz šifrarnika). U traci: nalog, ispod toga operacija / korak routingsa kad je poznat.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: _GanttLegendBar(theme: Theme.of(context)),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 148,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListView.builder(
                    itemCount: mKeys.length,
                    itemBuilder: (context, i) {
                      final mk = mKeys[i];
                      final label = widget.machineLabels[mk] ??
                          (mk.isEmpty ? 'Nije dodijeljen stroj' : '…');
                      return SizedBox(
                        height: 64,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: chartH,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Column(
                          children: mKeys.map((mk) {
                            return _GanttRow(
                              data: data,
                              machineKey: mk,
                              pxPerMinute: pxPerMinute,
                            );
                          }).toList(),
                        ),
                        ?nowMarker,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Početak: ${PlanningGanttChart._fmtDateTime(data.windowStart)}  ·  Kraj: ${PlanningGanttChart._fmtDateTime(data.windowEnd)}',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _GanttRow extends StatelessWidget {
  const _GanttRow({
    required this.data,
    required this.machineKey,
    required this.pxPerMinute,
  });

  final PlanningGanttDto data;
  final String machineKey;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ops =
        data.operations.where((o) => o.machineId == machineKey).toList();
    return SizedBox(
      height: 64,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
          for (final o in ops) ..._segments(theme, o),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: Container(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _segments(ThemeData theme, PlanningGanttOp o) {
    final rs = o.runStart;
    final re = o.runEnd;
    if (rs != null && re != null) {
      final s = o.plannedStart.difference(data.windowStart).inMinutes *
          pxPerMinute;
      final setupEnd = rs.difference(data.windowStart).inMinutes * pxPerMinute;
      var sw = (setupEnd - s).clamp(0.0, 1e6);
      if (sw < 2) sw = 2;
      final runL = re.difference(rs).inMinutes * pxPerMinute;
      final rx = rs.difference(data.windowStart).inMinutes * pxPerMinute;
      return [
        _block(theme, s, sw, o.orderCode, o.operationLabel, isSetup: true),
        if (runL > 0)
          _block(
            theme,
            rx,
            runL.clamp(4, 1e6),
            o.orderCode,
            o.operationLabel,
            isSetup: false,
          ),
      ];
    }
    final l = o.plannedStart.difference(data.windowStart).inMinutes * pxPerMinute;
    final w = o.plannedEnd.difference(o.plannedStart).inMinutes * pxPerMinute;
    return [
      _block(
        theme,
        l,
        w.clamp(4, 1e6),
        o.orderCode,
        o.operationLabel,
        isSetup: false,
      ),
    ];
  }

  Widget _block(
    ThemeData theme,
    double left,
    double w,
    String orderCode,
    String? operationLabel, {
    required bool isSetup,
  }) {
    final bg = isSetup
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.primaryContainer;
    final fg = isSetup
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onPrimaryContainer;
    return Positioned(
      left: left,
      top: 4,
      width: w,
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  orderCode,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (operationLabel != null && operationLabel.isNotEmpty)
                  Text(
                    operationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.92),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
