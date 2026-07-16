import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../models/workforce_compliance_document.dart';
import '../models/workforce_employee.dart';
import '../services/workforce_callable_service.dart';
import '../widgets/workforce_form_dialog.dart';
import '../widgets/workforce_screen_help.dart';
import '../workforce_compliance_labels.dart';
import '../workforce_date_key.dart';

/// F4 — compliance / employee file; **Firestore read samo tenant admin** (vidi rules).
class ComplianceListScreen extends StatefulWidget {
  const ComplianceListScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ComplianceListScreen> createState() => _ComplianceListScreenState();
}

class _ComplianceListScreenState extends State<ComplianceListScreen> {
  final _svc = WorkforceCallableService();
  Map<String, String> _employeeNames = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _canAccess =>
      ProductionAccessHelper.isSuperAdminRole(_role) ||
      ProductionAccessHelper.isAdminRole(_role);

  @override
  void initState() {
    super.initState();
    if (_canAccess) _loadEmployeeNames();
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

  String _employeeLabel(String? docId) {
    if (docId == null || docId.isEmpty) return 'Opće / kompanija';
    final n = _employeeNames[docId];
    if (n != null && n.isNotEmpty) return n;
    return 'Radnik nije pronađen';
  }

  Future<void> _addDocument() async {
    final employeesSnap = await FirebaseFirestore.instance
        .collection('workforce_employees')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('displayName')
        .limit(120)
        .get();

    if (!mounted) return;
    final employees =
        employeesSnap.docs.map(WorkforceEmployee.fromDoc).toList();

    String? empId;
    final title = TextEditingController();
    final version = TextEditingController(text: '1');
    final attach = TextEditingController();
    final notes = TextEditingController();
    String docType = 'policy_ack';
    String status = 'active';
    DateTime effective = DateTime.now();
    DateTime? validUntil;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return WorkforceFormDialog(
            title: 'Novi zapis usklađenosti',
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  DropdownButtonFormField<String?>(
                    initialValue: empId,
                    decoration: const InputDecoration(
                      labelText: 'Radnik (prazno = opće)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Opće / kompanija —'),
                      ),
                      ...employees.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(
                            '${e.displayName} (${e.employeeCode})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setSt(() => empId = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: docType,
                    decoration: const InputDecoration(labelText: 'Tip'),
                    items: const [
                      DropdownMenuItem(value: 'statement', child: Text('Izjava')),
                      DropdownMenuItem(
                        value: 'policy_ack',
                        child: Text('Potvrda procedure / politike'),
                      ),
                      DropdownMenuItem(
                        value: 'disciplinary',
                        child: Text('Disciplinski / zapisnik'),
                      ),
                      DropdownMenuItem(
                        value: 'training_ack',
                        child: Text('Potvrda obuke'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Ostalo')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => docType = v);
                    },
                  ),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Naslov *'),
                  ),
                  TextFormField(
                    controller: version,
                    decoration: const InputDecoration(labelText: 'Verzija *'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktivan')),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Text('Arhiviran'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSt(() => status = v);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Važi od: ${workforceDateKey(effective)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: effective,
                          firstDate: DateTime(effective.year - 10),
                          lastDate: DateTime(effective.year + 10),
                        );
                        if (p != null) setSt(() => effective = p);
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      validUntil == null
                          ? 'Važi do (opcionalno)'
                          : 'Važi do: ${workforceDateKey(validUntil!)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (validUntil != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setSt(() => validUntil = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: ctx,
                              initialDate: validUntil ?? effective,
                              firstDate: effective,
                              lastDate: DateTime(effective.year + 15),
                            );
                            if (p != null) setSt(() => validUntil = p);
                          },
                        ),
                      ],
                    ),
                  ),
                  TextFormField(
                    controller: attach,
                    decoration: const InputDecoration(
                      labelText: 'URL priloga (opcionalno)',
                    ),
                  ),
                  TextFormField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Kratka napomena'),
                    maxLines: 2,
                  ),
                ],
              ),
            );
        },
      ),
    );

    if (ok != true) {
      title.dispose();
      version.dispose();
      attach.dispose();
      notes.dispose();
      return;
    }
    final titleText = title.text.trim();
    final versionText = version.text.trim();
    final attachText = attach.text.trim();
    final notesText = notes.text.trim();
    title.dispose();
    version.dispose();
    attach.dispose();
    notes.dispose();

    if (titleText.isEmpty || versionText.isEmpty) return;

    try {
      await _svc.upsertComplianceDocument(
        companyId: _companyId,
        plantKey: _plantKey,
        employeeDocId: empId ?? '',
        docType: docType,
        title: titleText,
        version: versionText,
        effectiveFrom: workforceDateKey(effective),
        validUntil: validUntil != null ? workforceDateKey(validUntil!) : '',
        status: status,
        attachmentUrl: attachText,
        notesShort: notesText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zapis usklađenosti spremljen.')),
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
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dokumenti usklađenosti')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Pristup dokumentima usklađenosti imaju samo administratori kompanije.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('workforce_compliance_documents')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumenti usklađenosti'),
        actions: [
          const WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.complianceTitle,
            message: WorkforceHelpTexts.complianceMessage,
          ),
          IconButton(
            tooltip: 'Novi zapis',
            icon: const Icon(Icons.add),
            onPressed: _addDocument,
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
            return const Center(
              child: Text('Nema zapisa usklađenosti.'),
            );
          }
          final rows = docs.map(WorkforceComplianceDocument.fromDoc).toList();
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${WorkforceComplianceLabels.docTypeLabel(r.docType)} · v${r.version} · od ${r.effectiveFrom}'
                  '${r.validUntil != null && r.validUntil!.isNotEmpty ? " do ${r.validUntil}" : ""}\n'
                  '${_employeeLabel(r.employeeDocId)} · ${WorkforceComplianceLabels.statusLabel(r.status)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
