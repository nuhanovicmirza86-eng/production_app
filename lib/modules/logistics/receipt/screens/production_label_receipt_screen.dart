import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../production/production_orders/models/production_order_model.dart';
import '../../../production/production_orders/services/production_order_service.dart';
import '../../../production/qr/production_qr_resolver.dart';
import '../../inventory/services/product_warehouse_stock_service.dart';
import '../services/production_label_receipt_service.dart';

/// Prijem robe nakon skena etikete (JSON): odabir magacina → `inventory_movements` pending.
class ProductionLabelReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final ProductionQrScanResolution resolution;

  const ProductionLabelReceiptScreen({
    super.key,
    required this.companyData,
    required this.resolution,
  });

  @override
  State<ProductionLabelReceiptScreen> createState() =>
      _ProductionLabelReceiptScreenState();
}

class _ProductionLabelReceiptScreenState
    extends State<ProductionLabelReceiptScreen> {
  final _orderService = ProductionOrderService();
  final _stockService = ProductWarehouseStockService();
  final _receiptService = ProductionLabelReceiptService();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  ProductionOrderModel? _order;
  List<WarehouseRef> _warehouses = const [];
  String? _selectedWarehouseId;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _userId =>
      (widget.companyData['userId'] ?? 'system').toString().trim();

  Map<String, dynamic> get _label =>
      widget.resolution.labelFields ?? const {};

  @override
  void initState() {
    super.initState();
    if (widget.resolution.intent !=
        ProductionQrIntent.printedClassificationLabelV1) {
      _loading = false;
      _error = 'Neispravan QR — potrebna je etiketa (klasifikacija).';
      return;
    }
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
      final pn = (_label['pn'] ?? '').toString().trim();

      final order = pn.isEmpty
          ? null
          : await _orderService.getByProductionOrderCode(
              companyId: _companyId,
              plantKey: _plantKey,
              productionOrderCode: pn,
            );

      final warehouses = await _stockService.listActiveWarehouses(
        companyId: _companyId,
        plantKey: _plantKey,
      );

      if (!mounted) return;

      setState(() {
        _order = order;
        _warehouses = warehouses;
        _loading = false;
        if (order == null && pn.isNotEmpty) {
          _error =
              'Proizvodni nalog „$pn” nije pronađen za ovu kompaniju i pogon.';
        } else if (warehouses.isEmpty) {
          _error =
              _error ??
              'Nema aktivnih magacina. Dodajte magacin u master podacima.';
        }
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
    final order = _order;
    final whId = _selectedWarehouseId;
    if (order == null || whId == null) return;

    final whExists = _warehouses.any((w) => w.id == whId);
    if (!whExists) return;

    setState(() => _submitting = true);

    try {
      await _receiptService.createPendingMovementFromLabel(
        companyId: _companyId,
        plantKey: _plantKey,
        userId: _userId,
        toWarehouseId: whId,
        order: order,
        labelFields: Map<String, dynamic>.from(_label),
        extraNote: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Prijem zabilježen (pending). Sljedeći korak: potvrda zalihe u logistici.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prijem s etikete')),
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
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Podaci s etikete',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _kv('Nalog', _label['pn']),
                _kv('Šifra', _label['pcode']),
                _kv('Komad', _label['piece']),
                _kv('Količina', _label['qty']),
                _kv('Operater', _label['op']),
                _kv('Ispis (UTC)', _label['ts']),
                _kv('Klasifikacija', _label['cls']),
                if (_order != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Veza na nalog',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _kv('Proizvod (nalog)', _order!.productName),
                  _kv('Jedinica (nalog)', _order!.unit),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Odredišni magacin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_warehouses.isEmpty)
                  const Text('—')
                else
                  ..._warehouses.map(
                    (w) => ListTile(
                      title: Text(w.name),
                      subtitle: Text(w.code),
                      selected: _selectedWarehouseId == w.id,
                      leading: Icon(
                        _selectedWarehouseId == w.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _selectedWarehouseId == w.id
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      onTap: _order == null
                          ? null
                          : () => setState(() => _selectedWarehouseId = w.id),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Napomena (opciono)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      _submitting || _order == null || _selectedWarehouseId == null
                          ? null
                          : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: Text(_submitting ? 'Snimam…' : 'Potvrdi prijem (pending)'),
                ),
              ],
            ),
    );
  }

  Widget _kv(String k, Object? v) {
    final t = (v ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(t.isEmpty ? '—' : t)),
        ],
      ),
    );
  }
}
