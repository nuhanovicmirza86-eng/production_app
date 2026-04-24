import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../production/ooe/models/machine_state_event.dart';
import '../../production/tracking/models/production_operator_tracking_entry.dart';
import '../models/workforce_employee.dart';
import '../workforce_date_key.dart';

/// F3: objektivni KPI iz operativnog praćenja (output/škart) i MES stanja (događaji vezani uz UID).
class EmployeeKpiDashboardScreen extends StatefulWidget {
  const EmployeeKpiDashboardScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<EmployeeKpiDashboardScreen> createState() =>
      _EmployeeKpiDashboardScreenState();
}

class _EmployeeKpiDashboardScreenState extends State<EmployeeKpiDashboardScreen> {
  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  int _periodDays = 30;
  WorkforceEmployee? _employee;
  List<WorkforceEmployee> _employees = [];
  bool _loadingEmployees = true;
  bool _loadingKpi = false;
  String? _kpiError;

  int _trackingMatchCount = 0;
  double _totalGood = 0;
  double _totalScrap = 0;
  int _machineEventMatchCount = 0;
  int _downtimeSecondsAttributed = 0;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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
      await _loadKpi();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEmployees = false;
        _kpiError = '$e';
      });
    }
  }

  Future<void> _loadKpi() async {
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
      _loadingKpi = true;
      _kpiError = null;
    });

    final end = DateTime.now();
    final start = end.subtract(Duration(days: _periodDays));
    final startKey = workforceDateKey(start);
    final endKey = workforceDateKey(end);
    final startTs = Timestamp.fromDate(
      DateTime(start.year, start.month, start.day),
    );
    final endTs = Timestamp.fromDate(
      DateTime(end.year, end.month, end.day, 23, 59, 59),
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
        _loadingKpi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingKpi = false;
        _kpiError = '$e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI radnika (F3)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingKpi ? null : _loadKpi,
          ),
        ],
      ),
      body: _loadingEmployees
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Agregacija iz operativnog praćenja (output/škart) i događaja stanja stroja '
                  'gdje je [createdBy] jednak [linkedUserUid] radnika. '
                  'Za pouzdaniju vezu poveži radnika s Firebase korisnikom u profilu.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      _loadKpi();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [7, 30, 90].map((d) {
                      final sel = _periodDays == d;
                      return ChoiceChip(
                        label: Text('$d d'),
                        selected: sel,
                        onSelected: (_) {
                          setState(() => _periodDays = d);
                          _loadKpi();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  if (_kpiError != null)
                    Text(
                      _kpiError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_loadingKpi)
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
