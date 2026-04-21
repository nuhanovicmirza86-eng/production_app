import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/order_model.dart';
import '../order_status_ui.dart';
import '../services/orders_service.dart';

class _LineEditors {
  _LineEditors({
    required this.item,
    required this.qtyController,
    required this.unitPriceController,
    required this.discountController,
    required this.vatController,
    this.dueDate,
  });

  final OrderItemModel item;
  final TextEditingController qtyController;
  final TextEditingController unitPriceController;
  final TextEditingController discountController;
  final TextEditingController vatController;
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

  final _incotermsController = TextEditingController();
  final _customerCountryCodeController = TextEditingController();
  final _vatExemptionNoteController = TextEditingController();
  final _customsDeclarationRefController = TextEditingController();
  final _cmrNumberController = TextEditingController();
  final _awbNumberController = TextEditingController();

  late bool _isExport;

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
    _isExport = o.isExport;
    _incotermsController.text = (o.incoterms ?? '').trim();
    _customerCountryCodeController.text = (o.customerCountryCode ?? '').trim();
    _vatExemptionNoteController.text = (o.vatExemptionNote ?? '').trim();
    _customsDeclarationRefController.text =
        (o.customsDeclarationRef ?? '').trim();
    _cmrNumberController.text = (o.cmrNumber ?? '').trim();
    _awbNumberController.text = (o.awbNumber ?? '').trim();
    _orderDate = o.orderDate ?? o.createdAt ?? DateTime.now();
    _requestedDeliveryDate = o.requestedDeliveryDate;
    _confirmedDeliveryDate = o.confirmedDeliveryDate;

    String fmtDec(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

    _lines = o.items.map((it) {
      final q = it.qty == it.qty.roundToDouble()
          ? it.qty.toInt().toString()
          : it.qty.toString().replaceAll('.', ',');
      return _LineEditors(
        item: it,
        qtyController: TextEditingController(text: q),
        unitPriceController: TextEditingController(text: fmtDec(it.unitPrice)),
        discountController: TextEditingController(text: fmtDec(it.discountPercent)),
        vatController: TextEditingController(
          text: it.vatPercent != null ? fmtDec(it.vatPercent!) : '',
        ),
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
    _incotermsController.dispose();
    _customerCountryCodeController.dispose();
    _vatExemptionNoteController.dispose();
    _customsDeclarationRefController.dispose();
    _cmrNumberController.dispose();
    _awbNumberController.dispose();
    for (final l in _lines) {
      l.qtyController.dispose();
      l.unitPriceController.dispose();
      l.discountController.dispose();
      l.vatController.dispose();
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
        const SnackBar(
          content: Text('Nedostaje sesija. Ponovo se prijavi.'),
        ),
      );
      return;
    }

    if (widget.order.orderType == OrderType.customer) {
      final cc = _customerCountryCodeController.text.trim().toUpperCase();
      if (cc.isNotEmpty &&
          (cc.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(cc))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ISO država: točno 2 slova (npr. DE) ili prazno.'),
          ),
        );
        return;
      }
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
        isExport: widget.order.orderType == OrderType.customer
            ? _isExport
            : null,
        incoterms: widget.order.orderType == OrderType.customer
            ? _incotermsController.text.trim()
            : null,
        customerCountryCode: widget.order.orderType == OrderType.customer
            ? _customerCountryCodeController.text.trim()
            : null,
        vatExemptionNote: widget.order.orderType == OrderType.customer
            ? _vatExemptionNoteController.text.trim()
            : null,
        customsDeclarationRef: widget.order.orderType == OrderType.customer
            ? _customsDeclarationRefController.text.trim()
            : null,
        cmrNumber: widget.order.orderType == OrderType.customer
            ? _cmrNumberController.text.trim()
            : null,
        awbNumber: widget.order.orderType == OrderType.customer
            ? _awbNumberController.text.trim()
            : null,
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

        final priceRaw =
            le.unitPriceController.text.trim().replaceAll(',', '.');
        final newPrice = double.tryParse(priceRaw) ?? le.item.unitPrice;
        final discRaw =
            le.discountController.text.trim().replaceAll(',', '.');
        final newDisc = double.tryParse(discRaw) ?? le.item.discountPercent;
        final vatRaw = le.vatController.text.trim().replaceAll(',', '.');
        final newVat = vatRaw.isEmpty ? null : double.tryParse(vatRaw);
        if (vatRaw.isNotEmpty && newVat == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Stavka ${le.item.productCode}: neispravan PDV %.',
              ),
            ),
          );
          return;
        }

        final priceChanged = (newPrice - le.item.unitPrice).abs() > 1e-9;
        final discChanged = (newDisc - le.item.discountPercent).abs() > 1e-9;
        final vatChanged = vatRaw.isEmpty
            ? (le.item.vatPercent != null)
            : (le.item.vatPercent == null ||
                  (newVat! - le.item.vatPercent!).abs() > 1e-9);

        if (!qtyChanged &&
            !dueChanged &&
            !priceChanged &&
            !discChanged &&
            !vatChanged) {
          continue;
        }

        await _ordersService.updateOrderItemOrderedAndDue(
          companyId: _companyId,
          orderId: widget.order.id,
          orderItemId: docId,
          updatedBy: _userId,
          orderedQty: newQty,
          dueDate: le.dueDate,
          unitPrice: priceChanged ? newPrice : null,
          discountPercent: discChanged ? newDisc : null,
          vatPercent: vatChanged ? (vatRaw.isEmpty ? null : newVat) : null,
          clearVatPercent:
              vatChanged && vatRaw.isEmpty && le.item.vatPercent != null,
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
            if (o.orderType == OrderType.customer) ...[
              const SizedBox(height: 16),
              Text(
                'Izvoz i fiskalni podaci (BiH)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Izvoz (INO kupac)'),
                value: _isExport,
                onChanged: (v) => setState(() => _isExport = v),
              ),
              TextFormField(
                controller: _customerCountryCodeController,
                decoration: const InputDecoration(
                  labelText: 'ISO država kupca (2 slova)',
                  counterText: '',
                ),
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
              ),
              TextFormField(
                controller: _incotermsController,
                decoration: const InputDecoration(
                  labelText: 'INCOTERMS (opcionalno)',
                ),
              ),
              TextFormField(
                controller: _vatExemptionNoteController,
                decoration: const InputDecoration(
                  labelText: 'Napomena oslobođenja PDV-a',
                ),
                maxLines: 2,
              ),
              TextFormField(
                controller: _customsDeclarationRefController,
                decoration: const InputDecoration(
                  labelText: 'Referenca carinske deklaracije',
                ),
              ),
              TextFormField(
                controller: _cmrNumberController,
                decoration: const InputDecoration(labelText: 'CMR broj'),
              ),
              TextFormField(
                controller: _awbNumberController,
                decoration: const InputDecoration(labelText: 'AWB broj'),
              ),
            ],
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
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: le.unitPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Jedinična cijena',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: le.discountController,
                          decoration: const InputDecoration(
                            labelText: 'Rabat %',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: le.vatController,
                          decoration: const InputDecoration(
                            labelText: 'PDV % (prazno = podrazumijevani iz postavki)',
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
