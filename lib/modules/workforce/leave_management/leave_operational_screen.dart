import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../models/workforce_leave_operational.dart';
import '../services/workforce_callable_service.dart';
import '../workforce_date_key.dart';

/// F4 — operativna dostupnost / odsustvo za planiranje (bez medicinskih detalja).
class LeaveOperationalScreen extends StatefulWidget {
  const LeaveOperationalScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<LeaveOperationalScreen> createState() =>
      _LeaveOperationalScreenState();
}

class _LeaveOperationalScreenState extends State<LeaveOperationalScreen> {
  final _svc = WorkforceCallableService();
  Map<String, String> _employeeNames = {};

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
    _loadEmployeeNames();
  }

  Future<void> _loadEmployeeNames() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('workforce_employees')
          .where('companyId', isEqualTo: _companyId)
          .where('plantKey', isEqualTo: _plantKey)
          .limit(300)
          .get();
      final m = <String, String>{};
      for (final d in snap.docs) {
        final e = WorkforceEmployee.fromDoc(d);
        m[e.id] = e.displayName;
      }
      if (mounted) setState(() => _employeeNames = m);
    } catch (_) {}
  }

  String _employeeLabel(String docId) {
    final n = _employeeNames[docId];
    if (n != null && n.isNotEmpty) return '$n · $docId';
    return docId;
  }

  Future<void> _addLeave() async {
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
        const SnackBar(content: Text('Prvo dodaj radnike.')),
      );
      return;
    }

    String? empId = employees.first.id;
    final notes = TextEditingController();
    String availability = 'unavailable';
    String category = 'undisclosed';
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Operativno odsustvo (F4)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ne unositi zdravstvene ili osobne osjetljive podatke u napomenu.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: empId,
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
                    onChanged: (v) => setSt(() => empId = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Od: ${workforceDateKey(start)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: start,
                          firstDate: DateTime(start.year - 1),
                          lastDate: DateTime(start.year + 2),
                        );
                        if (p != null) setSt(() => start = p);
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Do: ${workforceDateKey(end)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: end,
                          firstDate: start,
                          lastDate: DateTime(start.year + 2),
                        );
                        if (p != null) setSt(() => end = p);
                      },
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: availability,
                    decoration: const InputDecoration(
                      labelText: 'Operativna dostupnost',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'unavailable',
                        child: Text('Nedostupan'),
                      ),
                      DropdownMenuItem(value: 'reduced', child: Text('Smanjena')),
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Dostupan (info)'),
                      ),
                      DropdownMenuItem(value: 'unknown', child: Text('Nepoznato')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => availability = v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Kategorija (operativno)',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'undisclosed',
                        child: Text('Ne navodi se'),
                      ),
                      DropdownMenuItem(value: 'annual', child: Text('Godišnji')),
                      DropdownMenuItem(
                        value: 'other_planned',
                        child: Text('Drugo planirano'),
                      ),
                      DropdownMenuItem(
                        value: 'other_unplanned',
                        child: Text('Drugo neplanirano'),
                      ),
                      DropdownMenuItem(
                        value: 'medical_category_operational',
                        child: Text('Medicinsko odsustvo (samo kategorija)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => category = v);
                    },
                  ),
                  TextFormField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'Kratka napomena (bez zdravstvenih podataka)',
                    ),
                    maxLines: 2,
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
    final employeeDocId = empId;
    if (employeeDocId == null) return;

    final startKey = workforceDateKey(start);
    final endKey = workforceDateKey(end);
    if (startKey.compareTo(endKey) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datum početka mora biti prije ili jednak kraju.')),
        );
      }
      return;
    }

    try {
      await _svc.upsertLeaveOperationalStatus(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: employeeDocId,
        dateKeyStart: startKey,
        dateKeyEnd: endKey,
        operationalAvailability: availability,
        leaveCategoryOperational: category,
        notesShort: notes.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operativno odsustvo zabilježeno.')),
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
        .collection('workforce_leave_operational_status')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('dateKeyStart', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Odsustva — operativni sloj'),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _addLeave,
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Greška: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nema operativnih zapisa odsustva. '
                  'Ovo nije HR dosije — samo dostupnost za planiranje.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rows = docs.map(WorkforceLeaveOperational.fromDoc).toList();
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                title: Text(
                  '${r.dateKeyStart} → ${r.dateKeyEnd}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_employeeLabel(r.employeeDocId)}\n'
                  '${r.operationalAvailability} · ${r.leaveCategoryOperational}'
                  '${(r.notesShort ?? '').isNotEmpty ? " · ${r.notesShort}" : ""}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
