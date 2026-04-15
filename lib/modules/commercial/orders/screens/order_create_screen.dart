import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../production/products/services/product_lookup_service.dart';
import '../models/order_model.dart';
import '../services/orders_service.dart';
import '../services/partners_lookup_service.dart';

class _DraftLine {
  ProductLookupItem? product;
  final TextEditingController qtyController = TextEditingController(text: '1');
  DateTime? dueDate;
}

class OrderCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const OrderCreateScreen({super.key, required this.companyData});

  @override
  State<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends State<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final OrdersService _ordersService = OrdersService();
  final PartnersLookupService _partnersLookup = PartnersLookupService();
  final ProductLookupService _productLookup = ProductLookupService();

  OrderType _orderType = OrderType.customer;
  PartnerPick? _partner;

  DateTime _orderDate = DateTime.now();
  DateTime? _requestedDeliveryDate;

  final TextEditingController _notesController = TextEditingController();

  final List<_DraftLine> _lines = <_DraftLine>[_DraftLine()];

  bool _submitting = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.qtyController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(_orderDate.year - 2),
      lastDate: DateTime(_orderDate.year + 5),
    );
    if (picked != null) {
      setState(() => _orderDate = picked);
    }
  }

  Future<void> _pickRequestedDelivery() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      setState(() => _requestedDeliveryDate = picked);
    }
  }

  Future<void> _pickLineDue(int index) async {
    final line = _lines[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: line.dueDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      setState(() => line.dueDate = picked);
    }
  }

  Future<void> _openPartnerPicker() async {
    final picked = await showModalBottomSheet<PartnerPick>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _PartnerPickerSheet(
          companyId: _companyId,
          orderType: _orderType,
          partnersLookup: _partnersLookup,
        );
      },
    );

    if (picked != null) {
      setState(() => _partner = picked);
    }
  }

  Future<void> _openProductPicker(int lineIndex) async {
    final picked = await showModalBottomSheet<ProductLookupItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _ProductPickerSheet(
          companyId: _companyId,
          productLookup: _productLookup,
        );
      },
    );

    if (picked != null) {
      setState(() => _lines[lineIndex].product = picked);
    }
  }

  void _addLine() {
    setState(() => _lines.add(_DraftLine()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].qtyController.dispose();
      _lines.removeAt(index);
    });
  }

  String _lineLabel(_DraftLine line) {
    final p = line.product;
    if (p == null) return 'Odaberi stavku (proizvod)';
    return '${p.productCode} — ${p.productName}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_partner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odaberi partnera (kupca ili dobavljača).'),
        ),
      );
      return;
    }

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stavka ${i + 1}: odaberi proizvod.')),
        );
        return;
      }

      final qty = double.tryParse(
        line.qtyController.text.trim().replaceAll(',', '.'),
      );
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stavka ${i + 1}: unesi ispravnu količinu.')),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < _lines.length; i++) {
        final line = _lines[i];
        final p = line.product!;
        final qty = double.parse(
          line.qtyController.text.trim().replaceAll(',', '.'),
        );

        final lineId =
            'L${DateTime.now().microsecondsSinceEpoch}_${i}_${items.length}';

        items.add({
          'lineId': lineId,
          'itemType': 'product',
          'productId': p.productId,
          'code': p.productCode,
          'name': p.productName,
          'orderedQty': qty,
          'unit': (p.unit ?? '').trim().isEmpty ? 'kom' : p.unit!.trim(),
          'unitPrice': 0.0,
          'dueDate': line.dueDate,
        });
      }

      await _ordersService.createOrder(
        companyData: widget.companyData,
        orderType: _orderType.value,
        partnerId: _partner!.id,
        partnerCode: _partner!.code,
        partnerName: _partner!.name,
        orderDate: _orderDate,
        requestedDeliveryDate: _requestedDeliveryDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        items: items,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Narudžba je kreirana.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova narudžba')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<OrderType>(
              segments: const [
                ButtonSegment(
                  value: OrderType.customer,
                  label: Text('Kupac'),
                  icon: Icon(Icons.shopping_cart_outlined),
                ),
                ButtonSegment(
                  value: OrderType.supplier,
                  label: Text('Dobavljač'),
                  icon: Icon(Icons.local_shipping_outlined),
                ),
              ],
              selected: {_orderType},
              onSelectionChanged: (set) {
                setState(() {
                  _orderType = set.first;
                  _partner = null;
                });
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Partner'),
              subtitle: Text(
                _partner == null
                    ? 'Odaberi kupca ili dobavljača'
                    : '${_partner!.code} — ${_partner!.name}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openPartnerPicker,
            ),
            const Divider(),
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
              title: const Text('Traženi datum isporuke'),
              subtitle: Text(
                _requestedDeliveryDate == null
                    ? 'Nije postavljen'
                    : '${_requestedDeliveryDate!.day.toString().padLeft(2, '0')}.'
                          '${_requestedDeliveryDate!.month.toString().padLeft(2, '0')}.'
                          '${_requestedDeliveryDate!.year}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_requestedDeliveryDate != null)
                    IconButton(
                      onPressed: () {
                        setState(() => _requestedDeliveryDate = null);
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  const Icon(Icons.event_outlined),
                ],
              ),
              onTap: _pickRequestedDelivery,
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Napomena'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Stavke',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Red'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_lines.length, (index) {
              final line = _lines[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _openProductPicker(index),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Proizvod',
                                ),
                                child: Text(
                                  _lineLabel(line),
                                  style: TextStyle(
                                    color: line.product == null
                                        ? Colors.black45
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_lines.length > 1)
                            IconButton(
                              onPressed: () => _removeLine(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: line.qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Količina',
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Obavezno';
                          final n = double.tryParse(t.replaceAll(',', '.'));
                          if (n == null || n <= 0) {
                            return 'Neispravna količina';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Rok stavke'),
                        subtitle: Text(
                          line.dueDate == null
                              ? 'Nije postavljen'
                              : '${line.dueDate!.day.toString().padLeft(2, '0')}.'
                                    '${line.dueDate!.month.toString().padLeft(2, '0')}.'
                                    '${line.dueDate!.year}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (line.dueDate != null)
                              IconButton(
                                onPressed: () {
                                  setState(() => line.dueDate = null);
                                },
                                icon: const Icon(Icons.clear),
                              ),
                            IconButton(
                              onPressed: () => _pickLineDue(index),
                              icon: const Icon(Icons.date_range_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_submitting ? 'Spremanje…' : 'Spremi narudžbu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerPickerSheet extends StatefulWidget {
  final String companyId;
  final OrderType orderType;
  final PartnersLookupService partnersLookup;

  const _PartnerPickerSheet({
    required this.companyId,
    required this.orderType,
    required this.partnersLookup,
  });

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet> {
  final TextEditingController _q = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<PartnerPick> _results = const [];
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = widget.orderType == OrderType.customer
          ? await widget.partnersLookup.searchCustomers(
              companyId: widget.companyId,
              query: query,
            )
          : await widget.partnersLookup.searchSuppliers(
              companyId: widget.companyId,
              query: query,
            );

      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _results = const [];
        _loading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(value);
    });
  }

  @override
  void initState() {
    super.initState();
    _q.addListener(() => _onChanged(_q.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSearch('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: pad.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.orderType == OrderType.customer
                ? 'Odaberi kupca'
                : 'Odaberi dobavljača',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            decoration: const InputDecoration(
              hintText: 'Pretraga po šifri ili nazivu',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            height: 360,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(
                    child: Text(
                      'Nema rezultata. Provjeri da li postoje zapisi u Firestore '
                      '(kolekcije customers / suppliers) za ovu kompaniju.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('Šifra: ${p.code}'),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final String companyId;
  final ProductLookupService productLookup;

  const _ProductPickerSheet({
    required this.companyId,
    required this.productLookup,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _q = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<ProductLookupItem> _results = const [];
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.productLookup.searchProducts(
        companyId: widget.companyId,
        query: trimmed,
        limit: 25,
      );

      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _results = const [];
        _loading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(value);
    });
  }

  @override
  void initState() {
    super.initState();
    _q.addListener(() => _onChanged(_q.text));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: pad.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Odaberi proizvod',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Šifra ili naziv (typeahead)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            height: 360,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _q.text.trim().isEmpty
                ? const Center(
                    child: Text(
                      'Upiši barem jedan znak za pretragu.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : _results.isEmpty
                ? const Center(child: Text('Nema rezultata.'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        title: Text('${p.productCode} — ${p.productName}'),
                        subtitle: Text('Jed: ${p.unit ?? '—'}'),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
