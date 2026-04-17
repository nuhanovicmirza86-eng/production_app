import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../logistics/inventory/widgets/product_warehouse_stock_section.dart';
import '../../../production/bom/services/bom_service.dart';
import '../../../production/products/services/product_lookup_service.dart';
import '../../../production/production_orders/services/production_order_technical_refs_resolver.dart';
import '../models/order_model.dart';
import '../services/orders_service.dart';

/// Kreiranje draft proizvodnog naloga iz stavke kupčeve narudžbe (sljedljivost → PN).
class OrderLineProductionCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final OrderModel order;
  final OrderItemModel item;

  const OrderLineProductionCreateScreen({
    super.key,
    required this.companyData,
    required this.order,
    required this.item,
  });

  @override
  State<OrderLineProductionCreateScreen> createState() =>
      _OrderLineProductionCreateScreenState();
}

class _OrderLineProductionCreateScreenState
    extends State<OrderLineProductionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ordersService = OrdersService();
  final _productLookup = ProductLookupService();
  final _refsResolver = ProductionOrderTechnicalRefsResolver();
  final _bomService = BomService();

  late final TextEditingController _qtyController;
  final TextEditingController _inputMaterialLotController =
      TextEditingController();
  DateTime? _scheduledEndAt;

  bool _loadingProduct = true;
  bool _submitting = false;
  String? _loadError;
  ProductLookupItem? _product;
  String? _resolvedBomClassification;
  bool _loadingBomClassification = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  /// PN je vezan za pogon iz sesije (`companyData`), ne za narudžbu (firma).
  String get _plantKeyForProduction =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.qty == widget.item.qty.roundToDouble()
          ? widget.item.qty.toInt().toString()
          : widget.item.qty.toString(),
    );
    _scheduledEndAt = widget.item.dueDate ?? widget.order.requestedDeliveryDate;
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final pid = widget.item.productId.trim();
    if (pid.isEmpty) {
      setState(() {
        _loadingProduct = false;
        _loadError =
            'Stavka nema productId iz šifrarnika. Nova polja dolaze pri kreiranju narudžbe s odabranim proizvodom.';
      });
      return;
    }

    try {
      final p = await _productLookup.getByProductId(
        companyId: _companyId,
        productId: pid,
      );
      if (!mounted) return;
      setState(() {
        _product = p;
        _loadingProduct = false;
        if (p == null) {
          _loadError =
              'Proizvod nije pronađen ili nije aktivan. Provjeri productId na stavci.';
        }
      });
      if (p != null) {
        await _resolveBomClassification();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProduct = false;
        _loadError = AppErrorMapper.toMessage(e);
      });
    }
  }

  Future<void> _resolveBomClassification() async {
    final p = _product;
    if (p == null) return;
    setState(() {
      _loadingBomClassification = true;
      _resolvedBomClassification = null;
    });
    try {
      final refs = await _refsResolver.resolve(
        companyId: _companyId,
        productId: p.productId,
        productBomId: p.bomId,
        productBomVersion: p.bomVersion,
        productRoutingId: p.routingId,
        productRoutingVersion: p.routingVersion,
      );
      if (!mounted) return;
      if (refs == null) {
        setState(() => _loadingBomClassification = false);
        return;
      }
      final cls = await _bomService.getClassificationForBomId(
        refs['bomId']?.toString() ?? '',
      );
      if (!mounted) return;
      setState(() {
        _loadingBomClassification = false;
        _resolvedBomClassification = cls;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBomClassification = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledEndAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _scheduledEndAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final docId = widget.item.orderItemDocId?.trim() ?? '';
    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nedostaje ID stavke u bazi. Osvježi detalje narudžbe.',
          ),
        ),
      );
      return;
    }

    if (_scheduledEndAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi rok završetka izrade')),
      );
      return;
    }

    final p = _product;
    if (p == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Proizvod nije učitan')));
      return;
    }

    final refs = await _refsResolver.resolve(
      companyId: _companyId,
      productId: p.productId,
      productBomId: p.bomId,
      productBomVersion: p.bomVersion,
      productRoutingId: p.routingId,
      productRoutingVersion: p.routingVersion,
    );

    if (refs == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nedostaju podaci za tehničke reference (kompanija / proizvod).',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    if (_plantKeyForProduction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nedostaje plantKey u sesiji (pogon) — potreban za kreiranje proizvodnog naloga.',
          ),
        ),
      );
      return;
    }

    double plannedQty;
    try {
      plannedQty = double.parse(
        _qtyController.text.trim().replaceAll(',', '.'),
      );
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Neispravna količina')));
      return;
    }
    if (plannedQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Količina mora biti veća od 0')),
      );
      return;
    }

    if (_resolvedBomClassification == 'SECONDARY' &&
        _inputMaterialLotController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Za SK (sekundarna sastavnica) unesi lot materijala ili šaržu.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final unit = (p.unit ?? '').trim().isNotEmpty
          ? p.unit!.trim()
          : widget.item.unit.trim().isNotEmpty
          ? widget.item.unit.trim()
          : 'kom';

      await _ordersService.createAndLinkProductionOrderFromOrderItem(
        companyData: widget.companyData,
        orderId: widget.order.id,
        orderNumber: widget.order.orderNumber,
        orderType: widget.order.orderType,
        partnerId: widget.order.partnerId,
        partnerName: widget.order.partnerName,
        orderItemDocId: docId,
        productId: p.productId,
        productCode: p.productCode,
        productName: p.productName,
        unit: unit,
        plantKey: _plantKeyForProduction,
        scheduledEndAt: _scheduledEndAt!,
        plannedQty: plannedQty,
        bomId: refs['bomId']!,
        bomVersion: refs['bomVersion']!,
        routingId: refs['routingId']!,
        routingVersion: refs['routingVersion']!,
        sourceOrderDate: widget.order.orderDate ?? widget.order.createdAt,
        requestedDeliveryDate:
            widget.order.requestedDeliveryDate ?? widget.item.dueDate,
        inputMaterialLot: _resolvedBomClassification == 'SECONDARY'
            ? _inputMaterialLotController.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _inputMaterialLotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order.orderType != OrderType.customer) {
      return Scaffold(
        appBar: AppBar(title: const Text('PN iz stavke')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Proizvodni nalog iz stavke podržan je samo za narudžbe kupca.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kreiraj PN iz stavke')),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_submitting) const LinearProgressIndicator(minHeight: 2),
            Text(
              '${widget.item.productCode} — ${widget.item.productName}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_loadingProduct)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Material(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_loadError!),
                ),
              )
            else if (_product != null) ...[
              _infoRow(
                'BOM',
                (_product!.bomId ?? '').trim().isEmpty &&
                        (_product!.bomVersion ?? '').trim().isEmpty
                    ? 'Nije na proizvodu — PN koristi privremenu oznaku dok ne aktiviraš sastavnicu'
                    : '${_product!.bomId ?? '—'} / ${_product!.bomVersion ?? '—'}',
              ),
              _infoRow(
                'Routing',
                '${_product!.routingId} / ${_product!.routingVersion}',
              ),
              const SizedBox(height: 12),
              ProductWarehouseStockSection(
                companyId: _companyId,
                productId: _product!.productId,
                plantKey: _plantKeyForProduction.isNotEmpty
                    ? _plantKeyForProduction
                    : null,
                fallbackUnit: _product!.unit ?? widget.item.unit,
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(
                        labelText: 'Planirana količina',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Obavezno';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Rok završetka izrade'),
                      subtitle: Text(
                        _scheduledEndAt == null
                            ? 'Nije odabrano'
                            : '${_scheduledEndAt!.day.toString().padLeft(2, '0')}.'
                                  '${_scheduledEndAt!.month.toString().padLeft(2, '0')}.'
                                  '${_scheduledEndAt!.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDate,
                    ),
                    if (_loadingBomClassification) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (!_loadingBomClassification &&
                        _resolvedBomClassification == 'SECONDARY') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _inputMaterialLotController,
                        decoration: const InputDecoration(
                          labelText: 'Lot materijala (šarža)',
                          helperText:
                              'Lot ili šarža materijala iz prethodne izrade (SK).',
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Pogon (za PN): $_plantKeyForProduction',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: const Text('Kreiraj i poveži'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
