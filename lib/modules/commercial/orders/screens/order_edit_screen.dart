import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/order_model.dart';
import '../order_status_ui.dart';
import '../services/orders_service.dart';

class _LineEditors {
  _LineEditors({required this.item, required this.qtyController, this.dueDate});

  final OrderItemModel item;
  final TextEditingController qtyController;
  DateTime? dueDate;
}

/// Uređivanje zaglavlja i stavki (količina/rok) uz pravila servisa.
class OrderEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final OrderModel order;

  const OrderEditScreen({
    super.key,
    required this.companyData,
    required this.order,
  });

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final OrdersService _ordersService = OrdersService();

  final _notesController = TextEditingController();
  final _customerRefController = TextEditingController();
  final _supplierRefController = TextEditingController();
  final _currencyController = TextEditingController();

  late DateTime _orderDate;
  DateTime? _requestedDeliveryDate;
  DateTime? _confirmedDeliveryDate;

  late List<_LineEditors> _lines;

  bool _submitting = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userId => (widget.companyData['userId'] ?? '').toString().trim();

  bool _lineQtyEditable(OrderItemModel it) {
    if (it.linkedProductionOrderCodes.isNotEmpty) return false;
    if (it.deliveredQty > 0 || it.receivedQty > 0) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _notesController.text = (o.notes ?? '').trim();
    _customerRefController.text = (o.customerReference ?? '').trim();
    _supplierRefController.text = (o.supplierReference ?? '').trim();
    _currencyController.text = (o.currency ?? '').trim();
    _orderDate = o.orderDate ?? o.createdAt ?? DateTime.now();
    _requestedDeliveryDate = o.requestedDeliveryDate;
    _confirmedDeliveryDate = o.confirmedDeliveryDate;

    _lines = o.items.map((it) {
      final q = it.qty == it.qty.roundToDouble()
          ? it.qty.toInt().toString()
          : it.qty.toString().replaceAll('.', ',');
      return _LineEditors(
        item: it,
        qtyController: TextEditingController(text: q),
        dueDate: it.dueDate,
      );
    }).toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customerRefController.dispose();
    _supplierRefController.dispose();
    _currencyController.dispose();
    for (final l in _lines) {
      l.qtyController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(_orderDate.year - 5),
      lastDate: DateTime(_orderDate.year + 5),
    );
    if (picked != null) setState(() => _orderDate = picked);
  }

  Future<void> _pickRequested() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _requestedDeliveryDate = picked);
  }

  Future<void> _pickConfirmed() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _confirmedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _confirmedDeliveryDate = picked);
  }

  Future<void> _pickLineDue(int index) async {
    final line = _lines[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: line.dueDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => line.dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyId.isEmpty || _userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje companyId ili userId.')),
      );
      return;
    }

    for (var i = 0; i < _lines.length; i++) {
      final le = _lines[i];
      if (!_lineQtyEditable(le.item)) continue;
      final raw = le.qtyController.text.trim().replaceAll(',', '.');
      final q = double.tryParse(raw);
      if (q == null || q <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stavka ${i + 1}: unesi ispravnu količinu.')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await _ordersService.updateOrderHeader(
        companyId: _companyId,
        orderId: widget.order.id,
        updatedBy: _userId,
        orderDate: _orderDate,
        requestedDeliveryDate: _requestedDeliveryDate,
        confirmedDeliveryDate: _confirmedDeliveryDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        customerReference: _customerRefController.text.trim().isEmpty
            ? null
            : _customerRefController.text.trim(),
        supplierReference: _supplierRefController.text.trim().isEmpty
            ? null
            : _supplierRefController.text.trim(),
        currency: _currencyController.text.trim().isEmpty
            ? null
            : _currencyController.text.trim(),
      );

      for (final le in _lines) {
        if (!_lineQtyEditable(le.item)) continue;
        final docId = le.item.orderItemDocId;
        if (docId == null || docId.isEmpty) continue;

        final raw = le.qtyController.text.trim().replaceAll(',', '.');
        final newQty = double.parse(raw);

        final qtyChanged = (newQty - le.item.qty).abs() > 1e-9;
        final dueChanged =
            (le.dueDate?.millisecondsSinceEpoch ?? -1) !=
            (le.item.dueDate?.millisecondsSinceEpoch ?? -1);
        if (!qtyChanged && !dueChanged) continue;

        await _ordersService.updateOrderItemOrderedAndDue(
          companyId: _companyId,
          orderId: widget.order.id,
          orderItemId: docId,
          updatedBy: _userId,
          orderedQty: newQty,
          dueDate: le.dueDate,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Narudžba je ažurirana.')));
      Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) {
    final o = widget.order;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uredi narudžbu'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
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
            Text(
              o.orderNumber,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${_typeLabel(o.orderType)} · ${o.partnerName}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${orderStatusLabel(o.status)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Datum narudžbe'),
              subtitle: Text(
                '${_orderDate.day.toString().padLeft(2, '0')}.'
                '${_orderDate.month.toString().padLeft(2, '0')}.'
                '${_orderDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickOrderDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Traženi rok isporuke'),
              subtitle: Text(
                _requestedDeliveryDate == null
                    ? '—'
                    : '${_requestedDeliveryDate!.day.toString().padLeft(2, '0')}.'
                          '${_requestedDeliveryDate!.month.toString().padLeft(2, '0')}.'
                          '${_requestedDeliveryDate!.year}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_requestedDeliveryDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _requestedDeliveryDate = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickRequested,
                  ),
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Potvrđeni rok isporuke'),
              subtitle: Text(
                _confirmedDeliveryDate == null
                    ? '—'
                    : '${_confirmedDeliveryDate!.day.toString().padLeft(2, '0')}.'
                          '${_confirmedDeliveryDate!.month.toString().padLeft(2, '0')}.'
                          '${_confirmedDeliveryDate!.year}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_confirmedDeliveryDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _confirmedDeliveryDate = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickConfirmed,
                  ),
                ],
              ),
            ),
            if (o.orderType == OrderType.customer) ...[
              TextFormField(
                controller: _customerRefController,
                decoration: const InputDecoration(labelText: 'Referenca kupca'),
              ),
            ] else ...[
              TextFormField(
                controller: _supplierRefController,
                decoration: const InputDecoration(
                  labelText: 'Referenca dobavljača',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyController,
              decoration: const InputDecoration(
                labelText: 'Valuta (opcionalno)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Napomena'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            Text(
              'Stavke',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...List.generate(_lines.length, (i) {
              final le = _lines[i];
              final editable = _lineQtyEditable(le.item);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${le.item.productCode} — ${le.item.productName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (!editable)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Količina i rok su zaključani (veza na PN ili isporuka/primka).',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      else ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: le.qtyController,
                          decoration: InputDecoration(
                            labelText: 'Naručeno (${le.item.unit})',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Rok stavke'),
                          subtitle: Text(
                            le.dueDate == null
                                ? '—'
                                : '${le.dueDate!.day.toString().padLeft(2, '0')}.'
                                      '${le.dueDate!.month.toString().padLeft(2, '0')}.'
                                      '${le.dueDate!.year}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (le.dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => le.dueDate = null),
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_today_outlined),
                                onPressed: () => _pickLineDue(i),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _typeLabel(OrderType type) {
    switch (type) {
      case OrderType.customer:
        return 'Kupac';
      case OrderType.supplier:
        return 'Dobavljač';
    }
  }
}
