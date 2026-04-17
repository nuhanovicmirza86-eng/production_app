import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../production/packing/services/packing_box_service.dart';
import '../../../production/production_orders/services/production_order_service.dart';
import '../../../production/station_pages/services/production_station_page_service.dart';
import '../../inventory/services/inventory_callable_service.dart';
import '../../inventory/services/product_warehouse_stock_service.dart';
import '../services/production_label_receipt_service.dart';

/// Prijem cijele kutije: magacin dolazi iz [production_station_pages] (postavlja Admin).
class PackingBoxReceiptScreen extends StatefulWidget {
  const PackingBoxReceiptScreen({
    super.key,
    required this.companyData,
    required this.boxId,
  });

  final Map<String, dynamic> companyData;
  final String boxId;

  @override
  State<PackingBoxReceiptScreen> createState() =>
      _PackingBoxReceiptScreenState();
}

class _PackingBoxReceiptScreenState extends State<PackingBoxReceiptScreen> {
  final _boxSvc = PackingBoxService();
  final _orderService = ProductionOrderService();
  final _stockService = ProductWarehouseStockService();
  final _stationPageSvc = ProductionStationPageService();
  final _receiptService = ProductionLabelReceiptService();
  final _inventoryCallable = InventoryCallableService();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  PackingBoxRecord? _box;
  String? _warehouseId;
  String? _warehouseLabel;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final box = await _boxSvc.getBox(widget.boxId);
      if (!mounted) return;

      String? err;
      if (box == null) {
        err = 'Kutija nije pronađena.';
      } else if (box.companyId != _companyId || box.plantKey != _plantKey) {
        err = 'Kutija ne pripada ovoj tvrtki / pogonu.';
      } else if (box.status == 'received') {
        err = 'Ova kutija je već primljena.';
      }

      String? whId;
      String? whLabel;
      if (err == null && box != null) {
        final page = await _stationPageSvc.getPage(
          companyId: _companyId,
          plantKey: _plantKey,
          stationSlot: box.stationSlot,
        );
        whId = page?.outboundWarehouseId?.trim();
        if (whId == null || whId.isEmpty) {
          err =
              'Admin nije postavio izlazni magacin za ovu stanicu '
              '(Stranice stanica → izlazni magacin nakon stanice).';
        } else {
          final warehouses = await _stockService.listActiveWarehouses(
            companyId: _companyId,
            plantKey: _plantKey,
          );
          final match = warehouses.where((w) => w.id == whId).toList();
          if (match.isEmpty) {
            err =
                'Magacin iz konfiguracije stanice nije aktivan ili ne pripada ovom pogonu.';
          } else {
            whLabel = '${match.first.name} (${match.first.code})';
          }
        }
      }

      setState(() {
        _box = box;
        _warehouseId = whId;
        _warehouseLabel = whLabel;
        _loading = false;
        _error = err;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.toMessage(e);
      });
    }
  }

  Future<void> _submit() async {
    final box = _box;
    final whId = _warehouseId;
    if (box == null || whId == null || whId.isEmpty) return;

    setState(() => _submitting = true);
    final extra = _notesController.text.trim();
    final errors = <String>[];

    try {
      for (final line in box.lines) {
        final pn = (line.productionOrderCode ?? '').trim();
        if (pn.isEmpty) {
          errors.add(
            '${line.productCode}: nema broja naloga (PN) — stavka se ne knjiži.',
          );
          continue;
        }
        final order = await _orderService.getByProductionOrderCode(
          companyId: _companyId,
          plantKey: _plantKey,
          productionOrderCode: pn,
        );
        if (order == null) {
          errors.add('PN $pn: nalog nije pronađen.');
          continue;
        }
        final labelFields = <String, dynamic>{
          'pn': pn,
          'pcode': line.productCode,
          'piece': line.productName,
          'qty': '${line.qtyGood} ${line.unit}',
          'op': line.preparedByDisplayName ?? '—',
          'cls': box.classification,
          'ts': DateTime.now().toUtc().toIso8601String(),
        };
        try {
          final movementId = await _receiptService.createPendingMovementFromLabel(
            companyId: _companyId,
            plantKey: _plantKey,
            toWarehouseId: whId,
            order: order,
            labelFields: labelFields,
            extraNote: extra.isEmpty ? null : '$extra · kutija ${widget.boxId}',
          );
          await _inventoryCallable.confirmInventoryMovement(
            companyId: _companyId,
            movementId: movementId,
          );
        } catch (e) {
          errors.add('${line.productCode}: ${AppErrorMapper.toMessage(e)}');
        }
      }

      if (errors.isEmpty) {
        await _boxSvc.markReceived(
          companyId: _companyId,
          boxId: widget.boxId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _warehouseLabel != null
                  ? 'Kutija je primljena u $_warehouseLabel.'
                  : 'Kutija je primljena u magacin.',
            ),
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Djelomični uspjeh'),
          content: SingleChildScrollView(
            child: Text(errors.join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    return Scaffold(
      appBar: AppBar(title: const Text('Prijem kutije (Stanica 1)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (box != null) ...[
                  Text(
                    'Kutija ${widget.boxId.length > 8 ? widget.boxId.substring(widget.boxId.length - 8) : widget.boxId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Stavki: ${box.lines.length} · ${box.classification}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Stavke',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...box.lines.map(
                    (l) => ListTile(
                      dense: true,
                      title: Text('${l.productCode} · ${l.productName}'),
                      subtitle: Text(
                        '${l.qtyGood} ${l.unit} · PN: ${l.productionOrderCode ?? "—"}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Izlazni magacin (nakon stanice)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _warehouseLabel ??
                                (_warehouseId != null && _warehouseId!.isNotEmpty
                                    ? _warehouseId!
                                    : '—'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Izlazni magacin za stanicu ${box.stationSlot} (postavlja Admin '
                            'u „Stranice stanica“); logistika ne bira ručno.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Napomena (opciono)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        _submitting ||
                            box.lines.isEmpty ||
                            _warehouseId == null ||
                            _warehouseId!.isEmpty ||
                            _error != null
                        ? null
                        : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.inventory_2_outlined),
                    label: Text(
                      _submitting ? 'Knjiženje…' : 'Primijeni u magacin',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
