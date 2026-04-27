import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dnevnik promjena vezan za ORV: [company_audit_logs] s [entityType] == work_time.
class WorkTimeAuditLogScreen extends StatelessWidget {
  const WorkTimeAuditLogScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dnevnik promjena')),
        body: const Center(child: Text('Nedostaje companyId (sesija).')),
      );
    }
    final loc = Localizations.localeOf(context).toString();
    final q = FirebaseFirestore.instance
        .collection('company_audit_logs')
        .where('companyId', isEqualTo: _companyId)
        .orderBy('createdAt', descending: true)
        .limit(200);
    return Scaffold(
      appBar: AppBar(title: const Text('Dnevnik promjena (ORV / IATF)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs
              .map((d) => d.data())
              .where((m) => (m['entityType'] ?? '').toString() == 'work_time')
              .toList();
          if (docs.isEmpty) {
            return const Center(
              child: Text('Nema ORV stavki u dnevniku. Akcije sa Callables ovdje završavaju audit trag.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final m = docs[i];
              final at = m['createdAt'];
              String when = '—';
              if (at is Timestamp) {
                when = DateFormat.yMMMd(loc).add_Hm().format(at.toDate());
              }
              return ListTile(
                title: Text('${m['action'] ?? ''} · ${m['summary'] ?? m['entityId'] ?? ''}'),
                subtitle: Text(
                  '${m['createdByEmail'] ?? ''} · $when',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
