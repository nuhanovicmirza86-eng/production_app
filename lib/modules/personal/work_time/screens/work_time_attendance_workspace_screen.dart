import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
import 'package:production_app/modules/personal/work_time/models/orv_demo_data.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_matrix_demo.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_rules_draft.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_matrix_service.dart';
import 'package:production_app/modules/personal/work_time/services/work_time_rules_service.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_employee_list_column.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_event_control_block.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_summary_rail.dart';
import 'package:production_app/modules/personal/work_time/widgets/orv_month_dropdown.dart';
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
  late int _year;
  late int _month;
  OrvListFilter _listFilter = OrvListFilter.all;
  String? _selectedId;
  WorkTimeMatrixSnapshot? _matrix;
  bool _matrixLoading = true;
  WorkTimeRulesDraft? _rules;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _year = n.year;
    _month = n.month;
    if (OrvDemoData.employees.isNotEmpty) {
      _selectedId = OrvDemoData.employees.first.id;
    }
    unawaited(_loadRules());
    _refreshMatrix();
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
    final all = OrvDemoData.employees;
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
    final lanes = OrvDemoData.daysFor(_year, _month);
    final events = OrvDemoData.eventsFor(year: _year, month: _month);
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
                _selectedId = OrvDemoData.employees.isNotEmpty
                    ? OrvDemoData.employees.first.id
                    : null;
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
              _toolbar(context),
              _legendBar(context),
              if (_showEarlyArrivalPanel(lanes)) _earlyArrivalPanel(context),
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
                                    child: OrvEventControlBlock(
                                      events: events,
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
