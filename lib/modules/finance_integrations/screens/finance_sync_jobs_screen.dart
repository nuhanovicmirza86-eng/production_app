import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_sync_jobs_service.dart';

class FinanceSyncJobsScreen extends StatelessWidget {
  const FinanceSyncJobsScreen({
    super.key,
    required this.companyId,
  });

  final String companyId;

  @override
  Widget build(BuildContext context) {
    final svc = FinanceSyncJobsService();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync poslovi'),
      ),
      body: StreamBuilder(
        stream: svc.watchJobs(companyId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nema pozadinskih poslova sinkronizacije za vašu kompaniju. '
                  'Pojavit će se kada sustav pokrene sljedeću sinkronizaciju.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final j = rows[i];
              final t = j.updatedAt ?? j.createdAt;
              final timeLabel = t != null ? df.format(t) : '—';
              return ListTile(
                isThreeLine: true,
                title: Text(
                  j.syncType.isNotEmpty ? j.syncType : j.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${j.status.isNotEmpty ? j.status : '?'} · ${j.provider.isNotEmpty ? j.provider : 'bez providera'} · $timeLabel'
                  '${j.lastErrorMessage != null && j.lastErrorMessage!.isNotEmpty ? '\n${j.lastErrorMessage}' : ''}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
