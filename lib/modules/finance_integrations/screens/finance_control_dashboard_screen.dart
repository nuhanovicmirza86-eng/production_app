import 'package:flutter/material.dart';

import '../models/finance_control_snapshot_model.dart';
import '../services/finance_control_snapshots_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../widgets/finance_screen_context_info.dart';

/// Kontrolni snimci (reconciliacija operativa vs ERP plan).
class FinanceControlDashboardScreen extends StatelessWidget {
  const FinanceControlDashboardScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final svc = FinanceControlSnapshotsService();

    if (!FinancePermissions.canViewErpIntegrationLayer(
      companyData: companyData,
      debugUnlockModule: debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kontrolni pregled')),
        body: const Center(child: Text('Nemate pristup.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrolni snimci'),
        actions: [
          FinanceScreenContextInfo(
            title: 'Što je ovdje',
            body:
                'Za svaki obračunski period sustav drži kontrolni snimak uz KPI. '
                'Kad ERP adapter usporedi knjiženja, status reconciliacije postaje '
                'dostupan u proširenom toku.',
          ),
        ],
      ),
      body: StreamBuilder<List<FinanceControlSnapshotModel>>(
        stream: svc.watchSnapshots(_companyId),
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
                  'Još nema kontrolnih snimaka. Pokrenite preračun KPI-a na pregledu controllinga.',
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
              final r = rows[i];
              final pk = r.plantKey.isEmpty ? 'zbroj / svi' : r.plantKey;
              return ListTile(
                isThreeLine: true,
                title: Text(
                  '${r.periodYear}-${r.periodMonth.toString().padLeft(2, '0')} · $pk',
                ),
                subtitle: Text(
                  '${r.businessYearId}\n'
                  '${r.reconciliationState} · ${r.controlSnapshotKind}',
                ),
                trailing: Text(
                  r.operationalGrossMargin != null
                      ? r.operationalGrossMargin!.toStringAsFixed(2)
                      : '—',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
