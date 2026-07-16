import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workforce_employee.dart';
import '../models/workforce_qualification.dart';
import '../widgets/workforce_screen_help.dart';
import '../workforce_qualification_labels.dart';

/// Pregled kvalifikacija s rokom važenja — istekle ili u narednih 30 dana.
class QualificationExpiryScreen extends StatefulWidget {
  const QualificationExpiryScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<QualificationExpiryScreen> createState() =>
      _QualificationExpiryScreenState();
}

class _QualificationExpiryScreenState extends State<QualificationExpiryScreen> {
  Map<String, String> _employeeNames = const {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  static const _horizonDays = 30;

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
        .limit(300)
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

  String _fmt(DateTime d) => DateFormat('d. M. yyyy.', 'bs').format(d);

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('workforce_qualifications')
        .where('companyId', isEqualTo: _companyId)
        .where('plantKey', isEqualTo: _plantKey)
        .limit(400);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Istek i revalidacija'),
        actions: const [
          WorkforceScreenHelpIcon(
            title: WorkforceHelpTexts.qualificationExpiryTitle,
            message: WorkforceHelpTexts.qualificationExpiryMessage,
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
          final now = DateTime.now();
          final horizon = now.add(const Duration(days: _horizonDays));
          final rows = snap.data!.docs
              .map(WorkforceQualification.fromDoc)
              .where((r) {
                final v = r.validUntil;
                if (v == null) return false;
                if (v.isBefore(now)) return true;
                return !v.isAfter(horizon);
              })
              .toList();
          rows.sort((a, b) {
            final va = a.validUntil;
            final vb = b.validUntil;
            if (va == null) return 1;
            if (vb == null) return -1;
            return va.compareTo(vb);
          });
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nema kvalifikacija s rokom u narednih 30 dana niti isteklih.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              final v = r.validUntil!;
              final expired = v.isBefore(now);
              return ListTile(
                leading: Icon(
                  expired ? Icons.warning_amber_rounded : Icons.schedule,
                  color: expired
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  '${WorkforceQualificationLabels.dimensionTypeLabel(r.dimensionType)}: ${r.dimensionId}',
                ),
                subtitle: Text(
                  '${_employeeLabel(r.employeeDocId)} · '
                  '${expired ? 'Isteklo' : 'Ističe'} ${_fmt(v)} · '
                  '${WorkforceQualificationLabels.approvalLabel(r.effectiveApproval)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
