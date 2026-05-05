import 'package:flutter/material.dart';

import '../services/finance_connection_service.dart';
import '../services/finance_control_snapshots_service.dart';
import '../services/finance_integration_callable_service.dart';
import '../services/finance_sync_jobs_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import 'finance_control_dashboard_screen.dart';
import 'finance_document_links_screen.dart';
import 'finance_error_resolution_screen.dart';

/// Pregled integracijskog sloja: veze, adapteri, prečaci na podmodule.
class FinanceIntegrationDashboardScreen extends StatefulWidget {
  const FinanceIntegrationDashboardScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  @override
  State<FinanceIntegrationDashboardScreen> createState() =>
      _FinanceIntegrationDashboardScreenState();
}

class _FinanceIntegrationDashboardScreenState
    extends State<FinanceIntegrationDashboardScreen> {
  final _connections = FinanceConnectionService();
  final _jobs = FinanceSyncJobsService();
  final _control = FinanceControlSnapshotsService();
  final _call = FinanceIntegrationCallableService();
  Map<String, dynamic>? _manifest;
  Object? _manifestErr;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    try {
      final m = await _call.getAdapterManifest();
      if (mounted) {
        setState(() {
          _manifest = m;
          _manifestErr = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _manifestErr = e;
          _manifest = null;
        });
      }
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!FinancePermissions.canViewErpIntegrationLayer(
      companyData: widget.companyData,
      debugUnlockModule: widget.debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Integracija ERP')),
        body: const Center(child: Text('Nemate pristup ovom modulu.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integracija ERP — pregled'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadManifest,
            tooltip: 'Osvježi registar konektora',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Sažetak stanja',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: _connections.watchConnections(_companyId),
            builder: (context, snap) {
              final n = snap.hasData ? snap.data!.length : null;
              return ListTile(
                leading: const Icon(Icons.link_outlined),
                title: Text(n == null ? 'ERP veze…' : 'ERP veze: $n'),
                subtitle: const Text('Aktivne konfiguracije sinkronizacije'),
              );
            },
          ),
          StreamBuilder(
            stream: _jobs.watchProblemJobs(_companyId),
            builder: (context, snap) {
              if (snap.hasError) {
                return ListTile(
                  leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                  title: Text(financeUserFacingLoadError(snap.error)),
                );
              }
              final n = snap.data?.length ?? 0;
              return ListTile(
                leading: Icon(
                  n > 0 ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                  color: n > 0 ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                title: Text('Poslovi koji traže pažnju: $n'),
                subtitle: const Text('Neuspjeli ili ručni pregled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(
                  context,
                  FinanceErrorResolutionScreen(
                    companyData: widget.companyData,
                    debugUnlockModule: widget.debugUnlockModule,
                  ),
                ),
              );
            },
          ),
          StreamBuilder(
            stream: _control.watchSnapshots(_companyId),
            builder: (context, snap) {
              final n = snap.hasData ? snap.data!.length : null;
              return ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(
                  n == null ? 'Kontrolni snimci…' : 'Kontrolni snimci: $n',
                ),
                subtitle: const Text('Usklađenost operativnog i ERP sloja'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(
                  context,
                  FinanceControlDashboardScreen(
                    companyData: widget.companyData,
                    debugUnlockModule: widget.debugUnlockModule,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 32),
          Text(
            'Registar konektora (backend)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_manifestErr != null)
            Text(
              financeUserFacingLoadError(_manifestErr),
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (_manifest == null)
            const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else
            ..._buildAdapterChips(_manifest!),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => _push(
              context,
              FinanceDocumentLinksScreen(
                companyData: widget.companyData,
                debugUnlockModule: widget.debugUnlockModule,
              ),
            ),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Veze dokumenata Operonix ↔ ERP'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdapterChips(Map<String, dynamic> manifest) {
    final adapters = manifest['adapters'];
    if (adapters is! List) {
      return [
        const Text('Nema liste adaptera u odgovoru.'),
      ];
    }
    return adapters.map((raw) {
      if (raw is! Map) return const SizedBox.shrink();
      final id = (raw['id'] ?? '').toString();
      final name = (raw['displayName'] ?? id).toString();
      final tier = (raw['integrationTier'] ?? '').toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          title: Text(name),
          subtitle: Text('$id · $tier'),
        ),
      );
    }).toList();
  }
}
