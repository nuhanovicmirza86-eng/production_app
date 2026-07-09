import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../../production_orders/models/production_order_model.dart';
import '../../production_orders/services/production_order_service.dart';
import '../../station_pages/models/production_station_config.dart';
import '../../station_pages/models/production_station_page.dart';
import '../models/production_station_work_session.dart';
import '../services/production_station_work_session_callable_service.dart';
import '../services/production_station_work_session_service.dart';

/// M2 pilot — **Prva kontrola** (Stanica 2 / `standard_production`, bez packinga).
class Station2WorkScreen extends StatefulWidget {
  const Station2WorkScreen({
    super.key,
    required this.companyData,
    required this.stationConfig,
    this.onCloseStation,
  });

  final Map<String, dynamic> companyData;
  final ProductionStationConfig stationConfig;
  final VoidCallback? onCloseStation;

  @override
  State<Station2WorkScreen> createState() => _Station2WorkScreenState();
}

class _Station2WorkScreenState extends State<Station2WorkScreen> {
  final _sessionService = ProductionStationWorkSessionService();
  final _sessionCallables = ProductionStationWorkSessionCallableService();
  final _orderService = ProductionOrderService();

  final _goodCtrl = TextEditingController();
  final _scrapCtrl = TextEditingController();
  final _reworkCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  List<ProductionOrderModel> _selectableOrders = const [];
  ProductionOrderModel? _selectedOrder;
  bool _ordersLoading = true;
  Object? _ordersError;
  bool _busy = false;
  String _plantDisplayLabel = '';

  bool get _supportsOsWindowChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey => widget.stationConfig.assignedPlantKey.trim().isNotEmpty
      ? widget.stationConfig.assignedPlantKey.trim()
      : ProductionStationPage.plantKeyForStationContext(widget.companyData);

  String get _stationTitle {
    final d = widget.stationConfig.displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    return 'Prva kontrola';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlantDisplayLabel());
    unawaited(_loadOrders());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_supportsOsWindowChrome) {
        unawaited(windowManager.setFullScreen(true));
      }
    });
  }

  @override
  void dispose() {
    _goodCtrl.dispose();
    _scrapCtrl.dispose();
    _reworkCtrl.dispose();
    _commentCtrl.dispose();
    if (_supportsOsWindowChrome) {
      unawaited(windowManager.setFullScreen(false));
    }
    super.dispose();
  }

  Future<void> _loadPlantDisplayLabel() async {
    final label = await CompanyPlantDisplayName.resolve(
      companyId: _companyId,
      plantKey: _plantKey,
    );
    if (!mounted) return;
    setState(() => _plantDisplayLabel = label.trim());
  }

  Future<void> _loadOrders() async {
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
    });
    try {
      final recent = await _orderService.getRecentOrders(
        companyId: _companyId,
        plantKey: _plantKey,
        limit: 80,
      );
      final filtered = recent
          .where(
            (o) => o.status == 'released' || o.status == 'in_progress',
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _selectableOrders = filtered;
        _selectedOrder = null;
        _ordersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ordersError = e;
        _ordersLoading = false;
      });
    }
  }

  Future<void> _closeStation() async {
    if (_supportsOsWindowChrome) {
      try {
        await windowManager.setFullScreen(false);
      } catch (_) {}
    }
    if (!mounted) return;
    if (widget.onCloseStation != null) {
      widget.onCloseStation!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startSession() async {
    final order = _selectedOrder;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi proizvodni nalog.')),
      );
      return;
    }
    await _runBusy(() async {
      await _sessionCallables.startProductionStationWorkSession(
        companyId: _companyId,
        stationSlot: widget.stationConfig.stationSlot,
        productionOrderId: order.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontrolna sesija pokrenuta.')),
      );
    });
  }

  Future<void> _pauseSession(ProductionStationWorkSession session) async {
    await _runBusy(() async {
      await _sessionCallables.updateProductionStationWorkSession(
        companyId: _companyId,
        sessionId: session.id,
        action: 'pause',
      );
    });
  }

  Future<void> _resumeSession(ProductionStationWorkSession session) async {
    await _runBusy(() async {
      await _sessionCallables.updateProductionStationWorkSession(
        companyId: _companyId,
        sessionId: session.id,
        action: 'resume',
      );
    });
  }

  Future<void> _finishSession(ProductionStationWorkSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Završi kontrolu'),
        content: const Text('Zatvoriti trenutnu kontrolnu sesiju na stanici?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Završi kontrolu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _runBusy(() async {
      await _sessionCallables.finishProductionStationWorkSession(
        companyId: _companyId,
        sessionId: session.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kontrola završena.')),
      );
    });
  }

  Future<void> _recordOutput(ProductionStationWorkSession session) async {
    final good = double.tryParse(_goodCtrl.text.replaceAll(',', '.')) ?? 0;
    final scrap = double.tryParse(_scrapCtrl.text.replaceAll(',', '.')) ?? 0;
    final rework = double.tryParse(_reworkCtrl.text.replaceAll(',', '.')) ?? 0;
    if (good + scrap + rework <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesi barem jednu količinu veću od 0.')),
      );
      return;
    }

    await _runBusy(() async {
      final result = await _sessionCallables.updateProductionStationWorkSession(
        companyId: _companyId,
        sessionId: session.id,
        action: 'record_output',
        goodQtyDelta: good,
        scrapQtyDelta: scrap,
        reworkQtyDelta: rework,
        comment: _commentCtrl.text.trim(),
      );
      final updated = result.session;
      _goodCtrl.clear();
      _scrapCtrl.clear();
      _reworkCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Zapisano: ispravni ${updated.goodQty.toStringAsFixed(0)}, '
            'škart ${updated.scrapQty.toStringAsFixed(0)}, '
            'dorada ${updated.reworkQty.toStringAsFixed(0)}, '
            'ukupno kontrolisano ${(updated.goodQty + updated.scrapQty + updated.reworkQty).toStringAsFixed(0)}.',
          ),
        ),
      );
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case ProductionStationWorkSession.statusOpen:
        return 'U kontroli';
      case ProductionStationWorkSession.statusPaused:
        return 'Pauzirano / zastoj';
      case ProductionStationWorkSession.statusClosed:
        return 'Završeno';
      default:
        return status;
    }
  }

  String get _plantLine {
    final fromSession =
        (widget.companyData['plantDisplayName'] ??
                widget.companyData['plantName'] ??
                '')
            .toString()
            .trim();
    final label = _plantDisplayLabel.isNotEmpty
        ? _plantDisplayLabel
        : fromSession.isNotEmpty
        ? fromSession
        : _plantKey;
    if (label.isEmpty) return 'Pogon: —';
    return 'Pogon: $label';
  }

  String _routingLabel({
    required ProductionOrderModel order,
    ProductionStationWorkOrderSnapshot? snap,
  }) {
    final version = (snap?.routingVersion ?? order.routingVersion).trim();
    final operation = (snap?.operationName ?? order.operationName)?.trim() ?? '';
    final routingId = (snap?.routingId ?? order.routingId).trim().toLowerCase();

    final placeholderId = routingId.isEmpty || routingId == 'unspecified';
    final placeholderVersion = version.isEmpty || version == '0';

    if (placeholderId && placeholderVersion && operation.isEmpty) {
      return 'Nije definisano';
    }

    final parts = <String>[];
    if (!placeholderVersion) parts.add(version.trim());
    if (operation.isNotEmpty) parts.add(operation);
    if (parts.isEmpty) return 'Nije definisano';
    return parts.join(' — ');
  }

  Widget _buildOrderSummaryCompact(ProductionOrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.productionOrderCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${order.productCode} — ${order.productName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Planirano: ${order.plannedQty.toStringAsFixed(0)} ${order.unit}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _openOrderPicker() async {
    if (_selectableOrders.isEmpty || _busy) return;

    final picked = await showModalBottomSheet<ProductionOrderModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(
                    'Odaberi radni nalog',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _selectableOrders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = _selectableOrders[index];
                      final selected = _selectedOrder?.id == order.id;
                      return Material(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(ctx, order),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildOrderSummaryCompact(order),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedOrder = picked);
    }
  }

  Widget _buildOrderSelector() {
    return InkWell(
      onTap: _busy ? null : _openOrderPicker,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Radni nalog',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.list_alt),
          enabled: !_busy,
        ),
        child: _selectedOrder == null
            ? Text(
                'Odaberi radni nalog',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : _buildOrderSummaryCompact(_selectedOrder!),
      ),
    );
  }

  Widget _buildSessionActions(ProductionStationWorkSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(_statusLabel(session.status)),
            backgroundColor:
                session.status == ProductionStationWorkSession.statusPaused
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (session.status == ProductionStationWorkSession.statusOpen)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pauseSession(session),
                icon: const Icon(Icons.pause),
                label: const Text('Pauziraj / zastoj'),
              )
            else if (session.status == ProductionStationWorkSession.statusPaused)
              FilledButton.icon(
                onPressed: _busy ? null : () => _resumeSession(session),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Nastavi rad'),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _finishSession(session),
              icon: const Icon(Icons.stop),
              label: const Text('Završi kontrolu'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }

  Widget _buildNoSession() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Pokreni kontrolu',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Odaberi aktivni proizvodni nalog. Automatsko planiranje po stanici nije u M2 pilotu.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (_ordersLoading)
          const Center(child: CircularProgressIndicator())
        else if (_ordersError != null)
          Text('Greška učitavanja naloga: $_ordersError')
        else if (_selectableOrders.isEmpty)
          const Text('Nema released / in_progress naloga za ovaj pogon.')
        else ...[
          _buildOrderSelector(),
          const SizedBox(height: 16),
          if (_selectedOrder != null) _buildOrderPreview(_selectedOrder!, null),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || _selectedOrder == null ? null : _startSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Pokreni kontrolu'),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderPreview(
    ProductionOrderModel order,
    ProductionStationWorkSession? session,
  ) {
    final produced = order.producedGoodQty;
    final remaining = (order.plannedQty - produced).clamp(0, double.infinity);
    final snap = session?.orderSnapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Radni nalog',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _infoRow('Nalog', order.productionOrderCode),
            _infoRow('Proizvod', '${order.productCode} — ${order.productName}'),
            _infoRow('Planirano', '${order.plannedQty.toStringAsFixed(0)} ${order.unit}'),
            _infoRow('Već proizvedeno', '${produced.toStringAsFixed(0)} ${order.unit}'),
            _infoRow('Preostalo', '${remaining.toStringAsFixed(0)} ${order.unit}'),
            _infoRow('BOM verzija', snap?.bomVersion ?? order.bomVersion),
            _infoRow('Routing', _routingLabel(order: order, snap: snap)),
            if ((snap?.workInstructions ?? order.notes)?.isNotEmpty == true)
              _infoRow(
                'Upute za rad',
                snap?.workInstructions ?? order.notes ?? '',
              ),
            if (session != null) ...[
              const Divider(height: 24),
              _infoRow('Sesija — ispravni', session.goodQty.toStringAsFixed(0)),
              _infoRow('Sesija — škart', session.scrapQty.toStringAsFixed(0)),
              _infoRow('Sesija — dorada', session.reworkQty.toStringAsFixed(0)),
              _infoRow(
                'Kontrolisano ukupno',
                (session.goodQty + session.scrapQty + session.reworkQty)
                    .toStringAsFixed(0),
              ),
              _infoRow(
                'Zastoj (min)',
                session.downtimeMinutes.toStringAsFixed(1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSession(ProductionStationWorkSession session) {
    return StreamBuilder<ProductionOrderModel?>(
      stream: _orderService.watchById(
        id: session.productionOrderId,
        companyId: _companyId,
        plantKey: _plantKey,
      ),
      builder: (context, orderSnap) {
        final order = orderSnap.data;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSessionActions(session),
            const SizedBox(height: 16),
            if (order != null)
              _buildOrderPreview(order, session)
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    session.orderSnapshot?.productionOrderCode.isNotEmpty == true
                        ? 'Nalog: ${session.orderSnapshot!.productionOrderCode}'
                        : 'Učitavanje naloga…',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Unos kontrole',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _goodCtrl,
                    enabled: !_busy &&
                        session.status == ProductionStationWorkSession.statusOpen,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Ispravni komadi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _scrapCtrl,
                    enabled: !_busy &&
                        session.status == ProductionStationWorkSession.statusOpen,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Škart',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _reworkCtrl,
                    enabled: !_busy &&
                        session.status == ProductionStationWorkSession.statusOpen,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Dorada / rework',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Komentar kontrole',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ||
                      session.status != ProductionStationWorkSession.statusOpen
                  ? null
                  : () => _recordOutput(session),
              icon: const Icon(Icons.save_alt),
              label: const Text('Zabilježi kontrolu'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: IconButton(
          tooltip: 'Zatvori stanicu',
          icon: const Icon(Icons.close),
          onPressed: _closeStation,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stationTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _plantLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                BaFormattedDate.formatFullDate(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<ProductionStationWorkSession?>(
        stream: _sessionService.watchActiveSession(
          companyId: _companyId,
          stationSlot: widget.stationConfig.stationSlot,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final session = snap.data;
          if (session == null) return _buildNoSession();
          return _buildActiveSession(session);
        },
      ),
    );
  }
}
