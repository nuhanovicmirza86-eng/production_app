import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../production/ai/screens/production_tracking_assistant_screen.dart';
import '../models/workforce_employee.dart';
import '../models/workforce_evaluation_record.dart';
import '../models/workforce_performance_feedback.dart';
import '../services/workforce_callable_service.dart';

/// F3: strukturirani feedback + evidencija ocjena (KPI).
class FeedbackListScreen extends StatefulWidget {
  const FeedbackListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen>
    with SingleTickerProviderStateMixin {
  final _svc = WorkforceCallableService();
  Map<String, String> _employeeNames = {};
  late TabController _tab;

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
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _loadEmployeeNames();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
    if (n != null && n.isNotEmpty) return n;
    return docId;
  }

  String _defaultPeriodKey() {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final mo = n.month.toString().padLeft(2, '0');
    return '$y-$mo';
  }

  Future<void> _openWorkforceAssistant(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionTrackingAssistantScreen(
          companyData: widget.companyData,
          initialPrompt:
              'Analiziraj efikasnost i efektivnost radnika u ovom pogonu koristeći '
              'kontekst sustava: formalne ocjene iz evidencije (kućni red, sigurnost, '
              'uspjeh rada, efikasnost), te operativno praćenje (output i škart). '
              'Daj sažetak za vodstvo i 2–3 konkretne smjernice.',
        ),
      ),
    );
  }

  Future<void> _addFeedback() async {
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
    final body = TextEditingController();
    final period = TextEditingController();
    final trackId = TextEditingController();
    final eventId = TextEditingController();
    String category = 'coaching';
    int? score;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Novi feedback (F3)'),
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
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Kategorija'),
                    items: const [
                      DropdownMenuItem(
                        value: 'coaching',
                        child: Text('Coaching'),
                      ),
                      DropdownMenuItem(
                        value: 'recognition',
                        child: Text('Priznanje'),
                      ),
                      DropdownMenuItem(
                        value: 'improvement_needed',
                        child: Text('Potrebno poboljšanje'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => category = v);
                    },
                  ),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Naslov *',
                    ),
                  ),
                  TextFormField(
                    controller: body,
                    decoration: const InputDecoration(labelText: 'Tekst'),
                    maxLines: 4,
                  ),
                  DropdownButtonFormField<int?>(
                    initialValue: score,
                    decoration: const InputDecoration(
                      labelText: 'Opc. ocjena 1–5',
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('—')),
                      DropdownMenuItem(value: 1, child: Text('1')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 4, child: Text('4')),
                      DropdownMenuItem(value: 5, child: Text('5')),
                    ],
                    onChanged: (v) => setSt(() => score = v),
                  ),
                  TextFormField(
                    controller: period,
                    decoration: const InputDecoration(
                      labelText: 'KPI period (YYYY-MM, opcionalno)',
                    ),
                  ),
                  TextFormField(
                    controller: trackId,
                    decoration: const InputDecoration(
                      labelText: 'ID unosa praćenja (opcionalno)',
                    ),
                  ),
                  TextFormField(
                    controller: eventId,
                    decoration: const InputDecoration(
                      labelText: 'ID machine_state_events (opcionalno)',
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
    if (title.text.trim().isEmpty) return;

    try {
      await _svc.upsertPerformanceFeedback(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: employeeDocId,
        category: category,
        noteTitle: title.text.trim(),
        noteBody: body.text.trim(),
        kpiPeriodKey: period.text.trim(),
        structuredScore: score,
        relatedTrackingEntryId: trackId.text.trim(),
        relatedMachineStateEventId: eventId.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback spremljen.')),
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

  Future<void> _addEvaluation() async {
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
    final period = TextEditingController(text: _defaultPeriodKey());
    final notes = TextEditingController();
    var house = 2;
    var safety = 2;
    var effectiveness = 3;
    var efficiency = 3;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Evidencija ocjena'),
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
                    controller: period,
                    decoration: const InputDecoration(
                      labelText: 'Period (YYYY-MM) *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Osnovne odgovornosti (1–3)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int>(house),
                    initialValue: house,
                    decoration: const InputDecoration(
                      labelText: 'Poštivanje kućnog reda',
                    ),
                    items: [1, 2, 3]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSt(() => house = v);
                    },
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int>(safety),
                    initialValue: safety,
                    decoration: const InputDecoration(
                      labelText: 'Poštivanje sigurnosnih propisa',
                    ),
                    items: [1, 2, 3]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSt(() => safety = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kvalitet rada (1–5)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int>(effectiveness),
                    initialValue: effectiveness,
                    decoration: const InputDecoration(
                      labelText: 'Rad izvršen uspješno (efektivnost)',
                    ),
                    items: [1, 2, 3, 4, 5]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSt(() => effectiveness = v);
                    },
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int>(efficiency),
                    initialValue: efficiency,
                    decoration: const InputDecoration(
                      labelText: 'Rad izvršen efikasno',
                    ),
                    items: [1, 2, 3, 4, 5]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSt(() => efficiency = v);
                    },
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
    final pk = period.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(pk)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Period mora biti YYYY-MM.')),
        );
      }
      return;
    }

    try {
      await _svc.upsertEvaluationRecord(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: employeeDocId,
        periodKeyYyyyMm: pk,
        houseRulesScore: house,
        safetyComplianceScore: safety,
        workEffectivenessScore: effectiveness,
        workEfficiencyScore: efficiency,
        notesShort: notes.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidencija spremljena.')),
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

  Widget _buildFeedbackList() {
    final q = FirebaseFirestore.instance
        .collection('workforce_performance_feedback')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('createdAt', descending: true)
        .limit(200);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            child: Text('Nema zapisa feedbacka. Dodaj prvi (+).'),
          );
        }
        final rows = docs.map(WorkforcePerformanceFeedback.fromDoc).toList();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            return ListTile(
              title: Text(
                r.noteTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${r.category}'
                '${r.structuredScore != null ? " · ocjena ${r.structuredScore}" : ""}\n'
                '${_employeeLabel(r.employeeDocId)}',
              ),
            );
          },
        );
      },
    );
  }

  Widget _kpiChip(String label, String value) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvaluationList() {
    final q = FirebaseFirestore.instance
        .collection('workforce_evaluation_records')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('createdAt', descending: true)
        .limit(120);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            child: Text(
              'Nema evidencije ocjena. Dodaj prvu (+).\n'
              'Osnove 25% (1–3), kvalitet rada 75% (1–5).',
              textAlign: TextAlign.center,
            ),
          );
        }
        final rows = docs.map(WorkforceEvaluationRecord.fromDoc).toList();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _employeeLabel(r.employeeDocId),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text('${r.periodKey} · ${r.totalScorePct}%'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kriteriji',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        _kpiChip('Kućni red', '${r.houseRulesScore}/3'),
                        _kpiChip('Sigurnost', '${r.safetyComplianceScore}/3'),
                      ],
                    ),
                    Row(
                      children: [
                        _kpiChip('Uspjeh (efekt.)', '${r.workEffectivenessScore}/5'),
                        _kpiChip('Efikasnost', '${r.workEfficiencyScore}/5'),
                      ],
                    ),
                    if (r.notesShort.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.notesShort,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performanse i feedback'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Feedback'),
            Tab(text: 'Evidencija ocjena'),
          ],
        ),
        actions: [
          if (_tab.index == 1)
            IconButton(
              icon: const Icon(Icons.psychology_outlined),
              tooltip: 'OperonixAI — efikasnost i efektivnost',
              onPressed: () => _openWorkforceAssistant(context),
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _tab.index == 0 ? _addFeedback : _addEvaluation,
              child: Icon(
                _tab.index == 0
                    ? Icons.add_comment_outlined
                    : Icons.fact_check_outlined,
              ),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          _buildFeedbackList(),
          _buildEvaluationList(),
        ],
      ),
    );
  }
}
