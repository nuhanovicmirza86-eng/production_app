import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/finance_sync_job_model.dart';
import '../services/finance_integration_callable_service.dart';
import '../services/finance_sync_jobs_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../widgets/finance_screen_context_info.dart';

/// Rješavanje grešaka sinkronizacije (retry / otkazivanje).
class FinanceErrorResolutionScreen extends StatelessWidget {
  const FinanceErrorResolutionScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  String get _role => (companyData['role'] ?? '').toString().trim();

  bool get _canAct => FinancePermissions.canManageConnections(
        companyData: companyData,
        role: _role,
        debugUnlockModule: debugUnlockModule,
      );

  @override
  Widget build(BuildContext context) {
    final svc = FinanceSyncJobsService();
    final call = FinanceIntegrationCallableService();

    if (!FinancePermissions.canViewErpIntegrationLayer(
      companyData: companyData,
      debugUnlockModule: debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Greške sinkronizacije')),
        body: const Center(child: Text('Nemate pristup.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Greške sinkronizacije'),
        actions: [
          FinanceScreenContextInfo(
            title: 'Kako riješiti',
            body:
                'Ponovno pokretanje vraća posao u red čekanja (backend ga ponovno obrađuje). '
                'Otkazivanje zaustavlja daljnje pokušaje za taj zapis. Potrebne su ovlasti '
                'administratora ili šefa računovodstva.',
          ),
        ],
      ),
      body: StreamBuilder<List<FinanceSyncJobModel>>(
        stream: svc.watchProblemJobs(_companyId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(financeUserFacingLoadError(snap.error)));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nema poslova koji traže pažnju za ovu kompaniju.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final j = rows[i];
              return ListTile(
                isThreeLine: true,
                title: Text('${j.syncType} · ${j.status}'),
                subtitle: Text(
                  '${j.provider} · ${j.connectionId.isNotEmpty ? j.connectionId : 'bez veze'}\n${j.lastErrorMessage ?? '—'}',
                  maxLines: 4,
                ),
                trailing: _canAct
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ponovi',
                            icon: const Icon(Icons.replay_outlined),
                            onPressed: () async {
                              try {
                                await call.retryFinanceSyncJob(
                                  companyId: _companyId,
                                  jobId: j.id,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Posao vraćen u red čekanja.'),
                                    ),
                                  );
                                }
                              } on FirebaseFunctionsException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.message ?? 'Nije uspjelo.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Otkaži',
                            icon: const Icon(Icons.cancel_outlined),
                            onPressed: () async {
                              try {
                                await call.cancelFinanceSyncJob(
                                  companyId: _companyId,
                                  jobId: j.id,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Posao otkazan.'),
                                    ),
                                  );
                                }
                              } on FirebaseFunctionsException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.message ?? 'Nije uspjelo.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
