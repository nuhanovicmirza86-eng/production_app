import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/workforce_qualification.dart';

/// F2: pregled kvalifikacija s rokom važenja — istekle ili u narednih 30 dana.
class QualificationExpiryScreen extends StatelessWidget {
  const QualificationExpiryScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (companyData['plantKey'] ?? '').toString().trim();

  static const _horizonDays = 30;

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
                  'Nema kvalifikacija s rokom u narednih $_horizonDays dana '
                  'niti isteklih (s validUntil u matrici).',
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
                title: Text('${r.dimensionType}:${r.dimensionId}'),
                subtitle: Text(
                  'Radnik ${r.employeeDocId} · '
                  '${expired ? "ISTEKLO" : "Ističe"} ${_fmt(v)} · '
                  'odobrenje: ${r.effectiveApproval}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
