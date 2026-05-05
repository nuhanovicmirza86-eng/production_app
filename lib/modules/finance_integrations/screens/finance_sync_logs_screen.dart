import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_sync_logs_service.dart';

class FinanceSyncLogsScreen extends StatelessWidget {
  const FinanceSyncLogsScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context) {
    final svc = FinanceSyncLogsService();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync logovi'),
      ),
      body: StreamBuilder(
        stream: svc.watchLogs(companyId),
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
                  'Nema log linija. Trace zapisi (`finance_sync_logs`) '
                  'ispunjava backend po sync poslu.',
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
              final l = rows[i];
              final t = l.createdAt;
              final timeLabel = t != null ? df.format(t) : '—';
              final hash = l.requestPayloadHash;
              return ListTile(
                isThreeLine: true,
                title: Text(
                  l.message.isNotEmpty ? l.message : l.id,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '$timeLabel · job ${l.syncJobId.isNotEmpty ? l.syncJobId : '—'}'
                  '${hash != null && hash.isNotEmpty ? '\nhash $hash' : ''}'
                  '${l.responseCode != null && l.responseCode!.isNotEmpty ? '\nkod ${l.responseCode}' : ''}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
