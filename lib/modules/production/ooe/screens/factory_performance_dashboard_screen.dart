import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/operational_business_year_context.dart';
import '../../../../core/ui/company_plant_label_text.dart';
import '../../tracking/services/production_tracking_assets_service.dart';
import '../models/ooe_shift_summary.dart';
import '../models/teep_summary.dart';
import '../services/ooe_summary_service.dart';
import '../services/shift_context_service.dart';
import '../services/shift_context_window.dart';
import '../services/teep_summary_service.dart';

String _formatIntThousands(num x) {
  if (x.isNaN) return '—';
  return x.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

double _pctToBarHeight(double? p) =>
    p == null ? 0.0 : (p * 100).clamp(0.0, 100.0).toDouble();

String _shiftLabelHr(String code) {
  switch (code.trim().toUpperCase()) {
    case 'DAY':
      return 'Dnevna';
    case 'NIGHT':
      return 'Noćna';
    case 'AFTERNOON':
      return 'Popodnevna';
    default:
      return code.trim();
  }
}

/// Tamni pregled učinka — isti raspored za OEE / OOE / TEEP (Operonix proizvodnja).
enum FactoryPerformanceKpiMode { oee, ooe, teep }

class FactoryPerformanceDashboardScreen extends StatefulWidget {
  const FactoryPerformanceDashboardScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<FactoryPerformanceDashboardScreen> createState() =>
      _FactoryPerformanceDashboardScreenState();
}

class _FactoryPerformanceDashboardScreenState
    extends State<FactoryPerformanceDashboardScreen> {
  final _summarySvc = OoeSummaryService();
  final _teepSvc = TeepSummaryService();
  final _shiftCtx = ShiftContextService();
  final _assetsSvc = ProductionTrackingAssetsService();

  late Future<ProductionPlantAssetsSnapshot> _assetsFuture;

  String? _machineId;
  String _shiftCode = 'DAY';
  DateTime _calendarDay = DateTime.now();
  FactoryPerformanceKpiMode _mode = FactoryPerformanceKpiMode.ooe;

  String _shiftWindowLabel = '';
  Timer? _debounceShift;
  OperationalFyBounds? _fyBounds;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canViewOoe => ProductionAccessHelper.canView(
        role: _role,
        card: ProductionDashboardCard.ooe,
      );

  @override
  void initState() {
    super.initState();
    _assetsFuture = _assetsSvc.loadForPlant(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    _assetsFuture.then((snap) {
      if (!mounted) return;
      if (_machineId == null && snap.machines.isNotEmpty) {
        setState(() => _machineId = snap.machines.first.id);
      }
      _refreshShiftWindow();
    });
    // ignore: discarded_futures
    _primeOperationalFyBounds();
  }

  Future<void> _primeOperationalFyBounds() async {
    if (_companyId.isEmpty) return;
    final b = await OperationalBusinessYearContext.resolveBoundsForCompany(
      companyId: _companyId,
    );
    if (!mounted) return;
    setState(() {
      _fyBounds = b;
      if (b != null) {
        _calendarDay =
            OperationalBusinessYearContext.clampLocalCalendarDay(_calendarDay, b);
      }
    });
    await _refreshShiftWindow();
  }

  @override
  void dispose() {
    _debounceShift?.cancel();
    super.dispose();
  }

  Future<void> _refreshShiftWindow() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    final raw = _shiftCode.trim().toUpperCase();
    final shiftId = raw.isEmpty ? 'DAY' : raw;
    try {
      final ctx = await _shiftCtx.getContext(
        companyId: _companyId,
        plantKey: _plantKey,
        shiftDateLocal: _calendarDay,
        shiftCode: shiftId,
      );
      if (!mounted) return;
      final w = ShiftContextWindowHelper.eventWindowForSummary(
        shiftCalendarDayLocal: _calendarDay,
        context: ctx,
      );
      setState(() {
        _shiftWindowLabel = ShiftContextWindowHelper.describeLabel(w);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shiftWindowLabel = ShiftContextWindowHelper.describeLabel(
          ShiftContextWindowHelper.eventWindowForSummary(
            shiftCalendarDayLocal: _calendarDay,
            context: null,
          ),
        );
      });
    }
  }

  void _onShiftOrDayChanged() {
    _debounceShift?.cancel();
    _debounceShift = Timer(const Duration(milliseconds: 350), _refreshShiftWindow);
  }

  OoeShiftSummary? _pickSummaryForShift(List<OoeShiftSummary> list) {
    if (list.isEmpty) return null;
    final want = _shiftCode.trim().toUpperCase();
    if (want.isEmpty) return list.first;
    for (final s in list) {
      if ((s.shiftId ?? '').trim().toUpperCase() == want) return s;
    }
    return list.first;
  }

  String _lineTitle(ProductionPlantAssetsSnapshot? assets, OoeShiftSummary? s) {
    if (s?.lineId != null && s!.lineId!.trim().isNotEmpty) {
      final lk = s.lineId!.trim();
      final name = assets?.lineDisplayNameByLineKey[lk];
      if (name != null && name.isNotEmpty) return name;
      return 'Linija $lk';
    }
    if (assets != null && _machineId != null) {
      final lk = assets.machineLineKeyByMachineId[_machineId!];
      if (lk != null) {
        final name = assets.lineDisplayNameByLineKey[lk];
        if (name != null && name.isNotEmpty) return name;
        return 'Linija $lk';
      }
    }
    return 'Linija';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userLine = user == null
        ? '—'
        : [
            user.displayName?.trim(),
            user.email?.trim(),
          ].whereType<String>().where((e) => e.isNotEmpty).firstOrNull ?? '—';

    final now = DateTime.now();
    final headerDate =
        '${now.day}.${now.month}.${now.year}. · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (!_canViewOoe) {
      return Scaffold(
        appBar: AppBar(title: const Text('Učinak pogona')),
        body: const Center(
          child: Text('Nemaš pristup ovom pregledu.'),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FactoryPerformanceTheme.bg,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: FactoryPerformanceTheme.text,
              displayColor: FactoryPerformanceTheme.text,
            ),
      ),
      child: Scaffold(
        backgroundColor: FactoryPerformanceTheme.bg,
        appBar: AppBar(
          backgroundColor: FactoryPerformanceTheme.headerBg,
          foregroundColor: FactoryPerformanceTheme.text,
          elevation: 0,
          title: const Text('Učinak pogona'),
          actions: [
            IconButton(
              tooltip: 'Datum smjene',
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () async {
                final pb = OperationalBusinessYearContext.materialDatePickerBounds(
                  fy: _fyBounds,
                  referenceDay: _calendarDay,
                );
                var initial = DateTime(
                  _calendarDay.year,
                  _calendarDay.month,
                  _calendarDay.day,
                );
                if (initial.isBefore(pb.firstDate)) initial = pb.firstDate;
                if (initial.isAfter(pb.lastDate)) initial = pb.lastDate;

                final p = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: pb.firstDate,
                  lastDate: pb.lastDate,
                );
                if (p != null && mounted) {
                  setState(() {
                    _calendarDay = DateTime(p.year, p.month, p.day);
                  });
                  _onShiftOrDayChanged();
                }
              },
            ),
          ],
        ),
        body: FutureBuilder<ProductionPlantAssetsSnapshot>(
          future: _assetsFuture,
          builder: (context, assetSnap) {
            if (assetSnap.hasError) {
              return Center(
                child: Text(
                  AppErrorMapper.toMessage(assetSnap.error!),
                  style: const TextStyle(color: FactoryPerformanceTheme.text),
                ),
              );
            }
            if (!assetSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final assets = assetSnap.data!;
            final mids = assets.machines.map((m) => m.id).toList();

            if (_machineId != null && !mids.contains(_machineId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _machineId = mids.isNotEmpty ? mids.first : null;
                  });
                }
              });
            }

            if (_machineId == null || _machineId!.isEmpty) {
              return Center(
                child: Text(
                  mids.isEmpty
                      ? 'Nema aktivnih strojeva u pogonu.'
                      : 'Odaberi stroj.',
                  style: const TextStyle(color: FactoryPerformanceTheme.text),
                ),
              );
            }

            final mid = _machineId!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _DashboardHeader(
                    shiftLine: _shiftWindowLabel.isEmpty
                        ? 'Smjena: ${_shiftLabelHr(_shiftCode)}'
                        : 'Smjena: $_shiftWindowLabel',
                    userLine: userLine,
                    dateLine: headerDate,
                    companyPlant: CompanyPlantLabelText(
                      companyId: _companyId,
                      plantKey: _plantKey,
                      prefix: 'Pogon: ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FactoryPerformanceTheme.textDim,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('fp-machine-$mid'),
                          initialValue: mid,
                          dropdownColor: FactoryPerformanceTheme.card,
                          style: const TextStyle(
                            color: FactoryPerformanceTheme.text,
                            fontSize: 14,
                          ),
                          decoration: _darkInputDecoration('Stroj'),
                          items: assets.machines
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text('${m.title} (${m.id})'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _machineId = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('fp-shift-$_shiftCode'),
                          initialValue: _shiftCode,
                          dropdownColor: FactoryPerformanceTheme.card,
                          style: const TextStyle(
                            color: FactoryPerformanceTheme.text,
                            fontSize: 14,
                          ),
                          decoration: _darkInputDecoration('Smjena'),
                          items: const [
                            DropdownMenuItem(
                              value: 'DAY',
                              child: Text('Dnevna (DAY)'),
                            ),
                            DropdownMenuItem(
                              value: 'NIGHT',
                              child: Text('Noćna (NIGHT)'),
                            ),
                            DropdownMenuItem(
                              value: 'AFTERNOON',
                              child: Text('Popodnevna (AFTERNOON)'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _shiftCode = v);
                            _onShiftOrDayChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _KpiModeBar(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<OoeShiftSummary>>(
                    stream: _summarySvc.watchSummariesForMachineOnCalendarDay(
                      companyId: _companyId,
                      plantKey: _plantKey,
                      machineId: mid,
                      calendarDay: _calendarDay,
                    ),
                    builder: (context, sumSnap) {
                      return StreamBuilder<List<TeepSummary>>(
                        stream: _teepSvc.watchRecentForPlant(
                          companyId: _companyId,
                          plantKey: _plantKey,
                          limit: 80,
                        ),
                        builder: (context, teepSnap) {
                          if (sumSnap.hasError) {
                            return Center(
                              child: Text(
                                AppErrorMapper.toMessage(sumSnap.error!),
                                style: const TextStyle(
                                  color: FactoryPerformanceTheme.text,
                                ),
                              ),
                            );
                          }
                          if (teepSnap.hasError) {
                            return Center(
                              child: Text(
                                AppErrorMapper.toMessage(teepSnap.error!),
                                style: const TextStyle(
                                  color: FactoryPerformanceTheme.text,
                                ),
                              ),
                            );
                          }

                          final summaries = sumSnap.data ?? [];
                          final s = _pickSummaryForShift(summaries);
                          final teepList = teepSnap.data ?? [];
                          final teep = _teepSvc.pickMachineDaySummary(
                            recent: teepList,
                            machineId: mid,
                            calendarDayLocal: _calendarDay,
                          );

                          final prev = _previousShiftSummary(mid, s, summaries);

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final wide = c.maxWidth >= 920;
                                final mainColumn = _MainBoard(
                                  mode: _mode,
                                  summary: s,
                                  teep: teep,
                                  prevSummary: prev,
                                  lineTitle: _lineTitle(assets, s),
                                  shiftCode: _shiftCode,
                                  shiftLabelHr: _shiftLabelHr(_shiftCode),
                                );
                                if (wide) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: mainColumn),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 6,
                                        child: _DetailColumns(
                                          mode: _mode,
                                          summary: s,
                                          teep: teep,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    mainColumn,
                                    const SizedBox(height: 16),
                                    _DetailColumns(
                                      mode: _mode,
                                      summary: s,
                                      teep: teep,
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  OoeShiftSummary? _previousShiftSummary(
    String machineId,
    OoeShiftSummary? current,
    List<OoeShiftSummary> sameDayList,
  ) {
    if (current == null) return null;
    final others = sameDayList
        .where((x) => x.id != current.id)
        .toList()
      ..sort((a, b) => b.lastCalculatedAt.compareTo(a.lastCalculatedAt));
    if (others.isNotEmpty) return others.first;
    return null;
  }

  InputDecoration _darkInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: FactoryPerformanceTheme.textDim),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FactoryPerformanceTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FactoryPerformanceTheme.cyan),
      ),
    );
  }

}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final i = iterator;
    return i.moveNext() ? i.current : null;
  }
}

// --- Theme -----------------------------------------------------------------

class FactoryPerformanceTheme {
  static const bg = Color(0xFF0C1018);
  static const headerBg = Color(0xFF121824);
  static const card = Color(0xFF151C2C);
  static const cardBorder = Color(0xFF252F45);
  static const text = Color(0xFFF2F5FF);
  static const textDim = Color(0xFF8B95B2);
  static const cyan = Color(0xFF00E5FF);
  static const purple = Color(0xFFB388FF);
  static const orange = Color(0xFFFFAB40);
  static const green = Color(0xFF69F0AE);
  static const red = Color(0xFFFF5252);
  static const border = Color(0xFF2A3448);
}

// --- Header ----------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.shiftLine,
    required this.userLine,
    required this.dateLine,
    required this.companyPlant,
  });

  final String shiftLine;
  final String userLine;
  final String dateLine;
  final Widget companyPlant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: FactoryPerformanceTheme.headerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FactoryPerformanceTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.precision_manufacturing_outlined,
                  color: FactoryPerformanceTheme.text, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pregled učinka proizvodnje',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: FactoryPerformanceTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          companyPlant,
          const SizedBox(height: 8),
          Text(
            shiftLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FactoryPerformanceTheme.cyan,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Korisnik: $userLine · $dateLine',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              color: FactoryPerformanceTheme.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

// --- KPI mode --------------------------------------------------------------

class _KpiModeBar extends StatelessWidget {
  const _KpiModeBar({required this.mode, required this.onChanged});

  final FactoryPerformanceKpiMode mode;
  final ValueChanged<FactoryPerformanceKpiMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(FactoryPerformanceKpiMode m, String label) {
      final on = mode == m;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: on
                ? FactoryPerformanceTheme.cyan.withValues(alpha: 0.18)
                : FactoryPerformanceTheme.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on
                        ? FactoryPerformanceTheme.cyan
                        : FactoryPerformanceTheme.border,
                    width: on ? 1.5 : 1,
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: FactoryPerformanceTheme.cyan
                                .withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: on
                        ? FactoryPerformanceTheme.cyan
                        : FactoryPerformanceTheme.textDim,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(FactoryPerformanceKpiMode.oee, 'OEE'),
        chip(FactoryPerformanceKpiMode.ooe, 'OOE'),
        chip(FactoryPerformanceKpiMode.teep, 'TEEP'),
      ],
    );
  }
}

// --- Main gauge + footer ---------------------------------------------------

class _MainBoard extends StatelessWidget {
  const _MainBoard({
    required this.mode,
    required this.summary,
    required this.teep,
    required this.prevSummary,
    required this.lineTitle,
    required this.shiftCode,
    required this.shiftLabelHr,
  });

  final FactoryPerformanceKpiMode mode;
  final OoeShiftSummary? summary;
  final TeepSummary? teep;
  final OoeShiftSummary? prevSummary;
  final String lineTitle;
  final String shiftCode;
  final String shiftLabelHr;

  double? _mainValue() {
    switch (mode) {
      case FactoryPerformanceKpiMode.ooe:
        return summary?.ooe;
      case FactoryPerformanceKpiMode.oee:
        return teep?.oee;
      case FactoryPerformanceKpiMode.teep:
        return teep?.teep;
    }
  }

  String _titleLong() {
    switch (mode) {
      case FactoryPerformanceKpiMode.oee:
        return 'OEE — učinkovitost opreme (planirano proizvodno vrijeme)';
      case FactoryPerformanceKpiMode.ooe:
        return 'OOE — učinkovitost operacija (operativno vrijeme)';
      case FactoryPerformanceKpiMode.teep:
        return 'TEEP — učinkovitost u kalendarskom vremenu';
    }
  }

  String _abbr() {
    switch (mode) {
      case FactoryPerformanceKpiMode.oee:
        return 'OEE';
      case FactoryPerformanceKpiMode.ooe:
        return 'OOE';
      case FactoryPerformanceKpiMode.teep:
        return 'TEEP';
    }
  }

  String? _deltaLine() {
    if (mode != FactoryPerformanceKpiMode.ooe) return null;
    final cur = _mainValue();
    if (cur == null || prevSummary == null) return null;
    final prevMain = prevSummary!.ooe;
    final d = (cur - prevMain) * 100;
    if (d.abs() < 0.02) {
      return '● 0,0 p.p. u odnosu na drugu smjenu (isti dan)';
    }
    final arrow = d >= 0 ? '▲' : '▼';
    return '$arrow ${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} p.p. u odnosu na drugu smjenu';
  }

  @override
  Widget build(BuildContext context) {
    final v = _mainValue();
    final pct = v == null || v.isNaN ? null : (v * 100).clamp(0.0, 100.0);
    final delta = _deltaLine();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FactoryPerformanceTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FactoryPerformanceTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.precision_manufacturing_outlined,
                  color: FactoryPerformanceTheme.text, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _titleLong(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: FactoryPerformanceTheme.text,
                  ),
                ),
              ),
            ],
          ),
          if (mode != FactoryPerformanceKpiMode.ooe && teep == null) ...[
            const SizedBox(height: 12),
            Text(
              mode == FactoryPerformanceKpiMode.oee
                  ? 'Nema TEEP dnevnog sažetka za ovaj stroj — OEE zahtijeva agregat iz modula TEEP.'
                  : 'Nema TEEP dnevnog sažetka za ovaj stroj.',
              style: TextStyle(
                fontSize: 12,
                color: FactoryPerformanceTheme.orange.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (mode == FactoryPerformanceKpiMode.ooe && summary == null) ...[
            const SizedBox(height: 12),
            const Text(
              'Nema sažetka smjene za odabrani dan i smjenu.',
              style: TextStyle(fontSize: 12, color: FactoryPerformanceTheme.textDim),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: _NeonGaugePainter(progress: (pct ?? 0) / 100.0),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pct == null ? '—' : '${pct.toStringAsFixed(0)} %',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: FactoryPerformanceTheme.text,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        _abbr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FactoryPerformanceTheme.textDim,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Trenutni ${_abbr()}: ${pct == null ? '—' : '${pct.toStringAsFixed(1)} %'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FactoryPerformanceTheme.textDim,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(
              delta,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: delta.contains('▲')
                    ? FactoryPerformanceTheme.green
                    : (delta.contains('▼')
                        ? FactoryPerformanceTheme.red
                        : FactoryPerformanceTheme.textDim),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _ShiftSummaryStrip(
            lineTitle: lineTitle,
            shiftLabelHr: shiftLabelHr,
            summary: summary,
          ),
        ],
      ),
    );
  }
}

class _NeonGaugePainter extends CustomPainter {
  _NeonGaugePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 14;
    const stroke = 18.0;

    final bgPaint = Paint()
      ..color = FactoryPerformanceTheme.bg.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bgPaint);

    final sweep = 1.85 * math.pi * progress.clamp(0.0, 1.0);
    const start = -math.pi * 1.15;

    final grad = SweepGradient(
      startAngle: start,
      endAngle: start + 1.85 * math.pi,
      colors: const [
        FactoryPerformanceTheme.red,
        Color(0xFFFFEE58),
        FactoryPerformanceTheme.green,
      ],
      stops: const [0.0, 0.45, 1.0],
      transform: GradientRotation(start),
    );

    final arcPaint = Paint()
      ..shader = grad.createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- Detail columns --------------------------------------------------------

class _DetailColumns extends StatelessWidget {
  const _DetailColumns({
    required this.mode,
    required this.summary,
    required this.teep,
  });

  final FactoryPerformanceKpiMode mode;
  final OoeShiftSummary? summary;
  final TeepSummary? teep;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final t = teep;

    final firstTitle =
        mode == FactoryPerformanceKpiMode.teep ? 'Iskorištenje' : 'Dostupnost';
    final firstPct = mode == FactoryPerformanceKpiMode.oee
        ? t?.availabilityOee
        : mode == FactoryPerformanceKpiMode.ooe
            ? s?.availability
            : t?.utilization;

    final downMin = s == null ? 0.0 : s.stopTimeSeconds / 60.0;
    final runMin = s == null ? 0.0 : s.runTimeSeconds / 60.0;

    final idealCyc = s?.idealCycleTimeSeconds;
    final idealOut = (s != null &&
            idealCyc != null &&
            idealCyc > 0 &&
            s.runTimeSeconds > 0)
        ? s.runTimeSeconds / idealCyc
        : null;
    final actualOut = s?.totalCount;

    return Column(
      children: [
        _DetailCard(
          title: firstTitle,
          icon: mode == FactoryPerformanceKpiMode.teep
              ? Icons.hourglass_top_outlined
              : Icons.settings_suggest_outlined,
          accent: FactoryPerformanceTheme.cyan,
          pct: firstPct,
          barA: _pctToBarHeight(firstPct),
          barB: 100,
          lines: [
            if (mode != FactoryPerformanceKpiMode.teep) ...[
              _DetailLine(
                label: 'Vrijeme zastoja',
                value: '${downMin.round()} min',
                warn: downMin > 0,
              ),
              _DetailLine(
                label: 'Vrijeme rada',
                value: '${runMin.round()} min',
              ),
            ] else ...[
              _DetailLine(
                label: 'Kalendarsko vrijeme',
                value: t == null
                    ? '—'
                    : '${(t.calendarTimeSeconds / 3600).toStringAsFixed(1)} h',
              ),
              _DetailLine(
                label: 'Planirana proizvodnja',
                value: t == null
                    ? '—'
                    : '${(t.plannedProductionTimeSeconds / 3600).toStringAsFixed(1)} h',
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Performans',
          icon: Icons.trending_up,
          accent: FactoryPerformanceTheme.purple,
          pct: mode == FactoryPerformanceKpiMode.ooe ? s?.performance : t?.performance,
          barA: _pctToBarHeight(
            mode == FactoryPerformanceKpiMode.ooe ? s?.performance : t?.performance,
          ),
          barB: 100,
          lines: [
            _DetailLine(
              label: 'Idealno (kom)',
              value: idealOut == null ? '—' : _formatIntThousands(idealOut),
            ),
            _DetailLine(
              label: 'Ostvareno (kom)',
              value: actualOut == null ? '—' : _formatIntThousands(actualOut),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Kvalitet',
          icon: Icons.verified_outlined,
          accent: FactoryPerformanceTheme.orange,
          pct: mode == FactoryPerformanceKpiMode.ooe ? s?.quality : t?.quality,
          barA: _pctToBarHeight(
            mode == FactoryPerformanceKpiMode.ooe ? s?.quality : t?.quality,
          ),
          barB: 100,
          lines: [
            _DetailLine(
              label: 'Škart (kom)',
              value: s == null ? '—' : _formatIntThousands(s.scrapCount),
              warn: (s?.scrapCount ?? 0) > 0,
            ),
            _DetailLine(
              label: 'Ukupno komada',
              value: s == null ? '—' : _formatIntThousands(s.totalCount),
            ),
            _DetailLine(
              label: 'Dobri komadi',
              value: s == null ? '—' : _formatIntThousands(s.goodCount),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailLine {
  const _DetailLine({
    required this.label,
    required this.value,
    this.warn = false,
  });
  final String label;
  final String value;
  final bool warn;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.pct,
    required this.barA,
    required this.barB,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final double? pct;
  final double barA;
  final double barB;
  final List<_DetailLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FactoryPerformanceTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FactoryPerformanceTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pct == null || pct!.isNaN ? '—' : '${(pct! * 100).toStringAsFixed(0)} %',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: FactoryPerformanceTheme.text,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _MiniBar(
                    heightFrac: barB > 0
                        ? (barA / barB).clamp(0.0, 1.0).toDouble()
                        : 0.0,
                    gradient: [accent, accent.withValues(alpha: 0.4)],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniBar(
                    heightFrac: 0.65,
                    gradient: [
                      accent.withValues(alpha: 0.35),
                      FactoryPerformanceTheme.border,
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FactoryPerformanceTheme.textDim,
                      ),
                    ),
                  ),
                  Text(
                    l.value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: l.warn ? FactoryPerformanceTheme.red : FactoryPerformanceTheme.text,
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

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.heightFrac, required this.gradient});

  final double heightFrac;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = (c.maxHeight * heightFrac).clamp(8.0, c.maxHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Bottom strip ----------------------------------------------------------

class _ShiftSummaryStrip extends StatelessWidget {
  const _ShiftSummaryStrip({
    required this.lineTitle,
    required this.shiftLabelHr,
    required this.summary,
  });

  final String lineTitle;
  final String shiftLabelHr;
  final OoeShiftSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final plannedMin = s == null ? 0 : s.plannedStopSeconds ~/ 60;
    final maintMin = s == null ? 0 : s.maintenanceSeconds ~/ 60;
    final lossRows = s?.topLosses.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FactoryPerformanceTheme.headerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FactoryPerformanceTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sažetak smjene',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: FactoryPerformanceTheme.text,
                  ),
                ),
              ),
              Text(
                lineTitle,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FactoryPerformanceTheme.textDim,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.more_horiz, color: FactoryPerformanceTheme.textDim.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            children: [
              _SumCell(
                icon: Icons.schedule_outlined,
                label: 'Smjena',
                value: shiftLabelHr,
              ),
              _SumCell(
                label: 'Ukupno kom',
                value: s == null ? '—' : _formatIntThousands(s.totalCount),
              ),
              _SumCell(
                label: 'Gubitci (retci)',
                value: '$lossRows',
              ),
              _SumCell(
                icon: Icons.build_circle_outlined,
                label: 'Održavanje',
                value: '$maintMin min',
              ),
              _SumCell(
                icon: Icons.handyman_outlined,
                label: 'Planirani zastoj',
                value: '$plannedMin min',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: FactoryPerformanceTheme.border,
                ),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _SumCell extends StatelessWidget {
  const _SumCell({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: FactoryPerformanceTheme.cyan),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: FactoryPerformanceTheme.textDim,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: FactoryPerformanceTheme.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
