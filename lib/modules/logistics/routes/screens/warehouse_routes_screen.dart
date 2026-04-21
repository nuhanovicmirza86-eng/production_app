import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../warehouse_hub/services/warehouse_hub_service.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../models/warehouse_route_row.dart';
import '../services/warehouse_routes_service.dart';

class WarehouseRoutesScreen extends StatefulWidget {
  const WarehouseRoutesScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  final Map<String, dynamic> companyData;
  final bool embedInHubShell;

  @override
  State<WarehouseRoutesScreen> createState() => _WarehouseRoutesScreenState();
}

class _WarehouseRoutesScreenState extends State<WarehouseRoutesScreen> {
  final _routesSvc = WarehouseRoutesService();
  final _whSvc = WarehouseHubService();

  bool _loading = true;
  String? _error;
  List<WarehouseRouteRow> _rows = const [];
  Map<String, String> _warehouseLabels = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _hasLogistics {
    final raw = widget.companyData['enabledModules'];
    if (raw is! List || raw.isEmpty) return false;
    return raw.map((e) => e.toString().trim().toLowerCase()).contains(
      'logistics',
    );
  }

  bool get _canManage {
    final r = _role;
    return r == ProductionAccessHelper.roleSuperAdmin ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleLogisticsManager;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _routesSvc.listRoutes(companyId: _companyId);
      final wh = await _whSvc.listWarehouses(companyId: _companyId);
      final labels = <String, String>{};
      for (final w in wh) {
        labels[w.id] = '${w.name} (${w.code})';
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _warehouseLabels = labels;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.toMessage(e);
      });
    }
  }

  String _whLabel(String id) => _warehouseLabels[id] ?? id;

  Future<void> _openEditor({WarehouseRouteRow? existing}) async {
    if (!_canManage) return;

    final fromCtrl = TextEditingController(text: existing?.fromWarehouseId ?? '');
    final toCtrl = TextEditingController(text: existing?.toWarehouseId ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var requiresQc = existing?.requiresQualityCheck ?? false;
    var active = existing?.active ?? true;
    final selectedTypes = <String>{
      ...?existing?.allowedItemTypes,
    };

    const allTypes = <String>[
      'raw_material',
      'semi_finished',
      'finished_good',
      'rework',
      'scrap',
      'maintenance',
      'other',
    ];

    String typeLabel(String k) {
      const m = {
        'raw_material': 'Sirovine',
        'semi_finished': 'Poluproizvod',
        'finished_good': 'Gotov proizvod',
        'rework': 'Prerada',
        'scrap': 'Otpad',
        'maintenance': 'Održavanje',
        'other': 'Ostalo',
      };
      return m[k] ?? k;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Nova ruta' : 'Uredi rutu'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: fromCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Polazni magacin',
                      border: OutlineInputBorder(),
                      helperText: 'Unutrašnja oznaka magacina (kao u listi magacina)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: toCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Odredišni magacin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dozvoljeni tipovi artikla (prazno = svi)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    children: allTypes.map((t) {
                      final sel = selectedTypes.contains(t);
                      return FilterChip(
                        label: Text(typeLabel(t)),
                        selected: sel,
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            selectedTypes.add(t);
                          } else {
                            selectedTypes.remove(t);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: requiresQc,
                    onChanged: (v) =>
                        setLocal(() => requiresQc = v ?? false),
                    title: const Text('Zahtijeva kontrolu kvaliteta'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: active,
                    onChanged: (v) => setLocal(() => active = v ?? true),
                    title: const Text('Aktivna ruta'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Napomena',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () {
                  if (fromCtrl.text.trim().isEmpty ||
                      toCtrl.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Sačuvaj'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) {
      fromCtrl.dispose();
      toCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    try {
      await _routesSvc.upsertRoute(
        companyId: _companyId,
        routeId: existing?.id,
        fromWarehouseId: fromCtrl.text.trim(),
        toWarehouseId: toCtrl.text.trim(),
        allowedItemTypes: selectedTypes.toList(),
        requiresQualityCheck: requiresQc,
        active: active,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      fromCtrl.dispose();
      toCtrl.dispose();
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta je sačuvana.')),
      );
      await _load();
    } catch (e) {
      fromCtrl.dispose();
      toCtrl.dispose();
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasLogistics) {
      final body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Modul logistike nije uključen za ovu kompaniju.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
      return wmsTabScaffold(
        embedInHubShell: widget.embedInHubShell,
        title: 'Rute magacina',
        body: body,
      );
    }

    final body = RefreshIndicator(
      onRefresh: _load,
      child: _loading && _rows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  _error!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Dozvoljeni tokovi između magacina. Prazan popis tipova znači '
                  'da nema filtriranja po tipu artikla (u ovoj verziji).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ..._rows.map((r) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        '${_whLabel(r.fromWarehouseId)} → ${_whLabel(r.toWarehouseId)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (!r.active) 'Neaktivno',
                          if (r.requiresQualityCheck) 'Kvaliteta',
                          if (r.allowedItemTypes.isNotEmpty)
                            r.allowedItemTypes.join(', ')
                          else
                            'Svi tipovi',
                          if (r.notes != null && r.notes!.isNotEmpty)
                            r.notes!,
                        ].join(' · '),
                      ),
                      trailing: _canManage
                          ? IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openEditor(existing: r),
                            )
                          : null,
                    ),
                  );
                }),
                if (_rows.isEmpty && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Još nema definiranih ruta.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
              ],
            ),
    );

    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Rute magacina',
      body: body,
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Nova ruta'),
            )
          : null,
    );
  }
}
