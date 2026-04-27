import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
import 'package:production_app/modules/workforce/models/workforce_employee.dart';
import 'package:production_app/modules/personal/work_time/models/orv_demo_data.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_rules_draft.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_rules_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_employee_list_column.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_event_panel.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_summary_rail.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_month_dropdown.dart';
import 'package:production_app/modules/personal/work_time/models/orv_lanes_from_events.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_operational_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_work_time_timeline.dart';

/// Dnevna evidencija: radnici, prijave, planirani i stvarni rad u mreži 0–24 h.
class WorkTimeAttendanceWorkspaceScreen extends StatefulWidget {
  const WorkTimeAttendanceWorkspaceScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkTimeAttendanceWorkspaceScreen> createState() =>
      _WorkTimeAttendanceWorkspaceScreenState();
}

class _WorkTimeAttendanceWorkspaceScreenState
    extends State<WorkTimeAttendanceWorkspaceScreen> {
  final WorkTimeMatrixService _matrixSvc = WorkTimeMatrixService();
  final WorkTimeRulesService _rulesSvc = WorkTimeRulesService();
  final WorkTimeOperationalService _opSvc = WorkTimeOperationalService();
  late int _year;
  late int _month;
  OrvListFilter _listFilter = OrvListFilter.all;
  String? _selectedId;
  WorkTimeMatrixSnapshot? _matrix;
  bool _matrixLoading = true;
  WorkTimeRulesDraft? _rules;
  List<OrvDemoEmployee> _loadedEmployees = [];
  List<Map<String, dynamic>> _monthEvents = <Map<String, dynamic>>[];
  bool _monthEventsLoading = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _year = n.year;
    _month = n.month;
    unawaited(_loadWorkforce());
    if (OrvDemoData.employees.isNotEmpty) {
      _selectedId = OrvDemoData.employees.first.id;
    }
    unawaited(_loadRules());
    _refreshMatrix();
  }

  Future<void> _loadWorkforce() async {
    if (_companyId.isEmpty) {
      return;
    }
    try {
      final sc = await _opSvc.listMyManagedEmployees(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      Set<String>? scope;
      if (sc.restricted && sc.employeeDocIds != null) {
        scope = sc.employeeDocIds!.toSet();
      }
      final snap = await FirebaseFirestore.instance
          .collection('workforce_employees')
          .where('companyId', isEqualTo: _companyId)
          .where('plantKey', isEqualTo: _plantKey)
          .orderBy('displayName')
          .limit(200)
          .get();
      var list = snap.docs
          .map(WorkforceEmployee.fromDoc)
          .map(
            (w) => OrvDemoEmployee(
              id: w.id,
              lastName: w.displayName,
              firstName: w.employeeCode,
            ),
          )
          .toList();
      if (scope != null && scope.isNotEmpty) {
        list = list.where((e) => scope!.contains(e.id)).toList();
      }
      if (mounted) {
        setState(() {
          _loadedEmployees = list;
          if (list.isNotEmpty && (_selectedId == null || _selectedId!.isEmpty)) {
            _selectedId = list.first.id;
          }
          if (list.isNotEmpty &&
              _selectedId != null &&
              !list.any((e) => e.id == _selectedId)) {
            _selectedId = list.first.id;
          }
        });
      }
    } catch (e, st) {
      debugPrint('workforce za ORV: $e $st');
    }
  }

  Future<void> _loadMonthEvents() async {
    if (_companyId.isEmpty) {
      return;
    }
    if (mounted) {
      setState(() => _monthEventsLoading = true);
    }
    try {
      final items = await _opSvc.listEvents(
        companyId: _companyId,
        plantKey: _plantKey,
        year: _year,
        month: _month,
      );
      if (mounted) {
        setState(() {
          _monthEvents = items;
          _monthEventsLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('ORV mjesec događaja: $e $st');
      if (mounted) {
        setState(() => _monthEventsLoading = false);
      }
    }
  }

  Future<void> _loadRules() async {
    try {
      final r = await _rulesSvc.getRules(
        companyId: workTimeCompanyIdFrom(widget.companyData),
        plantKey: workTimePlantKeyFrom(widget.companyData),
      );
      if (!mounted) {
        return;
      }
      setState(() => _rules = r);
    } catch (e, st) {
      debugPrint('workTimeGetRules (dnevna evidencija): $e $st');
    }
  }

  void _refreshMatrix() {
    if (!mounted) return;
    setState(() => _matrixLoading = true);
    unawaited(_loadMonthEvents());
    unawaited(
      _matrixSvc
          .getMonthSnapshot(
            companyId: workTimeCompanyIdFrom(widget.companyData),
            plantKey: workTimePlantKeyFrom(widget.companyData),
            year: _year,
            month: _month,
          )
          .then((s) {
        if (!mounted) return;
        setState(() {
          _matrix = s;
          _matrixLoading = false;
        });
      }),
    );
  }

  String get _userLabel {
    final n = (widget.companyData['name'] ?? widget.companyData['email'] ?? '')
        .toString()
        .trim();
    if (n.isNotEmpty) return n;
    return 'Korisnik (sesija)';
  }

  List<OrvDemoEmployee> get _visibleEmployees {
    final all =
        _loadedEmployees.isNotEmpty ? _loadedEmployees : OrvDemoData.employees;
    switch (_listFilter) {
      case OrvListFilter.all:
        return all;
      case OrvListFilter.marked:
        return all; // nema „označenih" u demu
      case OrvListFilter.invalid:
        return all.where((e) => e.rowHasDataError).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_matrix == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dnevna evidencija')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final matrix = _matrix!;
    final baseLanes = OrvDemoData.daysFor(_year, _month);
    final lanes = orvDayLanesWithEvents(
      year: _year,
      month: _month,
      employeeDocId: _selectedId,
      baseLanes: baseLanes,
      monthEvents: _monthEvents,
    );
    OrvDemoEmployee? selectedEmployee;
    for (final e in _visibleEmployees) {
      if (e.id == _selectedId) {
        selectedEmployee = e;
        break;
      }
    }
    final employeeOk = selectedEmployee == null || !selectedEmployee.rowHasDataError;
    final canCalc = employeeOk && !matrix.hasReviewBlocker;
    final String? monthRailWarning = !employeeOk
        ? 'Za ovog radnika ima neusklađenih prijava. Odaberite drugog radnika ili ispravite unos.'
        : (matrix.hasReviewBlocker
            ? (matrix.payrollBlockersNote ??
                'Mjesec nije spreman za obračun dok se ne riješe pregled.')
            : null);
    const minW = 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dnevna evidencija'),
        actions: [
          IconButton(
            tooltip: 'Poništi filtar',
              onPressed: () {
              setState(() {
                _listFilter = OrvListFilter.all;
                final v = _visibleEmployees;
                _selectedId =
                    v.isNotEmpty ? v.first.id : _selectedId;
              });
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 0.3),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < minW) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Za cjelovit prikaz mreže proširite prozor (preporučeno barem 1000 točaka širine ekrana).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_matrixLoading) const LinearProgressIndicator(minHeight: 2),
              if (_monthEventsLoading) const LinearProgressIndicator(minHeight: 2),
              _toolbar(context),
              _legendBar(context),
              if (_showEarlyArrivalPanel(lanes)) _earlyArrivalPanel(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(
                  _monthEvents.isEmpty
                      ? 'Dnevna mreža: crvena traka s demo podatkom dok nema otkučaja u mjesecu; '
                          'kategorije sati u Callable izlazu (dnevni/mjesečni sažetak).'
                      : 'Crvena traka = stvarni in/out u mjesecu za odabranog radnika; siva = plan (demo). '
                          'Konačni sati: dnevni/mjesečni sažetak.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 256,
                        child: OrvEmployeeListColumn(
                          employees: _visibleEmployees,
                          selectedId: _selectedId,
                          onSelect: (e) => setState(() => _selectedId = e.id),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 2,
                                    child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 200,
                                    ),
                                    child: WorkTimeEventPanel(
                                      companyData: widget.companyData,
                                      employeeDocId: _selectedId,
                                      year: _year,
                                      month: _month,
                                      onEventsChanged: () =>
                                          unawaited(_loadMonthEvents()),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 200,
                                    ),
                                    child: OrvSummaryRail(
                                      canCalculate: canCalc,
                                      monthlyWarning: monthRailWarning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: OrvWorkTimeTimeline(lanes: lanes),
                            ),
                            const SizedBox(height: 4),
                            _footer(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _showEarlyArrivalPanel(List<OrvDayLane> lanes) {
    final r = _rules;
    if (r == null) {
      return false;
    }
    if (r.earlyArrivalPriznajStvarniDolazak) {
      return false;
    }
    return lanes.any((l) => l.hasEarlyClockIn);
  }

  /// Upozorenje: pravilo ne priznaje rani dolazak, a u mreži postoji otkučaj prije smjene.
  Widget _earlyArrivalPanel(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_outlined, color: t.colorScheme.onErrorContainer, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'U pravilu je postavljeno da se rad tretira od početka smjene, a ne od ranijeg otkučaja. '
                'Tako stoje i sati u obračunu za zabilježene dane s ranim dolaskom. '
                'Ako tvrtka želi priznavati stvarno vrijeme, uključite to u Pravila obračuna.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendBar(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        'U mreži: siva = planirana smjena po rasporedu, crvena = stvarno otkučano.',
        style: t.textTheme.labelSmall?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Text('Korisnik', style: t.textTheme.labelMedium),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _userLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodyMedium,
              ),
            ),
            const Spacer(),
            OrvYearMonthToolbar(
              year: _year,
              month: _month,
              onChanged: (y, m) {
                setState(() {
                  _year = y;
                  _month = m;
                });
                _refreshMatrix();
              },
            ),
            const SizedBox(width: 20),
            SegmentedButton<OrvListFilter>(
              segments: const [
                ButtonSegment(
                  value: OrvListFilter.all,
                  label: Text('Svi'),
                ),
                ButtonSegment(
                  value: OrvListFilter.marked,
                  label: Text('Označeni'),
                ),
                ButtonSegment(
                  value: OrvListFilter.invalid,
                  label: Text('Neispravni'),
                ),
              ],
              selected: {_listFilter},
              onSelectionChanged: (s) {
                setState(() {
                  _listFilter = s.first;
                  if (_visibleEmployees.isEmpty) {
                    _selectedId = null;
                  } else if (_selectedId == null ||
                      !_visibleEmployees.any((e) => e.id == _selectedId)) {
                    _selectedId = _visibleEmployees.first.id;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      shape: kOperonixProductionCardShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Text('Napomena', style: t.textTheme.labelMedium),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Bilješka za dan',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Godišnji: 24+0 prošla godina; korišteno: 1; ostalo: 23',
              style: t.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
