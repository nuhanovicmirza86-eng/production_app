import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_connection_model.dart';
import '../screens/finance_connection_edit_screen.dart';
import '../services/finance_connection_service.dart';
import '../services/finance_integration_callable_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../utils/finance_provider_constants.dart';

/// Lista ERP veza za ugradnju u zavičaj (npr. tab bez vlastitog [Scaffold]).
class FinanceConnectionsInlineList extends StatelessWidget {
  const FinanceConnectionsInlineList({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  String get _companyId =>
      (companyData['companyId'] ?? '').toString().trim();

  String get _role => (companyData['role'] ?? '').toString().trim();

  bool get _canManage => FinancePermissions.canManageConnections(
        companyData: companyData,
        role: _role,
        debugUnlockModule: debugUnlockModule,
      );

  Future<void> _openEditor(
    BuildContext context, {
    FinanceConnectionModel? existing,
  }) async {
    if (!_canManage) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => FinanceConnectionEditScreen(
          companyData: companyData,
          debugUnlockModule: debugUnlockModule,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _testConnection(
    BuildContext context,
    FinanceConnectionModel c,
  ) async {
    try {
      final r = await FinanceIntegrationCallableService().testFinanceConnection(
        companyId: _companyId,
        connectionId: c.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.reachable
                ? 'Dostupnost: u redu (${r.httpStatus ?? '—'}). ${r.detail}'
                : 'Dostupnost: problem. ${r.detail}',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Test nije uspio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = FinanceConnectionService();
    final dateFmt = DateFormat('dd.MM.yyyy');
    return StreamBuilder<List<FinanceConnectionModel>>(
      stream: svc.watchConnections(_companyId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    financeUserFacingLoadError(snap.error),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                FinanceTechnicalInfoIcon(detail: '${snap.error}'),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _canManage
                  ? 'Nema definiranih veza. Dodajte prvu.'
                  : 'Nema veza za prikaz.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return Column(
          children: rows.map((c) {
            final providerLabel = FinanceProviderConstants.displayLabel(
              c.provider,
            );
            final last = c.lastSuccessfulSyncAt;
            final lastLabel = last != null ? dateFmt.format(last) : '—';
            final testOk = c.lastConnectionTestOk;
            final testPart = testOk == null
                ? ''
                : ' · zadnji test: ${testOk ? 'ok' : 'neuspješan'}';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                c.connectionName.isNotEmpty ? c.connectionName : providerLabel,
              ),
              subtitle: Text(
                '${c.status.isNotEmpty ? c.status : 'nepoznato'} · '
                '$providerLabel · zadnji uspješni sinkron: $lastLabel$testPart',
              ),
              isThreeLine: true,
              trailing: _canManage
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Testiraj dostupnost URL-a',
                          icon: const Icon(Icons.cloud_sync_outlined, size: 22),
                          onPressed: () => _testConnection(context, c),
                        ),
                        IconButton(
                          tooltip: 'Uredi',
                          icon: const Icon(Icons.edit_outlined, size: 22),
                          onPressed: () => _openEditor(context, existing: c),
                        ),
                      ],
                    )
                  : null,
              onTap: _canManage
                  ? () => _openEditor(context, existing: c)
                  : null,
            );
          }).toList(),
        );
      },
    );
  }
}
