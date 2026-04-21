import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../models/production_plant_device_event.dart';
import '../services/production_asset_display_lookup.dart';
import '../services/production_tracking_assets_service.dart';
import '../services/production_tracking_hub_callable_service.dart';
import '../services/production_tracking_hub_firestore_service.dart';
import '../services/tracking_effective_plant_key.dart';

/// Pregled uređaja pogona (Firestore `assets`, operativno stanje) + zastoji i alarmi.
class ProductionTrackingDevicesScreen extends StatefulWidget {
  const ProductionTrackingDevicesScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionTrackingDevicesScreen> createState() =>
      _ProductionTrackingDevicesScreenState();
}

class _ProductionTrackingDevicesScreenState
    extends State<ProductionTrackingDevicesScreen> {
  final _svc = ProductionTrackingAssetsService();
  final _hub = ProductionTrackingHubFirestoreService();
  final _hubCall = ProductionTrackingHubCallableService();

  bool _loading = true;
  Object? _error;
  ProductionPlantAssetsSnapshot? _snap;
  String? _plantKey;
  ProductionAssetDisplayLookup? _assetLookup;
  final Set<String> _resolvingIds = {};

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role => (widget.companyData['role'] ?? '').toString();

  bool get _canManageHubData {
    final r = ProductionAccessHelper.normalizeRole(_role);
    return ProductionAccessHelper.isAdminRole(_role) ||
        ProductionAccessHelper.isSuperAdminRole(_role) ||
        r == ProductionAccessHelper.roleProductionManager ||
        r == ProductionAccessHelper.roleSupervisor;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pk = await resolveEffectiveTrackingPlantKey(widget.companyData);
      if (pk == null || pk.isEmpty) {
        throw StateError('Nije odabran pogon (plantKey).');
      }
      final results = await Future.wait([
        _svc.loadForPlant(
          companyId: _companyId,
          plantKey: pk,
          limit: 64,
        ),
        ProductionAssetDisplayLookup.loadForPlant(
          companyId: _companyId,
          plantKey: pk,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _snap = results[0] as ProductionPlantAssetsSnapshot;
        _assetLookup = results[1] as ProductionAssetDisplayLookup;
        _plantKey = pk;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _resolveEvent(String eventId) async {
    final pk = _plantKey;
    if (pk == null || _companyId.isEmpty) return;
    if (_resolvingIds.contains(eventId)) return;
    setState(() => _resolvingIds.add(eventId));
    try {
      await _hubCall.resolveProductionPlantDeviceEvent(
        companyId: _companyId,
        plantKey: pk,
        eventId: eventId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resolvingIds.remove(eventId));
      }
    }
  }

  Future<void> _openAddEventDialog() async {
    final pk = _plantKey;
    if (pk == null || !_canManageHubData) return;

    final kindCtrl = ValueNotifier<String>('alarm');
    final sevCtrl = ValueNotifier<String>('warning');
    final titleCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final assetCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Novi događaj'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: kindCtrl,
                  builder: (context, kind, _) {
                    return SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'alarm',
                          label: Text('Alarm'),
                          icon: Icon(Icons.notifications_active_outlined),
                        ),
                        ButtonSegment(
                          value: 'downtime',
                          label: Text('Zastoj'),
                          icon: Icon(Icons.pause_circle_outline),
                        ),
                      ],
                      selected: {kind},
                      onSelectionChanged: (s) =>
                          kindCtrl.value = s.first,
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: sevCtrl,
                  builder: (context, sev, _) {
                    return DropdownButtonFormField<String>(
                      initialValue: sev,
                      decoration: const InputDecoration(
                        labelText: 'Ozbiljnost',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'info', child: Text('Info')),
                        DropdownMenuItem(
                          value: 'warning',
                          child: Text('Upozorenje'),
                        ),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('Kritično'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) sevCtrl.value = v;
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Naslov',
                  ),
                  maxLength: 200,
                ),
                TextField(
                  controller: detailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opis (opcionalno)',
                  ),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                TextField(
                  controller: assetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Šifra uređaja (opcionalno)',
                  ),
                  maxLength: 120,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Spremi'),
            ),
          ],
        );
      },
    );

    final kind = kindCtrl.value;
    final severity = sevCtrl.value;
    final title = titleCtrl.text.trim();
    final detail = detailCtrl.text.trim();
    final asset = assetCtrl.text.trim();

    kindCtrl.dispose();
    sevCtrl.dispose();
    titleCtrl.dispose();
    detailCtrl.dispose();
    assetCtrl.dispose();

    if (ok != true || !mounted) {
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naslov je obavezan.')),
      );
      return;
    }

    try {
      await _hubCall.appendProductionPlantDeviceEvent(
        companyId: _companyId,
        plantKey: pk,
        kind: kind,
        severity: severity,
        title: title,
        detail: detail.isEmpty ? null : detail,
        assetCode: asset.isEmpty ? null : asset,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stanje uređaja'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canManageHubData &&
              _plantKey != null &&
              _error == null &&
              !_loading
          ? FloatingActionButton.extended(
              onPressed: _openAddEventDialog,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Događaj'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_plantKey != null)
                      Text(
                        'Pogon: $_plantKey · '
                        'U radu: ${_snap?.runningCount ?? 0} / ${_snap?.totalCount ?? 0} '
                        '(${_fmtPct(_snap?.runningSharePct ?? 0)})',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Zastoji i alarmi',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ručni unos ili kasnije automatski iz SCADA / MES. '
                      'Otvoreni događaji mogu se označiti kao riješeni.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_plantKey != null)
                      StreamBuilder<List<ProductionPlantDeviceEvent>>(
                        stream: _hub.watchRecentDeviceEvents(
                          companyId: _companyId,
                          plantKey: _plantKey!,
                        ),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Text(
                              AppErrorMapper.toMessage(snap.error!),
                              style: TextStyle(color: cs.error),
                            );
                          }
                          final list = snap.data ?? [];
                          if (list.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Nema prijavljenih događaja.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: cs.outline),
                              ),
                            );
                          }
                          return Column(
                            children: list
                                .map(
                                  (e) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Icon(
                                        e.kind ==
                                                ProductionPlantDeviceEventKind
                                                    .downtime
                                            ? Icons.pause_circle_outline
                                            : Icons.notifications_active_outlined,
                                        color: _severityColor(context, e),
                                      ),
                                      title: Text(
                                        _assetLookup?.resolveEventLine(
                                              e.assetCode,
                                              e.title,
                                            ) ??
                                            e.title,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (e.detail != null &&
                                              e.detail!.isNotEmpty)
                                            Text(e.detail!),
                                          Text(
                                            e.isResolved
                                                ? 'Riješeno'
                                                : 'Aktivno',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: e.isResolved
                                                      ? cs.primary
                                                      : cs.tertiary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      isThreeLine: true,
                                      trailing: !e.isResolved && _canManageHubData
                                          ? _resolvingIds.contains(e.id)
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : TextButton(
                                                  onPressed: () =>
                                                      _resolveEvent(e.id),
                                                  child: const Text('Riješi'),
                                                )
                                          : null,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Šifarnik uređaja',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if ((_snap?.machines ?? []).isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        child: Text(
                          'Nema aktivnih uređaja u šifarniku za ovaj pogon '
                          '(ili podaci još nisu uneseni).',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                      )
                    else
                      ...(_snap!.machines.map(
                        (m) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              _iconFor(m.status),
                              color: _colorFor(context, m.status),
                            ),
                            title: Text(m.title),
                            subtitle: Text(m.detail),
                            trailing: Text(
                              _labelFor(m.status),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: _colorFor(context, m.status),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      )),
                  ],
                ),
    );
  }

  static Color _severityColor(
    BuildContext context,
    ProductionPlantDeviceEvent e,
  ) {
    final cs = Theme.of(context).colorScheme;
    switch (e.severity) {
      case ProductionPlantDeviceEventSeverity.info:
        return cs.primary;
      case ProductionPlantDeviceEventSeverity.warning:
        return cs.tertiary;
      case ProductionPlantDeviceEventSeverity.critical:
        return cs.error;
    }
  }

  static String _fmtPct(double v) =>
      '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

  static IconData _iconFor(ProductionMachineStatus s) {
    switch (s) {
      case ProductionMachineStatus.running:
        return Icons.play_circle_outline;
      case ProductionMachineStatus.stopped:
        return Icons.stop_circle_outlined;
      case ProductionMachineStatus.unknown:
        return Icons.help_outline;
    }
  }

  static Color _colorFor(BuildContext context, ProductionMachineStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case ProductionMachineStatus.running:
        return cs.primary;
      case ProductionMachineStatus.stopped:
        return cs.outline;
      case ProductionMachineStatus.unknown:
        return cs.tertiary;
    }
  }

  static String _labelFor(ProductionMachineStatus s) {
    switch (s) {
      case ProductionMachineStatus.running:
        return 'U radu';
      case ProductionMachineStatus.stopped:
        return 'Zaustavljeno';
      case ProductionMachineStatus.unknown:
        return 'Nepoznato';
    }
  }
}
