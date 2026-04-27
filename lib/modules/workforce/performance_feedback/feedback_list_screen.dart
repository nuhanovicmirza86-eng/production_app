import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../production/ai/screens/production_tracking_assistant_screen.dart';
import '../employee_profiles/employee_edit_screen.dart';
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
    return 'Radnik (nepoznato ime)';
  }

  String _feedbackCategoryLabel(String category) {
    switch (category) {
      case 'coaching':
        return 'Coaching';
      case 'recognition':
        return 'Priznanje';
      case 'improvement_needed':
        return 'Potrebno poboljšanje';
      default:
        return 'Ostalo';
    }
  }

  String? _formatPeriodKeyYyyyMmForUi(
    BuildContext context,
    String periodKeyYyyyMm,
  ) {
    final raw = periodKeyYyyyMm.trim();
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(raw)) return null;
    final parts = raw.split('-');
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (y < 1970 || m < 1 || m > 12) return null;
    return _formatMonthYearForUi(context, DateTime(y, m, 1));
  }

  String _formatMonthYearForUi(BuildContext context, DateTime monthFirst) {
    final loc = Localizations.localeOf(context).toString();
    return DateFormat.yMMMM(loc).format(monthFirst);
  }

  String _toPeriodKeyYyyyMm(DateTime monthFirst) {
    return '${monthFirst.year}-${monthFirst.month.toString().padLeft(2, '0')}';
  }

  WorkforceEmployee? _employeeOrNull(
    List<WorkforceEmployee> list,
    String? docId,
  ) {
    if (docId == null) return null;
    for (final e in list) {
      if (e.id == docId) return e;
    }
    return null;
  }

  /// Bez povezanog mrežnog naloga, MES unosi se ne mogu atributirati imenu (niti OperonixAI u punom opsegu).
  Widget _noLinkedUserAccountBanner(
    BuildContext context,
    WorkforceEmployee? employee, {
    VoidCallback? onOpenProfile,
  }) {
    final u = employee?.linkedUserUid?.trim();
    if (u != null && u.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Korisnički nalog nije povezan s ovim radničkim profilom. '
                      'Pouzdano povezivanje MES unosa i zastoja s ovom osobom (uključujući OperonixAI) '
                      'moguće je nakon povezivanja u operativnom profilu radnika.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
              if (onOpenProfile != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onOpenProfile,
                    child: const Text('Otvori profil'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Zatvara trenutni [dialogContext] (formu) i otvara [EmployeeEditScreen] za odabranog radnika.
  VoidCallback? _openLinkedProfileFromDialog(
    BuildContext dialogContext,
    List<WorkforceEmployee> employees,
    String? empId,
  ) {
    if (!_canManage) return null;
    return () {
      final emp = _employeeOrNull(employees, empId);
      if (emp == null) return;
      Navigator.of(dialogContext).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => EmployeeEditScreen(
                companyData: widget.companyData,
                existing: emp,
              ),
            ),
          ),
        );
      });
    };
  }

  /// Odabir kalendarskog mjeseca; bilo koji dan u mjesecu se normalizira na 1. u mjesecu.
  Future<DateTime?> _pickMonthInDialog(
    BuildContext context,
    DateTime initialMonthFirst,
  ) async {
    final now = DateTime.now();
    if (initialMonthFirst.isAfter(DateTime(now.year + 5, 12, 31))) {
      initialMonthFirst = DateTime(now.year, now.month, 1);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialMonthFirst,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, 1);
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

  void _openOperonixAiForEvaluation({
    required String employeeDocId,
    required String employeeDisplayName,
    required String periodYyyyMm,
  }) {
    final monthLabel = periodYyyyMm;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProductionTrackingAssistantScreen(
            companyData: widget.companyData,
            evaluationEmployeeDocId: employeeDocId,
            evaluationPeriodYyyyMm: periodYyyyMm,
            autoSendInitialPrompt: true,
            startFreshThread: true,
            initialPrompt:
                'Za radnika $employeeDisplayName i mjesec $monthLabel, na osnovu '
                'sustavskog konteksta (ORV, prijave, kašnjenja gdje su u agregatima, '
                'operativno praćenje i škart, zastoji na linijama, povratne informacije, '
                'dokumenti usklađenosti) predloži **objektivne** brojeve: '
                'kućni red 1–3, sigurnosna pravila 1–3, uspjeh odnosno kvalitet rada 1–5, '
                'te efikasnost 1–5. Ako povezivanje mrežnog naloga s profilom radnika '
                'nedostaje, jasno navedi ograničenje. Na kraju u jednoj reci daj i prijedlog '
                'spreman za upis (samo cijele brojeve, odvojene zarezom u istom redoslijedu).',
          ),
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
    DateTime? kpiOptionalMonth;
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
                              e.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => empId = v),
                  ),
                  _noLinkedUserAccountBanner(
                    ctx,
                    _employeeOrNull(employees, empId),
                    onOpenProfile: _openLinkedProfileFromDialog(ctx, employees, empId),
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
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('KPI period (mjesec, opcionalno)'),
                    subtitle: Text(
                      kpiOptionalMonth == null
                          ? 'Nije odabran mjesec'
                          : _formatMonthYearForUi(ctx, kpiOptionalMonth!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (kpiOptionalMonth != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Ukloni period',
                            onPressed: () {
                              setSt(() => kpiOptionalMonth = null);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_month_outlined),
                          tooltip: 'Odaberi mjesec u kalendaru',
                          onPressed: () async {
                            final now = DateTime.now();
                            final init = kpiOptionalMonth ??
                                DateTime(now.year, now.month, 1);
                            final m = await _pickMonthInDialog(ctx, init);
                            if (m != null) setSt(() => kpiOptionalMonth = m);
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final init = kpiOptionalMonth ??
                          DateTime(now.year, now.month, 1);
                      final m = await _pickMonthInDialog(ctx, init);
                      if (m != null) setSt(() => kpiOptionalMonth = m);
                    },
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
        kpiPeriodKey: kpiOptionalMonth == null
            ? ''
            : _toPeriodKeyYyyyMm(kpiOptionalMonth!),
        structuredScore: score,
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
    var evalPeriodStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    final notes = TextEditingController();
    var house = 2;
    var safety = 2;
    var effectiveness = 3;
    var efficiency = 3;

    final dialogResult = await showDialog<String>(
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
                              e.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => empId = v),
                  ),
                  _noLinkedUserAccountBanner(
                    ctx,
                    _employeeOrNull(employees, empId),
                    onOpenProfile: _openLinkedProfileFromDialog(ctx, employees, empId),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Period (mjesec) *'),
                    subtitle: Text(
                      _formatMonthYearForUi(ctx, evalPeriodStart),
                    ),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final m = await _pickMonthInDialog(ctx, evalPeriodStart);
                      if (m != null) setSt(() => evalPeriodStart = m);
                    },
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Odustani'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx, 'ai'),
                icon: const Icon(Icons.psychology_outlined),
                label: const Text('OperonixAI'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('Spremi'),
              ),
            ],
          );
        },
      ),
    );

    if (dialogResult == 'ai') {
      if (!mounted) return;
      final eid0 = empId;
      if (eid0 == null) return;
      var displayName = 'Radnik';
      for (final e in employees) {
        if (e.id == eid0) {
          displayName = e.displayName;
          break;
        }
      }
      _openOperonixAiForEvaluation(
        employeeDocId: eid0,
        employeeDisplayName: displayName.trim(),
        periodYyyyMm: _toPeriodKeyYyyyMm(evalPeriodStart),
      );
      return;
    }
    if (dialogResult != 'save') {
      return;
    }
    final employeeDocId = empId;
    if (employeeDocId == null) return;
    final pk = _toPeriodKeyYyyyMm(evalPeriodStart);

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
                '${_feedbackCategoryLabel(r.category)}'
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
                          label: Text(
                            '${_formatPeriodKeyYyyyMmForUi(context, r.periodKey) ?? r.periodKey} · ${r.totalScorePct}%',
                          ),
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
