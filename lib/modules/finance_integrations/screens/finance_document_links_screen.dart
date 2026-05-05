import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/finance_connection_model.dart';
import '../models/finance_document_link_model.dart';
import '../services/finance_connection_service.dart';
import '../services/finance_document_links_service.dart';
import '../services/finance_integration_callable_service.dart';
import '../utils/finance_load_error_presenter.dart';
import '../utils/finance_permissions.dart';
import '../utils/finance_provider_constants.dart';

/// Veze entiteta Operonix ↔ ERP.
class FinanceDocumentLinksScreen extends StatelessWidget {
  const FinanceDocumentLinksScreen({
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

  @override
  Widget build(BuildContext context) {
    final links = FinanceDocumentLinksService();
    final conns = FinanceConnectionService();

    if (!FinancePermissions.canViewErpIntegrationLayer(
      companyData: companyData,
      debugUnlockModule: debugUnlockModule,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Veze dokumenata')),
        body: const Center(child: Text('Nemate pristup.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Veze dokumenata'),
        actions: [
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova veza',
              onPressed: () => _openEditor(context, conns: conns),
            ),
        ],
      ),
      body: StreamBuilder<List<FinanceDocumentLinkModel>>(
        stream: links.watchLinks(_companyId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(financeUserFacingLoadError(snap.error)));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nema spremljenih veza. Dodajte prvu ili pričekajte da je pozadinski sync popuni.',
                      textAlign: TextAlign.center,
                    ),
                    if (_canManage) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openEditor(context, conns: conns),
                        icon: const Icon(Icons.add),
                        label: const Text('Dodaj vezu'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                isThreeLine: true,
                title: Text(
                  '${r.operonixEntityType} · ${r.operonixEntityId}',
                  maxLines: 2,
                ),
                subtitle: Text(
                  '${FinanceProviderConstants.displayLabel(r.provider)}\n'
                  'ERP: ${r.erpDocumentNumber.isNotEmpty ? r.erpDocumentNumber : r.erpEntityId}',
                ),
                trailing: _canManage
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(
                          context,
                          conns: conns,
                          existing: r,
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    required FinanceConnectionService conns,
    FinanceDocumentLinkModel? existing,
  }) async {
    final snap = await conns.watchConnections(_companyId).first;
    if (!context.mounted) return;
    if (snap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prvo definirajte barem jednu ERP vezu.'),
        ),
      );
      return;
    }

    FinanceConnectionModel initialConn = snap.first;
    if (existing != null) {
      for (final e in snap) {
        if (e.id == existing.connectionId) {
          initialConn = e;
          break;
        }
      }
    }
    final cConn = ValueNotifier<FinanceConnectionModel>(initialConn);
    final oxType = TextEditingController(text: existing?.operonixEntityType ?? '');
    final oxId = TextEditingController(text: existing?.operonixEntityId ?? '');
    final erpNum = TextEditingController(text: existing?.erpDocumentNumber ?? '');
    final erpType = TextEditingController(text: existing?.erpEntityType ?? '');

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(existing == null ? 'Nova veza dokumenta' : 'Uredi vezu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<FinanceConnectionModel>(
                    valueListenable: cConn,
                    builder: (context, selectedConn, child) {
                      return DropdownButtonFormField<FinanceConnectionModel>(
                        // ignore: deprecated_member_use
                        value: selectedConn,
                        decoration: const InputDecoration(
                          labelText: 'ERP veza',
                        ),
                        items: snap
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e.connectionName.isNotEmpty
                                      ? e.connectionName
                                      : e.id,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cConn.value = v;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: oxType,
                    decoration: const InputDecoration(
                      labelText: 'Operonix tip entiteta',
                    ),
                  ),
                  TextField(
                    controller: oxId,
                    decoration: const InputDecoration(
                      labelText: 'Operonix ID entiteta',
                    ),
                  ),
                  TextField(
                    controller: erpType,
                    decoration: const InputDecoration(
                      labelText: 'ERP tip (opcionalno)',
                    ),
                  ),
                  TextField(
                    controller: erpNum,
                    decoration: const InputDecoration(
                      labelText: 'ERP broj dokumenta / referenca',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () async {
                  final sel = cConn.value;
                  try {
                    await FinanceIntegrationCallableService().upsertFinanceDocumentLink(
                      companyId: _companyId,
                      connectionId: sel.id,
                      provider: sel.provider,
                      operonixEntityType: oxType.text.trim(),
                      operonixEntityId: oxId.text.trim(),
                      erpEntityType: erpType.text.trim(),
                      erpDocumentNumber: erpNum.text.trim(),
                      linkId: existing?.id,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veza spremljena.')),
                      );
                    }
                  } on FirebaseFunctionsException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.message ?? 'Greška')),
                      );
                    }
                  }
                },
                child: const Text('Spremi'),
              ),
            ],
          );
        },
      );
    } finally {
      cConn.dispose();
      oxType.dispose();
      oxId.dispose();
      erpNum.dispose();
      erpType.dispose();
    }
  }
}
