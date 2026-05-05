import 'package:flutter/material.dart';

import '../screens/finance_connection_edit_screen.dart';
import '../screens/finance_control_dashboard_screen.dart';
import '../screens/finance_csv_export_capabilities_screen.dart';
import '../screens/finance_document_links_screen.dart';
import '../screens/finance_error_resolution_screen.dart';
import '../screens/finance_integration_dashboard_screen.dart';
import '../screens/finance_mapping_rules_screen.dart';
import '../screens/finance_sync_jobs_screen.dart';
import '../screens/finance_sync_logs_screen.dart';
import '../utils/finance_permissions.dart';
import 'finance_connections_inline_list.dart';
import 'finance_screen_context_info.dart';

/// Sadržaj taba **ERP**: ugrađene veze + prečaci na povezane preglede.
class FinanceErpHubTabBody extends StatelessWidget {
  const FinanceErpHubTabBody({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
    this.shrinkWrapped = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  /// Kad je `true`, vraća samo [Column] (npr. unutar roditeljskog [ListView]).
  final bool shrinkWrapped;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  String get _role => (companyData['role'] ?? '').toString().trim();

  bool get _canManage => FinancePermissions.canManageConnections(
        companyData: companyData,
        role: _role,
        debugUnlockModule: debugUnlockModule,
      );

  void _push(BuildContext context, Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _addConnection(BuildContext context) async {
    if (!_canManage) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => FinanceConnectionEditScreen(
          companyData: companyData,
          debugUnlockModule: debugUnlockModule,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrapped ? MainAxisSize.min : MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Povezivanje s računovodstvenim sustavom',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FinanceScreenContextInfo(
              title: 'Smjer: cjelokupni troškovni lanac',
              body:
                  'Cilj je jedinstvena financijska slika: troškovi i rashodi kroz cijeli '
                  'proces — od ulaza sirovine, kroz sve faze proizvodnje i logistiku, '
                  'do isporuke kupcu. To uključuje razinu procesa, proizvoda, zastoja '
                  'i kvalitete, uz usklađenost s ERP-om. Kontroling u aplikaciji i '
                  'integracija nadopunjavaju se u fazama: prvo operativni KPI i agregati, '
                  'zatim proširenje u dublje procesne i logističke troškove prema vašem '
                  'ERP-u i pravilima mapiranja.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Aktivne veze',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_canManage)
              FilledButton.tonalIcon(
                onPressed: () => _addConnection(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Nova veza'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        FinanceConnectionsInlineList(
          companyData: companyData,
          debugUnlockModule: debugUnlockModule,
        ),
        const SizedBox(height: 20),
        Text(
          'Operativni alati',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.dashboard_customize_outlined),
          title: const Text('Pregled integracije'),
          subtitle: const Text('Konektori i sažetak stanja'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceIntegrationDashboardScreen(
              companyData: companyData,
              debugUnlockModule: debugUnlockModule,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.hub_outlined),
          title: const Text('Veze dokumenata'),
          subtitle: const Text('Operonix entiteti ↔ ERP'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceDocumentLinksScreen(
              companyData: companyData,
              debugUnlockModule: debugUnlockModule,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('Kontrolni snimci'),
          subtitle: const Text('Reconciliacija / kontroling'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceControlDashboardScreen(
              companyData: companyData,
              debugUnlockModule: debugUnlockModule,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.build_circle_outlined),
          title: const Text('Rješavanje grešaka sinkronizacije'),
          subtitle: const Text('Ponovi ili otkaži poslove'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceErrorResolutionScreen(
              companyData: companyData,
              debugUnlockModule: debugUnlockModule,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.sync_alt_outlined),
          title: const Text('Sync poslovi'),
          subtitle: const Text('Status poslova sinkronizacije'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceSyncJobsScreen(companyId: _companyId),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Sync logovi'),
          subtitle: const Text('Zapisi po poslu sinkronizacije'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceSyncLogsScreen(companyId: _companyId),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Mapiranja'),
          subtitle: const Text('Polja i pravila izvora u ERP'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceMappingRulesScreen(companyId: _companyId),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: const Text('CSV / Excel'),
          subtitle: const Text('Veze s uključenim izvozom'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            FinanceCsvExportCapabilitiesScreen(
              companyData: companyData,
              debugUnlockModule: debugUnlockModule,
            ),
          ),
        ),
      ],
    );
    if (shrinkWrapped) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: column,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: column,
    );
  }
}
