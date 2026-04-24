import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../services/workforce_callable_service.dart';
import '../workforce_date_key.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late DateTime _day;
  String _shiftCode = 'DAY';
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

  Future<void> _addEntry() async {
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
        const SnackBar(content: Text('Nema radnika u pogonu.')),
      );
      return;
    }

    String? chosenId = employees.first.id;
    String status = 'present';
    final note = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Evidencija prisutnosti'),
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
                    initialValue: status,
                    decoration:
                        const InputDecoration(labelText: 'Operativni status'),
                    items: const [
                      DropdownMenuItem(value: 'present', child: Text('Prisutan')),
                      DropdownMenuItem(value: 'absent', child: Text('Odsutan')),
                      DropdownMenuItem(value: 'late', child: Text('Kašnjenje')),
                      DropdownMenuItem(
                        value: 'leave_operational',
                        child: Text('Odsustvo (operativno)'),
                      ),
                      DropdownMenuItem(value: 'unknown', child: Text('Nepoznato')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => status = v);
                    },
                  ),
                  TextFormField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Kratka napomena (bez zdravstvenih podataka)',
                    ),
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
      await _svc.upsertAttendanceEntry(
        companyId: _companyId,
        plantKey: _plantKey,
        dateKey: _dateKey,
        shiftCode: _shiftCode,
        employeeDocId: employeeDocId,
        operationalStatus: status,
        noteShort: note.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prisutnost zabilježena.')),
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
        .collection('workforce_attendance_entries')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .where('dateKey', isEqualTo: _dateKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prisutnost'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDay,
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _addEntry,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Datum: $_dateKey',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButton<String>(
                  value: _shiftCode,
                  items: const [
                    DropdownMenuItem(value: 'DAY', child: Text('DAY')),
                    DropdownMenuItem(value: 'NIGHT', child: Text('NIGHT')),
                    DropdownMenuItem(value: 'AFTERNOON', child: Text('AFTERNOON')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _shiftCode = v);
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
                final rows = snap.data!.docs
                    .where(
                      (d) =>
                          (d.data()['shiftCode'] ?? '').toString() ==
                          _shiftCode,
                    )
                    .toList();
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('Nema zapisa za ovaj dan i smjenu.'),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = rows[i].data();
                    return ListTile(
                      title: Text(
                        (m['operationalStatus'] ?? '').toString(),
                      ),
                      subtitle: Text(
                        'Radnik: ${m['employeeDocId'] ?? ''}'
                        '${(m['noteShort'] ?? '').toString().isEmpty ? '' : ' · ${m['noteShort']}'}',
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
