import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../models/workforce_qualification.dart';
import '../services/workforce_callable_service.dart';
import '../widgets/workforce_form_dialog.dart';
import '../widgets/workforce_screen_help.dart';
import '../workforce_qualification_labels.dart';
import 'qualification_expiry_screen.dart';

class SkillsMatrixScreen extends StatefulWidget {
  const SkillsMatrixScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<SkillsMatrixScreen> createState() => _SkillsMatrixScreenState();
}

class _SkillsMatrixScreenState extends State<SkillsMatrixScreen> {
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

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadEmployeeNames();
  }

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

  String _employeeLabel(String employeeDocId) {
    final name = (_employeeNames[employeeDocId] ?? '').trim();
    return name.isEmpty ? 'Radnik nije pronađen' : name;
  }

  Future<void> _addRow() async {
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
    String dimType = WorkforceQualificationLabels.machine;
    final dimId = TextEditingController();
    int level = 0;
    String status = 'in_training';
    String approvalStatus = 'approved';
    DateTime? validUntilDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return WorkforceFormDialog(
            title: 'Nova kvalifikacija',
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: empId,
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
                  onChanged: (v) => setSt(() => empId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: dimType,
                  decoration: const InputDecoration(
                    labelText: 'Vrsta kvalifikacije',
                  ),
                  items: WorkforceQualificationLabels.dimensionTypeItems(),
                  onChanged: (v) {
                    if (v != null) setSt(() => dimType = v);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: dimId,
                  decoration: const InputDecoration(
                    labelText: 'Oznaka stroja, procesa ili operacije *',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Nivo'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0')),
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSt(() => level = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: WorkforceQualificationLabels.statusItems(),
                  onChanged: (v) {
                    if (v != null) setSt(() => status = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: approvalStatus,
                  decoration: const InputDecoration(labelText: 'Odobrenje'),
                  items: WorkforceQualificationLabels.approvalItems(),
                  onChanged: (v) {
                    if (v != null) setSt(() => approvalStatus = v);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    validUntilDate == null
                        ? 'Važi do (opcionalno)'
                        : 'Važi do: ${_isoDate(validUntilDate!)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (validUntilDate != null)
                        IconButton(
                          tooltip: 'Ukloni datum',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setSt(() => validUntilDate = null),
                        ),
                      IconButton(
                        tooltip: 'Odaberi datum',
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: ctx,
                            initialDate: validUntilDate ??
                                DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (p != null) {
                            setSt(() => validUntilDate = p);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (ok != true) return;
    final employeeDocId = empId;
    if (employeeDocId == null) return;
    final dimensionId = dimId.text.trim();
    dimId.dispose();
    if (dimensionId.isEmpty) return;

    try {
      await _svc.upsertQualification(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: employeeDocId,
        dimensionType: dimType,
        dimensionId: dimensionId,
        level: level,
        status: status,
        approvalStatus: approvalStatus,
        validUntilIso: validUntilDate != null
            ? validUntilDate!.toUtc().toIso8601String()
            : '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kvalifikacija spremljena.')),
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

  Future<void> _onRowTap(WorkforceQualification r) async {
    if (!_canManage) {
      if (!mounted) return;
      if (r.effectiveApproval == 'pending_approval') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kvalifikacija čeka odobrenje — odluku može donijeti upravljač.',
            ),
          ),
        );
      }
      return;
    }
    if (r.effectiveApproval != 'pending_approval') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${WorkforceQualificationLabels.dimensionTypeLabel(r.dimensionType)}: '
            '${r.dimensionId} — '
            '${WorkforceQualificationLabels.approvalLabel(r.effectiveApproval)}',
          ),
        ),
      );
      return;
    }

    final note = TextEditingController();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Odobrenje kvalifikacije',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${WorkforceQualificationLabels.dimensionTypeLabel(r.dimensionType)}: '
              '${r.dimensionId} · ${_employeeLabel(r.employeeDocId)}',
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Napomena (opcionalno)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'rejected'),
                    child: const Text('Odbij'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'approved'),
                    child: const Text('Odobri'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    try {
      await _svc.resolveQualificationApproval(
        companyId: _companyId,
        plantKey: _plantKey,
        qualificationDocId: r.id,
        resolution: action,
        note: note.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odluka o odobrenju snimljena.')),
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
        .collection('workforce_qualifications')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .limit(250);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrica kvalifikacija'),
        actions: [
          const WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.skillsMatrixTitle,
            message: WorkforceHelpTexts.skillsMatrixMessage,
          ),
          IconButton(
            icon: const Icon(Icons.event_busy_outlined),
            tooltip: 'Istek i revalidacija',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      QualificationExpiryScreen(companyData: widget.companyData),
                ),
              );
            },
          ),
          if (_canManage)
            IconButton(
              tooltip: 'Nova kvalifikacija',
              icon: const Icon(Icons.add),
              onPressed: _addRow,
            ),
        ],
      ),
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
            return Center(
              child: Text(
                'Nema unosa u matrici.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          final rows = docs.map(WorkforceQualification.fromDoc).toList();
          rows.sort((a, b) {
            final c = a.employeeDocId.compareTo(b.employeeDocId);
            if (c != 0) return c;
            return a.dimensionId.compareTo(b.dimensionId);
          });
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              final sub = <String>[
                _employeeLabel(r.employeeDocId),
                'Nivo ${r.level}',
                WorkforceQualificationLabels.statusLabel(r.status),
                WorkforceQualificationLabels.approvalLabel(r.effectiveApproval),
                if (r.validUntil != null)
                  'Do ${_isoDate(r.validUntil!)}${r.isExpired ? ' · isteklo' : ''}',
              ].join(' · ');
              return ListTile(
                title: Text(
                  '${WorkforceQualificationLabels.dimensionTypeLabel(r.dimensionType)}: '
                  '${r.dimensionId}',
                ),
                subtitle: Text(sub),
                trailing: r.effectiveApproval == 'pending_approval'
                    ? const Icon(Icons.pending_actions_outlined)
                    : null,
                onTap: () => _onRowTap(r),
              );
            },
          );
        },
      ),
    );
  }
}
