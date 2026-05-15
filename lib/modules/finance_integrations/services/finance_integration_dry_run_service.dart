import 'package:cloud_functions/cloud_functions.dart';

/// Rezultat Callable [runFinanceIntegrationSyncDryRun] (skeleton bez ERP ingest-a).
class FinanceIntegrationDryRunResult {
  const FinanceIntegrationDryRunResult({
    required this.success,
    required this.syncRunId,
    required this.status,
    required this.recordsProcessed,
    required this.recordsFailed,
  });

  final bool success;
  final String syncRunId;
  final String status;
  final int recordsProcessed;
  final int recordsFailed;
}

/// Poziv dry-run synca: connection → syncRun → audit → ažuriranje veze (backend).
class FinanceIntegrationDryRunService {
  FinanceIntegrationDryRunService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<FinanceIntegrationDryRunResult> runFinanceIntegrationSyncDryRun({
    required String companyId,
    required String connectionId,
  }) async {
    final res = await _functions
        .httpsCallable('runFinanceIntegrationSyncDryRun')
        .call(<String, dynamic>{
      'companyId': companyId.trim(),
      'connectionId': connectionId.trim(),
    });
    final raw = res.data;
    if (raw is! Map) {
      throw StateError('Neočekivani odgovor dry-run synca.');
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['success'] != true) {
      throw StateError('Dry-run sync nije uspio.');
    }
    final sid = (data['syncRunId'] ?? '').toString().trim();
    if (sid.isEmpty) {
      throw StateError('Nedostaje syncRunId u odgovoru.');
    }
    final st = (data['status'] ?? '').toString().trim();
    final rp = data['recordsProcessed'];
    final rf = data['recordsFailed'];
    final processed = rp is num ? rp.toInt() : int.tryParse('$rp') ?? 0;
    final failed = rf is num ? rf.toInt() : int.tryParse('$rf') ?? 0;
    return FinanceIntegrationDryRunResult(
      success: true,
      syncRunId: sid,
      status: st.isEmpty ? 'completed' : st,
      recordsProcessed: processed,
      recordsFailed: failed,
    );
  }
}
