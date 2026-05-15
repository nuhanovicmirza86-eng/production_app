import 'package:flutter/material.dart';

import '../services/finance_connection_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../utils/finance_provider_constants.dart';
import '../utils/finance_sync_constants.dart';
import '../widgets/finance_screen_context_info.dart';

/// Pregled veza s uključenim tipom [FinanceEnabledSyncTypes.csvExport].
class FinanceCsvExportCapabilitiesScreen extends StatelessWidget {
  const FinanceCsvExportCapabilitiesScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (companyData['role'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final svc = FinanceConnectionService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV / Excel izvoz'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Veze u kojima je omogućen izvoz u tablični oblik.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              FinanceScreenContextInfo(
                title: 'CSV / Excel izvoz',
                body:
                    'Oznaka na vezi znači da je izvoz u tablicu podržan. Datoteke se '
                    'stvare na poslužitelju kad je veza aktivna i odobrena.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: svc.watchConnections(_companyId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        financeUserFacingLoadError(snap.error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    FinanceTechnicalInfoIcon(detail: '${snap.error}'),
                  ],
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data!;
              final withCsv = rows.where((c) {
                return c.enabledModules.any(
                  (t) =>
                      t.toLowerCase() ==
                      FinanceEnabledSyncTypes.csvExport.toLowerCase(),
                );
              }).toList();
              if (withCsv.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      rows.isEmpty
                          ? 'Nema definiranih ERP veza. Dodajte vezu na kartici ERP veze.'
                          : 'Nijedna veza trenutno nema uključenu opciju „${FinanceEnabledSyncTypes.displayLabel(FinanceEnabledSyncTypes.csvExport)}”. '
                                'Uredi vezu i uključi izvoz kad bude dostupan za vaš ERP.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: withCsv
                    .map(
                      (c) => Card(
                        child: ListTile(
                          title: Text(
                            c.connectionName.isNotEmpty
                                ? c.connectionName
                                : FinanceProviderConstants.displayLabel(
                                    c.provider,
                                  ),
                          ),
                          subtitle: Text(
                            '${FinanceProviderConstants.displayLabel(c.provider)} · ${c.status}',
                          ),
                          leading: const Icon(Icons.table_chart_outlined),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (FinancePermissions.canManageConnections(
            companyData: companyData,
            role: _role,
            debugUnlockModule: debugUnlockModule,
          )) ...[
            const SizedBox(height: 24),
            Text(
              'Upravljanje tipovima synca radi se prilikom uređivanja veze.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
