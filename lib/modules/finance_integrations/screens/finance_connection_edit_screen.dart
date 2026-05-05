import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/access/production_access_helper.dart';
import '../models/finance_connection_model.dart';
import '../services/finance_connection_callable_service.dart';
import '../utils/finance_permissions.dart';
import '../utils/finance_provider_constants.dart';
import '../utils/finance_sync_constants.dart';

/// Obrazac za kreiranje / uređivanje `finance_connections` (Callable — bez tajni).
class FinanceConnectionEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;
  final FinanceConnectionModel? existing;

  const FinanceConnectionEditScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
    this.existing,
  });

  @override
  State<FinanceConnectionEditScreen> createState() =>
      _FinanceConnectionEditScreenState();
}

class _FinanceConnectionEditScreenState extends State<FinanceConnectionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _plantCtrl;

  late String _providerCode;
  late String _connectionType;
  late String _environment;
  late String _status;
  late String _syncDirection;
  late Set<String> _selectedSync;

  /// Ključevi kao u Callableu (`masterDataPolicy`).
  static const _masterKeys = <String>[
    'partnersMaster',
    'itemsMaster',
    'costCentersMaster',
    'productionOrdersMaster',
    'maintenanceOrdersMaster',
    'developmentProjectsMaster',
  ];

  final Map<String, String> _masterChoice = {};
  bool _saving = false;

  final _callable = FinanceConnectionCallableService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canSave => FinancePermissions.canManageConnections(
    companyData: widget.companyData,
    role: _role,
    debugUnlockModule: widget.debugUnlockModule,
  );

  bool get _showPlantField {
    final r = ProductionAccessHelper.normalizeRole(_role);
    return ProductionAccessHelper.isAdminRole(r) ||
        ProductionAccessHelper.isSuperAdminRole(r);
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.connectionName ?? '');
    _baseUrlCtrl = TextEditingController(text: ex?.baseUrl ?? '');
    _plantCtrl = TextEditingController(text: ex?.plantKey ?? '');
    _providerCode = (ex?.provider ?? FinanceProviderConstants.pantheon)
        .trim()
        .toLowerCase();
    if (!_validProvider(_providerCode)) {
      _providerCode = FinanceProviderConstants.pantheon;
    }
    _connectionType = (ex?.connectionType ?? 'api').trim().toLowerCase();
    if (_connectionType != 'api' && _connectionType != 'file') {
      _connectionType = 'api';
    }
    _environment = (ex?.environment ?? 'production').trim().toLowerCase();
    _status = (ex?.status ?? 'draft').trim().toLowerCase();
    _syncDirection =
        (ex?.syncDirection ?? 'bidirectional').trim().toLowerCase();
    _selectedSync = {...?ex?.enabledSyncTypes};

    for (final k in _masterKeys) {
      final v = ex?.masterDataPolicy?[k];
      if (v == 'erp' || v == 'operonix') {
        _masterChoice[k] = v!;
      } else {
        _masterChoice[k] = 'erp';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _plantCtrl.dispose();
    super.dispose();
  }

  bool _validProvider(String code) {
    return FinanceProviderConstants.selectableProviderCodes.contains(code);
  }

  String _masterLabel(String key) {
    switch (key) {
      case 'partnersMaster':
        return 'Partneri';
      case 'itemsMaster':
        return 'Artikli / materijali';
      case 'costCentersMaster':
        return 'Troškovna mjesta';
      case 'productionOrdersMaster':
        return 'Proizvodni nalozi';
      case 'maintenanceOrdersMaster':
        return 'Radni nalozi održavanja';
      case 'developmentProjectsMaster':
        return 'Projekti razvoja';
      default:
        return key;
    }
  }

  Future<void> _submit() async {
    if (!_canSave) return;
    final v = _formKey.currentState;
    if (v == null || !v.validate()) return;

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'companyId': _companyId,
        if (widget.existing != null) 'connectionId': widget.existing!.id,
        'connectionName': _nameCtrl.text.trim(),
        'provider': _providerCode,
        'connectionType': _connectionType,
        'status': _status,
        'syncDirection': _syncDirection,
        'enabledSyncTypes': _selectedSync.toList(),
        'masterDataPolicy': Map<String, String>.from(_masterChoice),
      };
      if (_environment.isNotEmpty) {
        payload['environment'] = _environment;
      }
      final bu = _baseUrlCtrl.text.trim();
      if (bu.isNotEmpty) {
        payload['baseUrl'] = bu;
      }
      if (_showPlantField) {
        final pk = _plantCtrl.text.trim();
        if (pk.isNotEmpty) {
          payload['plantKey'] = pk;
        }
      }

      await _callable.upsertFinanceConnection(payload);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final msg = (e.message ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isNotEmpty ? msg : 'Operacija nije uspjela.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null ? 'Nova ERP veza' : 'Uredi ERP vezu';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_canSave)
            TextButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naziv veze',
                border: OutlineInputBorder(),
              ),
              validator: (s) {
                if ((s ?? '').trim().isEmpty) {
                  return 'Unesite naziv.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _providerCode,
              decoration: const InputDecoration(
                labelText: 'ERP / provider',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in FinanceProviderConstants.selectableProviderCodes)
                  DropdownMenuItem(
                    value: c,
                    child: Text(FinanceProviderConstants.displayLabel(c)),
                  ),
              ],
              onChanged: _canSave
                  ? (v) {
                      if (v != null) {
                        setState(() => _providerCode = v);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _connectionType,
              decoration: const InputDecoration(
                labelText: 'Tip veze',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'api', child: Text('API')),
                DropdownMenuItem(value: 'file', child: Text('Datoteka (npr. CSV)')),
              ],
              onChanged: _canSave
                  ? (v) {
                      if (v != null) {
                        setState(() => _connectionType = v);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _environment,
              decoration: const InputDecoration(
                labelText: 'Okruženje',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'production', child: Text('Produkcija')),
                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')),
                DropdownMenuItem(value: 'test', child: Text('Test')),
                DropdownMenuItem(value: 'staging', child: Text('Staging')),
              ],
              onChanged: _canSave
                  ? (v) {
                      if (v != null) {
                        setState(() => _environment = v);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _baseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Bazni URL API-ja (opcionalno)',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              enabled: _canSave,
              validator: (s) {
                final t = (s ?? '').trim();
                if (t.isEmpty) return null;
                if (!t.startsWith('http://') && !t.startsWith('https://')) {
                  return 'URL mora počinjati s http:// ili https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status veze',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Nacrt')),
                DropdownMenuItem(value: 'pending', child: Text('Na čekanju')),
                DropdownMenuItem(value: 'active', child: Text('Aktivno')),
                DropdownMenuItem(value: 'inactive', child: Text('Neaktivno')),
              ],
              onChanged: _canSave
                  ? (v) {
                      if (v != null) {
                        setState(() => _status = v);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _syncDirection,
              decoration: const InputDecoration(
                labelText: 'Smjer sinkronizacije',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'bidirectional',
                  child: Text('Dvosmjerno'),
                ),
                DropdownMenuItem(
                  value: 'operonix_to_erp',
                  child: Text('Operonix → ERP'),
                ),
                DropdownMenuItem(
                  value: 'erp_to_operonix',
                  child: Text('ERP → Operonix'),
                ),
              ],
              onChanged: _canSave
                  ? (v) {
                      if (v != null) {
                        setState(() => _syncDirection = v);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Tipovi sinkronizacije',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in FinanceEnabledSyncTypes.allCodes)
                  FilterChip(
                    label:
                        Text(FinanceEnabledSyncTypes.displayLabel(code)),
                    selected: _selectedSync.contains(code),
                    onSelected: _canSave
                        ? (sel) {
                            setState(() {
                              if (sel) {
                                _selectedSync.add(code);
                              } else {
                                _selectedSync.remove(code);
                              }
                            });
                          }
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Politika master podataka',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._masterKeys.map((k) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(_masterLabel(k)),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _masterChoice[k],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'erp',
                            child: Text('ERP (izvor istine)'),
                          ),
                          DropdownMenuItem(
                            value: 'operonix',
                            child: Text('Operonix'),
                          ),
                        ],
                        onChanged: _canSave
                            ? (v) {
                                if (v != null) {
                                  setState(() => _masterChoice[k] = v);
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_showPlantField) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _plantCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'Pogon (plantKey, opcionalno — prazno = cijela kompanija)',
                  border: OutlineInputBorder(),
                ),
                enabled: _canSave,
              ),
            ],
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tajne i API ključevi se ne unose u aplikaciju. '
                  'Referenca na sigurno spremište bit će zasebna admin radnja u idućoj fazi.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
