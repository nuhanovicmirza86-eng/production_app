import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_employee.dart';
import '../models/workforce_training_record.dart';
import '../services/workforce_callable_service.dart';

class TrainingListScreen extends StatefulWidget {
  const TrainingListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<TrainingListScreen> createState() => _TrainingListScreenState();
}

class _TrainingListScreenState extends State<TrainingListScreen> {
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

  Future<void> _addRecord() async {
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
    final title = TextEditingController();
    final trainer = TextEditingController();
    final notes = TextEditingController();
    final linkedDimType = TextEditingController();
    final linkedDimId = TextEditingController();
    String trainingType = 'classroom';
    String status = 'planned';
    DateTime? scheduled;
    DateTime? completed;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Nova evidencija obuke (F2)'),
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
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Naslov / tema obuke *',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: trainingType,
                    decoration: const InputDecoration(labelText: 'Tip'),
                    items: const [
                      DropdownMenuItem(
                        value: 'classroom',
                        child: Text('Učionica'),
                      ),
                      DropdownMenuItem(
                        value: 'practical',
                        child: Text('Praktično'),
                      ),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                      DropdownMenuItem(value: 'other', child: Text('Ostalo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => trainingType = v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'planned', child: Text('Planirano')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('U toku'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Završeno'),
                      ),
                      DropdownMenuItem(value: 'failed', child: Text('Nije položeno')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Otkazano')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => status = v);
                    },
                  ),
                  TextFormField(
                    controller: trainer,
                    decoration: const InputDecoration(
                      labelText: 'Trener / organizator',
                    ),
                  ),
                  ListTile(
                    title: Text(
                      scheduled == null
                          ? 'Planirani datum (opcionalno)'
                          : 'Plan: ${_isoDate(scheduled!)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.event),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: scheduled ?? DateTime.now(),
                          firstDate: DateTime(DateTime.now().year - 2),
                          lastDate: DateTime(DateTime.now().year + 2),
                        );
                        if (p != null) {
                          setSt(() => scheduled = p);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                      completed == null
                          ? 'Datum završetka (opcionalno)'
                          : 'Završeno: ${_isoDate(completed!)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.event_available),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: completed ?? DateTime.now(),
                          firstDate: DateTime(DateTime.now().year - 2),
                          lastDate: DateTime(DateTime.now().year + 2),
                        );
                        if (p != null) {
                          setSt(() => completed = p);
                        }
                      },
                    ),
                  ),
                  TextFormField(
                    controller: linkedDimType,
                    decoration: const InputDecoration(
                      labelText: 'Povezana dimenzija — tip (npr. machine)',
                    ),
                  ),
                  TextFormField(
                    controller: linkedDimId,
                    decoration: const InputDecoration(
                      labelText: 'Povezana dimenzija — ID',
                    ),
                  ),
                  TextFormField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Napomena'),
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
    if (title.text.trim().isEmpty) return;

    try {
      await _svc.upsertTrainingRecord(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: employeeDocId,
        title: title.text.trim(),
        trainingType: trainingType,
        status: status,
        trainerName: trainer.text.trim(),
        scheduledAtIso: scheduled != null ? scheduled!.toUtc().toIso8601String() : '',
        completedAtIso: completed != null ? completed!.toUtc().toIso8601String() : '',
        notesShort: notes.text.trim(),
        linkedDimensionType: linkedDimType.text.trim(),
        linkedDimensionId: linkedDimId.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidencija obuke spremljena.')),
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
        .collection('workforce_training_records')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(title: const Text('Evidencija obuka')),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _addRecord,
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
              child: Text('Nema zapisa obuka. Dodaj prvi (+).'),
            );
          }
          final rows = docs.map(WorkforceTrainingRecord.fromDoc).toList();
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    'Radnik: ${r.employeeDocId}',
                    'Status: ${r.status}',
                    if (r.trainerName != null && r.trainerName!.isNotEmpty)
                      'Trener: ${r.trainerName}',
                  ].join(' · '),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
