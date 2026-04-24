import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../services/workforce_callable_service.dart';
import '../workforce_date_key.dart';

class ShiftPlanningScreen extends StatefulWidget {
  const ShiftPlanningScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ShiftPlanningScreen> createState() => _ShiftPlanningScreenState();
}

class _ShiftPlanningScreenState extends State<ShiftPlanningScreen> {
  late DateTime _day;
  String _shiftFilter = 'DAY';
  final _svc = WorkforceCallableService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canManage => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.shifts,
      );

  bool get _canBypassQualCheck =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
  }

  String get _dateKey => workforceDateKey(_day);

  Future<void> _pickDay() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 1),
      lastDate: DateTime(_day.year + 1),
    );
    if (p != null) {
      setState(() => _day = DateTime(p.year, p.month, p.day));
    }
  }

  Future<void> _addAssignment() async {
    final employeesSnap = await FirebaseFirestore.instance
        .collection('workforce_employees')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('displayName')
        .limit(120)
        .get();

    final employees =
        employeesSnap.docs.map(WorkforceEmployee.fromDoc).toList();
    if (!mounted) return;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prvo dodaj radnike u operativnom profilu.'),
        ),
      );
      return;
    }

    String? chosenId = employees.first.id;
    final placement = TextEditingController();
    final roleTag = TextEditingController();
    String shift = _shiftFilter == '_ALL' ? 'DAY' : _shiftFilter;
    final skipQualHolder = <bool>[false];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Nova dodjela smjene'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: chosenId,
                    decoration: const InputDecoration(labelText: 'Radnik'),
                    items: employees
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
                    onChanged: (v) => setSt(() => chosenId = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: shift,
                    decoration: const InputDecoration(labelText: 'Smjena'),
                    items: const [
                      DropdownMenuItem(value: 'DAY', child: Text('DAY')),
                      DropdownMenuItem(value: 'NIGHT', child: Text('NIGHT')),
                      DropdownMenuItem(
                        value: 'AFTERNOON',
                        child: Text('AFTERNOON'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => shift = v);
                    },
                  ),
                  TextFormField(
                    controller: placement,
                    decoration: const InputDecoration(
                      labelText: 'Linija / stroj (opcionalno ID)',
                    ),
                  ),
                  TextFormField(
                    controller: roleTag,
                    decoration: const InputDecoration(
                      labelText: 'Uloga na smjeni (opcionalno)',
                    ),
                  ),
                  if (_canBypassQualCheck)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Preskoči provjeru kvalifikacije za stroj (samo admin)',
                      ),
                      value: skipQualHolder[0],
                      onChanged: (v) =>
                          setSt(() => skipQualHolder[0] = v ?? false),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Spremi'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;
    final employeeDocId = chosenId;
    if (employeeDocId == null) return;

    try {
      final pid = placement.text.trim();
      await _svc.upsertShiftAssignment(
        companyId: _companyId,
        plantKey: _plantKey,
        dateKey: _dateKey,
        shiftCode: shift,
        employeeDocId: employeeDocId,
        placementType: pid.isEmpty ? 'plant' : 'machine',
        placementId: pid,
        roleTag: roleTag.text.trim(),
        skipQualificationCheck: skipQualHolder[0],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodjela spremljena.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Greška')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('workforce_shift_assignments')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .where('dateKey', isEqualTo: _dateKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspored smjena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDay,
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _addAssignment,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Datum: $_dateKey',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButton<String>(
                  value: _shiftFilter,
                  items: const [
                    DropdownMenuItem(value: 'DAY', child: Text('DAY')),
                    DropdownMenuItem(value: 'NIGHT', child: Text('NIGHT')),
                    DropdownMenuItem(value: 'AFTERNOON', child: Text('AFTERNOON')),
                    DropdownMenuItem(value: '_ALL', child: Text('Sve smjene')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _shiftFilter = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Greška: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var rows = snap.data!.docs;
                if (_shiftFilter != '_ALL') {
                  rows = rows
                      .where(
                        (d) =>
                            (d.data()['shiftCode'] ?? '').toString() ==
                            _shiftFilter,
                      )
                      .toList();
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('Nema dodjela za ovaj dan.'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = rows[i].data();
                    final emp = (m['employeeDocId'] ?? '').toString();
                    final sc = (m['shiftCode'] ?? '').toString();
                    final pl = (m['placementId'] ?? '').toString();
                    final rt = (m['roleTag'] ?? '').toString();
                    return ListTile(
                      title: Text('Radnik doc: $emp'),
                      subtitle: Text(
                        [
                          'Smjena: $sc',
                          if (pl.isNotEmpty) 'Mjesto: $pl',
                          if (rt.isNotEmpty) 'Uloga: $rt',
                        ].join(' · '),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
