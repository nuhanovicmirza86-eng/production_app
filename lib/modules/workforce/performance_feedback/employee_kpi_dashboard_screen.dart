import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../features/process_evidence_analytics/models/process_evidence_analytics_models.dart';
import '../../../features/process_evidence_analytics/services/process_evidence_analytics_callable_service.dart';
import '../../production/ooe/models/machine_state_event.dart';
import '../../production/tracking/models/production_operator_tracking_entry.dart';
import '../models/workforce_employee.dart';
import '../workforce_date_key.dart';
import 'workforce_evidence_kpi_section.dart';

/// F3: objektivni KPI — legacy (operativno praćenje / MES) + M2-F profile-driven evidencije.
class EmployeeKpiDashboardScreen extends StatefulWidget {
  const EmployeeKpiDashboardScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<EmployeeKpiDashboardScreen> createState() =>
      _EmployeeKpiDashboardScreenState();
}

class _EmployeeKpiDashboardScreenState extends State<EmployeeKpiDashboardScreen> {
  final _analyticsService = ProcessEvidenceAnalyticsCallableService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  WorkforceEmployee? _employee;
  List<WorkforceEmployee> _employees = [];
  bool _loadingEmployees = true;
  bool _loadingLegacyKpi = false;
  bool _loadingEvidenceKpi = false;
  String? _legacyKpiError;
  Object? _evidenceKpiError;

  late DateTime _dateFrom;
  late DateTime _dateTo;

  int _trackingMatchCount = 0;
  double _totalGood = 0;
  double _totalScrap = 0;
  int _machineEventMatchCount = 0;
  int _downtimeSecondsAttributed = 0;

  WorkerPerformanceKpiRow? _evidenceKpiRow;
  Map<String, List<ProcessEvidenceBreakdownRow>> _evidenceBreakdowns = const {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTo = DateTime(now.year, now.month, now.day);
    _dateFrom = _dateTo.subtract(const Duration(days: 30));
    _loadEmployees();
  }

  String _formatDisplayDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  ProcessEvidenceAnalyticsFilters get _evidenceFilters =>
      ProcessEvidenceAnalyticsFilters(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        plantKey: _plantKey.isEmpty ? null : _plantKey,
      );

  Set<String> _candidateOperatorIds(WorkforceEmployee emp) {
    final ids = <String>{emp.id.trim()};
    final uid = emp.linkedUserUid?.trim() ?? '';
    if (uid.isNotEmpty) ids.add(uid);
    return ids;
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('workforce_employees')
          .where('companyId', isEqualTo: _companyId)
          .where('plantKey', isEqualTo: _plantKey)
          .orderBy('displayName')
          .limit(200)
          .get();
      final list = snap.docs.map(WorkforceEmployee.fromDoc).toList();
      if (!mounted) return;
      setState(() {
        _employees = list;
        _employee = list.isEmpty ? null : list.first;
        _loadingEmployees = false;
      });
      await _loadAllKpi();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEmployees = false;
        _legacyKpiError = '$e';
      });
    }
  }

  Future<void> _loadAllKpi() async {
    await Future.wait([
      _loadLegacyKpi(),
      _loadEvidenceKpi(),
    ]);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(_dateTo)) _dateFrom = _dateTo;
      }
    });
    await _loadAllKpi();
  }

  void _applyPeriodDays(int days) {
    final end = DateTime.now();
    setState(() {
      _dateTo = DateTime(end.year, end.month, end.day);
      _dateFrom = _dateTo.subtract(Duration(days: days));
    });
    _loadAllKpi();
  }

  Future<void> _loadLegacyKpi() async {
    final emp = _employee;
    if (emp == null || _companyId.isEmpty || _plantKey.isEmpty) {
      setState(() {
        _trackingMatchCount = 0;
        _totalGood = 0;
        _totalScrap = 0;
        _machineEventMatchCount = 0;
        _downtimeSecondsAttributed = 0;
      });
      return;
    }

    setState(() {
      _loadingLegacyKpi = true;
      _legacyKpiError = null;
    });

    final startKey = workforceDateKey(_dateFrom);
    final endKey = workforceDateKey(_dateTo);
    final startTs = Timestamp.fromDate(
      DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day),
    );
    final endTs = Timestamp.fromDate(
      DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59),
    );

    try {
      final tSnap = await FirebaseFirestore.instance
          .collection('production_operator_tracking')
          .where('companyId', isEqualTo: _companyId)
          .where('plantKey', isEqualTo: _plantKey)
          .where('workDate', isGreaterThanOrEqualTo: startKey)
          .where('workDate', isLessThanOrEqualTo: endKey)
          .limit(500)
          .get();

      final mSnap = await FirebaseFirestore.instance
          .collection('machine_state_events')
          .where('companyId', isEqualTo: _companyId)
          .where('plantKey', isEqualTo: _plantKey)
          .where('startedAt', isGreaterThanOrEqualTo: startTs)
          .where('startedAt', isLessThanOrEqualTo: endTs)
          .limit(400)
          .get();

      double good = 0;
      double scrap = 0;
      var tCount = 0;
      for (final d in tSnap.docs) {
        final e = ProductionOperatorTrackingEntry.fromDoc(d);
        if (!_matchesTracking(emp, e)) continue;
        tCount++;
        good += e.effectiveGoodQty;
        scrap += e.scrapTotalQty;
      }

      var mCount = 0;
      var downSec = 0;
      for (final d in mSnap.docs) {
        final ev = MachineStateEvent.fromDoc(d);
        if (!_matchesMachineEvent(emp, ev)) continue;
        mCount++;
        if (ev.state != MachineStateEvent.stateRunning &&
            ev.durationSeconds != null &&
            ev.durationSeconds! > 0) {
          downSec += ev.durationSeconds!;
        }
      }

      if (!mounted) return;
      setState(() {
        _trackingMatchCount = tCount;
        _totalGood = good;
        _totalScrap = scrap;
        _machineEventMatchCount = mCount;
        _downtimeSecondsAttributed = downSec;
        _loadingLegacyKpi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLegacyKpi = false;
        _legacyKpiError = '$e';
      });
    }
  }

  Future<void> _loadEvidenceKpi() async {
    final emp = _employee;
    if (emp == null || _companyId.isEmpty) {
      setState(() {
        _evidenceKpiRow = null;
        _evidenceBreakdowns = const {};
      });
      return;
    }

    setState(() {
      _loadingEvidenceKpi = true;
      _evidenceKpiError = null;
    });

    try {
      final candidates = _candidateOperatorIds(emp);
      WorkerPerformanceKpiRow? matched;
      String? matchedOperatorId;

      for (final operatorId in candidates) {
        final filters = ProcessEvidenceAnalyticsFilters(
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          plantKey: _plantKey.isEmpty ? null : _plantKey,
          operatorId: operatorId,
        );
        final snapshot = await _analyticsService.getWorkerPerformanceKpiSnapshot(
          companyId: _companyId,
          filters: filters,
        );
        for (final row in snapshot.operators) {
          if (candidates.contains(row.operatorId.trim())) {
            matched = row;
            matchedOperatorId = row.operatorId.trim();
            break;
          }
        }
        if (matched != null) break;
      }

      if (matched == null) {
        final snapshot = await _analyticsService.getWorkerPerformanceKpiSnapshot(
          companyId: _companyId,
          filters: _evidenceFilters,
        );
        for (final row in snapshot.operators) {
          if (candidates.contains(row.operatorId.trim())) {
            matched = row;
            matchedOperatorId = row.operatorId.trim();
            break;
          }
        }
      }

      final breakdowns = <String, List<ProcessEvidenceBreakdownRow>>{};
      if (matchedOperatorId != null) {
        final breakdownFilters = ProcessEvidenceAnalyticsFilters(
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          plantKey: _plantKey.isEmpty ? null : _plantKey,
          operatorId: matchedOperatorId,
        );
        for (final dimension in const [
          'profile',
          'operation_type',
          'product',
          'scrap_reason',
        ]) {
          breakdowns[dimension] = await _analyticsService.getBreakdown(
            companyId: _companyId,
            filters: breakdownFilters,
            dimension: dimension,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _evidenceKpiRow = matched;
        _evidenceBreakdowns = breakdowns;
        _loadingEvidenceKpi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvidenceKpi = false;
        _evidenceKpiError = e;
        _evidenceKpiRow = null;
        _evidenceBreakdowns = const {};
      });
    }
  }

  static bool _matchesTracking(
    WorkforceEmployee emp,
    ProductionOperatorTrackingEntry e,
  ) {
    final link = emp.linkedUserUid?.trim() ?? '';
    if (link.isNotEmpty && e.createdByUid == link) return true;
    final name = emp.displayName.trim().toLowerCase();
    if (name.isEmpty) return false;
    final prep = (e.preparedByDisplayName ?? '').toLowerCase().trim();
    if (prep.isNotEmpty && (prep.contains(name) || name.contains(prep))) {
      return true;
    }
    final raw = (e.rawWorkOperatorName ?? '').toLowerCase().trim();
    if (raw.isNotEmpty && (raw.contains(name) || name.contains(raw))) {
      return true;
    }
    return false;
  }

  static bool _matchesMachineEvent(WorkforceEmployee emp, MachineStateEvent ev) {
    final link = emp.linkedUserUid?.trim() ?? '';
    if (link.isEmpty) return false;
    return (ev.createdBy ?? '').trim() == link;
  }

  bool get _loadingKpi => _loadingLegacyKpi || _loadingEvidenceKpi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI radnika (F3)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingKpi ? null : _loadAllKpi,
          ),
        ],
      ),
      body: _loadingEmployees
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Objektivni KPI iz više izvora: profile-driven evidencije procesa (M2-F) '
                  'i legacy agregati iz operativnog praćenja te MES događaja stanja stroja. '
                  'Subjektivni feedback rukovodioca je u kartici '
                  '„Performanse i povratne informacije“.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 16),
                if (_employees.isEmpty)
                  const Text('Nema radnika u pogonu.')
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _employee?.id,
                    decoration: const InputDecoration(
                      labelText: 'Radnik',
                    ),
                    items: _employees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              '${e.displayName} (${e.employeeCode})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _employee =
                            _employees.firstWhere((e) => e.id == v);
                      });
                      _loadAllKpi();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _dateField(
                        label: 'Period od',
                        value: _formatDisplayDate(_dateFrom),
                        onTap: () => _pickDate(isFrom: true),
                      ),
                      _dateField(
                        label: 'Period do',
                        value: _formatDisplayDate(_dateTo),
                        onTap: () => _pickDate(isFrom: false),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [7, 30, 90].map((d) {
                          final days = _dateTo.difference(_dateFrom).inDays;
                          final sel = days == d;
                          return ChoiceChip(
                            label: Text('$d d'),
                            selected: sel,
                            onSelected: (_) => _applyPeriodDays(d),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  WorkforceEvidenceKpiSection(
                    kpiRow: _evidenceKpiRow,
                    breakdowns: _evidenceBreakdowns,
                    loading: _loadingEvidenceKpi,
                    error: _evidenceKpiError != null
                        ? processEvidenceAnalyticsErrorMessage(
                            _evidenceKpiError!,
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Legacy KPI (operativno praćenje i MES)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agregacija iz operativnog praćenja (output/škart) i događaja stanja stroja '
                    'gdje je [createdBy] jednak [linkedUserUid] radnika.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_legacyKpiError != null)
                    Text(
                      _legacyKpiError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_loadingLegacyKpi)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _kpiCard(
                      context,
                      title: 'Operativno praćenje',
                      lines: [
                        'Povezani unosi: $_trackingMatchCount',
                        'Dobra količina (procjena): ${_fmtNum(_totalGood)}',
                        'Škart (zbir): ${_fmtNum(_totalScrap)}',
                        if (_totalGood + _totalScrap > 0)
                          'Udio škarta: ${_fmtPct(_totalScrap / (_totalGood + _totalScrap))}',
                      ],
                    ),
                    const SizedBox(height: 12),
                    _kpiCard(
                      context,
                      title: 'MES — događaji stanja (uz UID)',
                      lines: [
                        'Povezani događaji: $_machineEventMatchCount',
                        'Zbir trajanja zatvorenih segm. (ne running): ${_fmtDuration(_downtimeSecondsAttributed)}',
                      ],
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(value),
        ),
      ),
    );
  }

  Widget _kpiCard(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l),
                )),
          ],
        ),
      ),
    );
  }

  static String _fmtNum(double x) {
    if (x == x.roundToDouble()) return x.round().toString();
    return x.toStringAsFixed(2);
  }

  static String _fmtPct(double x) {
    if (x.isNaN) return '—';
    return '${(x * 100).toStringAsFixed(1)} %';
  }

  static String _fmtDuration(int sec) {
    if (sec <= 0) return '0 min';
    final m = sec ~/ 60;
    final h = m ~/ 60;
    if (h > 0) return '${h}h ${m % 60}min';
    return '$m min';
  }
}
