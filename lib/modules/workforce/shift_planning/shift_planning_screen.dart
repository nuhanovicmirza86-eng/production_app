import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../services/workforce_callable_service.dart';
import '../widgets/workforce_screen_help.dart';
import '../workforce_date_key.dart';
import '../workforce_shift_labels.dart';

class ShiftPlanningScreen extends StatefulWidget {
  const ShiftPlanningScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ShiftPlanningScreen> createState() => _ShiftPlanningScreenState();
}

class _ShiftPlanningScreenState extends State<ShiftPlanningScreen> {
  late DateTime _day;
  String _shiftFilter = WorkforceShiftLabels.day;
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

  bool get _canBypassQualCheck =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

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
          content: Text('Prvo unesite radnike u operativnom profilu.'),
        ),
      );
      return;
    }

    String? chosenId = employees.first.id;
    final placement = TextEditingController();
    final roleTag = TextEditingController();
    String shift = _shiftFilter == WorkforceShiftLabels.all
        ? WorkforceShiftLabels.day
        : _shiftFilter;
    final skipQualHolder = <bool>[false];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nova dodjela smjene',
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Odustani',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          IconButton(
                            tooltip: 'Spremi',
                            icon: const Icon(Icons.check),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                        initialValue: shift,
                        decoration: const InputDecoration(labelText: 'Smjena'),
                        items: WorkforceShiftLabels.dropdownItems(),
                        onChanged: (v) {
                          if (v != null) setSt(() => shift = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: placement,
                        decoration: const InputDecoration(
                          labelText: 'Linija ili stroj (opcionalno)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: roleTag,
                        decoration: const InputDecoration(
                          labelText: 'Uloga na smjeni (opcionalno)',
                        ),
                      ),
                      if (_canBypassQualCheck) ...[
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Preskoči provjeru kvalifikacije za stroj',
                          ),
                          subtitle: const Text('Samo administrator'),
                          value: skipQualHolder[0],
                          onChanged: (v) =>
                              setSt(() => skipQualHolder[0] = v ?? false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    placement.dispose();
    roleTag.dispose();

    if (ok != true) {
      placement.dispose();
      roleTag.dispose();
      return;
    }
    final employeeDocId = chosenId;
    if (employeeDocId == null) {
      placement.dispose();
      roleTag.dispose();
      return;
    }

    final placementText = placement.text.trim();
    final roleTagText = roleTag.text.trim();
    placement.dispose();
    roleTag.dispose();

    try {
      await _svc.upsertShiftAssignment(
        companyId: _companyId,
        plantKey: _plantKey,
        dateKey: _dateKey,
        shiftCode: shift,
        employeeDocId: employeeDocId,
        placementType: placementText.isEmpty ? 'plant' : 'machine',
        placementId: placementText,
        roleTag: roleTagText,
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
    if (name.isEmpty || name == 'Radnik nije pronađen') return '?';
    return name.substring(0, 1).toUpperCase();
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
          const WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.shiftPlanningTitle,
            message: WorkforceHelpTexts.shiftPlanningMessage,
          ),
          PopupMenuButton<String>(
            tooltip: 'Smjena: ${WorkforceShiftLabels.label(_shiftFilter)}',
            icon: const Icon(Icons.filter_list_outlined),
            initialValue: _shiftFilter,
            onSelected: (v) => setState(() => _shiftFilter = v),
            itemBuilder: (ctx) => WorkforceShiftLabels.popupEntries(
              includeAll: true,
            ),
          ),
          IconButton(
            tooltip: 'Datum: $_dayLabel',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDay,
          ),
          if (_canManage)
            IconButton(
              tooltip: 'Nova dodjela smjene',
              icon: const Icon(Icons.add),
              onPressed: _addAssignment,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Učitavanje nije uspjelo. Pokušajte ponovo.'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var rows = snap.data!.docs;
          if (_shiftFilter != WorkforceShiftLabels.all) {
            rows = rows
                .where(
                  (d) =>
                      (d.data()['shiftCode'] ?? '').toString() ==
                      _shiftFilter,
                )
                .toList();
          }
          if (rows.isEmpty) {
            return Center(
              child: Text(
                'Nema dodjela za $_dayLabel.',
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
              final sc = (m['shiftCode'] ?? '').toString();
              final pl = (m['placementId'] ?? '').toString();
              final rt = (m['roleTag'] ?? '').toString();
              final parts = <String>[
                WorkforceShiftLabels.label(sc),
                if (pl.isNotEmpty) 'Mjesto: $pl',
                if (rt.isNotEmpty) 'Uloga: $rt',
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
