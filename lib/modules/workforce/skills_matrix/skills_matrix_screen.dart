import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../models/workforce_qualification.dart';
import '../services/workforce_callable_service.dart';
import 'qualification_expiry_screen.dart';

class SkillsMatrixScreen extends StatefulWidget {
  const SkillsMatrixScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<SkillsMatrixScreen> createState() => _SkillsMatrixScreenState();
}

class _SkillsMatrixScreenState extends State<SkillsMatrixScreen> {
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

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    final dimType = TextEditingController(text: 'machine');
    final dimId = TextEditingController();
    int level = 0;
    String status = 'in_training';
    String approvalStatus = 'approved';
    DateTime? validUntilDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Nova kvalifikacija (F2)'),
            content: SingleChildScrollView(
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
                              '${e.displayName} (${e.employeeCode})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => empId = v),
                  ),
                  TextFormField(
                    controller: dimType,
                    decoration: const InputDecoration(
                      labelText: 'Tip dimenzije (machine / process / operation)',
                    ),
                  ),
                  TextFormField(
                    controller: dimId,
                    decoration: const InputDecoration(
                      labelText: 'ID stroja / procesa / operacije *',
                    ),
                  ),
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
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'qualified',
                        child: Text('Kvalificiran'),
                      ),
                      DropdownMenuItem(
                        value: 'in_training',
                        child: Text('U obuci'),
                      ),
                      DropdownMenuItem(
                        value: 'not_qualified',
                        child: Text('Nije kvalificiran'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Isteklo'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => status = v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: approvalStatus,
                    decoration: const InputDecoration(
                      labelText: 'Odobrenje (F2)',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Odobreno'),
                      ),
                      DropdownMenuItem(
                        value: 'pending_approval',
                        child: Text('Čeka odobrenje'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => approvalStatus = v);
                    },
                  ),
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
                            icon: const Icon(Icons.clear),
                            onPressed: () => setSt(() => validUntilDate = null),
                          ),
                        IconButton(
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
    if (dimId.text.trim().isEmpty) return;

    try {
      await _svc.upsertQualification(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: employeeDocId,
        dimensionType: dimType.text.trim(),
        dimensionId: dimId.text.trim(),
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
            '${r.dimensionType}:${r.dimensionId} — odobrenje: ${r.effectiveApproval}',
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
            Text('${r.dimensionType}:${r.dimensionId} · radnik ${r.employeeDocId}'),
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
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _addRow,
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
              child: Text('Nema redaka matrice. Dodaj prvi red (+).'),
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
                'Radnik ${r.employeeDocId}',
                'nivo ${r.level}',
                r.status,
                'odobrenje: ${r.effectiveApproval}',
                if (r.validUntil != null)
                  'do ${_isoDate(r.validUntil!)}${r.isExpired ? " (isteklo)" : ""}',
              ].join(' · ');
              return ListTile(
                title: Text('${r.dimensionType}:${r.dimensionId}'),
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
