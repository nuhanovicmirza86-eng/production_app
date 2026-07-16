import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../services/workforce_callable_service.dart';
import '../widgets/workforce_form_dialog.dart';
import '../widgets/workforce_screen_help.dart';
import '../workforce_attendance_labels.dart';
import '../workforce_date_key.dart';
import '../workforce_shift_labels.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late DateTime _day;
  String _shiftCode = WorkforceShiftLabels.day;
  final _svc = WorkforceCallableService();
  Map<String, String> _employeeNames = const {};

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
    _loadEmployeeNames();
  }

  String get _dateKey => workforceDateKey(_day);

  String get _dayLabel =>
      DateFormat('d. MMMM yyyy.', 'bs').format(_day);

  Future<void> _loadEmployeeNames() async {
    final snap = await FirebaseFirestore.instance
        .collection('workforce_employees')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('displayName')
        .limit(200)
        .get();
    if (!mounted) return;
    setState(() {
      _employeeNames = {
        for (final doc in snap.docs)
          doc.id: WorkforceEmployee.fromDoc(doc).displayName,
      };
    });
  }

  Future<void> _pickDay() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 1),
      lastDate: DateTime(_day.year + 1),
      helpText: 'Odaberite dan',
      cancelText: 'Odustani',
      confirmText: 'Potvrdi',
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
    String status = WorkforceAttendanceLabels.present;
    final note = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return WorkforceFormDialog(
            title: 'Evidencija prisutnosti',
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
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
                            e.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => chosenId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Operativni status',
                  ),
                  items: WorkforceAttendanceLabels.dropdownItems(),
                  onChanged: (v) {
                    if (v != null) setSt(() => status = v);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Kratka napomena (bez zdravstvenih podataka)',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final noteText = note.text.trim();
    note.dispose();

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
        noteShort: noteText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prisutnost zabilježena.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Spremanje nije uspjelo.')),
        );
      }
    }
  }

  String _employeeLabel(String employeeDocId) {
    final name = (_employeeNames[employeeDocId] ?? '').trim();
    return name.isEmpty ? 'Radnik nije pronađen' : name;
  }

  String _employeeInitial(String employeeDocId) {
    final name = _employeeLabel(employeeDocId);
    if (name == 'Radnik nije pronađen') return '?';
    return name.substring(0, 1).toUpperCase();
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
          const WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.attendanceTitle,
            message: WorkforceHelpTexts.attendanceMessage,
          ),
          PopupMenuButton<String>(
            tooltip: 'Smjena: ${WorkforceShiftLabels.label(_shiftCode)}',
            icon: const Icon(Icons.filter_list_outlined),
            initialValue: _shiftCode,
            onSelected: (v) => setState(() => _shiftCode = v),
            itemBuilder: (ctx) => WorkforceShiftLabels.popupEntries(),
          ),
          IconButton(
            tooltip: 'Datum: $_dayLabel',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDay,
          ),
          if (_canManage)
            IconButton(
              tooltip: 'Nova evidencija prisutnosti',
              icon: const Icon(Icons.add),
              onPressed: _addEntry,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Učitavanje nije uspjelo. Pokušajte ponovo.'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!.docs
              .where(
                (d) =>
                    (d.data()['shiftCode'] ?? '').toString() == _shiftCode,
              )
              .toList();
          if (rows.isEmpty) {
            return Center(
              child: Text(
                'Nema zapisa za $_dayLabel · '
                '${WorkforceShiftLabels.shortLabel(_shiftCode)}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = rows[i].data();
              final emp = (m['employeeDocId'] ?? '').toString();
              final status = (m['operationalStatus'] ?? '').toString();
              final note = (m['noteShort'] ?? '').toString().trim();
              final parts = <String>[
                WorkforceShiftLabels.label(_shiftCode),
                WorkforceAttendanceLabels.label(status),
                if (note.isNotEmpty) note,
              ];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(_employeeInitial(emp)),
                ),
                title: Text(_employeeLabel(emp)),
                subtitle: Text(parts.join(' · ')),
              );
            },
          );
        },
      ),
    );
  }
}
