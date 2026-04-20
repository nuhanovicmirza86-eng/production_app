import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../warehouse_hub/services/warehouse_hub_service.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';
import '../wms_scan_helpers.dart';

class _LineCtrls {
  _LineCtrls() {
    itemId = TextEditingController();
    qty = TextEditingController();
    unit = TextEditingController(text: 'pcs');
    lotId = TextEditingController();
    batch = TextEditingController();
    supplierId = TextEditingController();
  }

  late final TextEditingController itemId;
  late final TextEditingController qty;
  late final TextEditingController unit;
  late final TextEditingController lotId;
  late final TextEditingController batch;
  late final TextEditingController supplierId;

  void dispose() {
    itemId.dispose();
    qty.dispose();
    unit.dispose();
    lotId.dispose();
    batch.dispose();
    supplierId.dispose();
  }
}

class WmsReceivingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  const WmsReceivingScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  @override
  State<WmsReceivingScreen> createState() => _WmsReceivingScreenState();
}

class _WmsReceivingScreenState extends State<WmsReceivingScreen> {
  final _svc = WarehouseWmsService();
  final _hub = WarehouseHubService();

  final _notes = TextEditingController();
  final _supplierOrderRef = TextEditingController();

  final List<_LineCtrls> _lines = [_LineCtrls()];

  String? _warehouseId;
  List<({String id, String label})> _warehouses = const [];
  bool _loading = false;
  bool _loadingWh = true;

  static const int _maxLines = 20;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWh = true);
    try {
      final rows = await _hub.listWarehouses(companyId: _cid);
      setState(() {
        _warehouses = rows
            .map((r) => (id: r.id, label: r.name))
            .toList();
        if (_warehouseId == null && _warehouses.isNotEmpty) {
          _warehouseId = _warehouses.first.id;
        }
      });
    } catch (_) {
      setState(() => _warehouses = const []);
    } finally {
      if (mounted) setState(() => _loadingWh = false);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _supplierOrderRef.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    if (_lines.length >= _maxLines) {
      _snack('Maksimalno $_maxLines stavki po prijemu u ovom ekranu.');
      return;
    }
    setState(() => _lines.add(_LineCtrls()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final wid = _warehouseId?.trim();
    if (wid == null || wid.isEmpty) {
      _snack('Odaberi magacin.');
      return;
    }

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final item = l.itemId.text.trim();
      final q = double.tryParse(l.qty.text.trim().replaceAll(',', '.'));
      if (item.isEmpty || q == null || q <= 0) {
        _snack('Stavka ${i + 1}: artikl (ID) i pozitivna količina su obavezni.');
        return;
      }
      out.add(<String, dynamic>{
        'itemId': item,
        'quantity': q,
        'unit': l.unit.text.trim().isEmpty ? 'pcs' : l.unit.text.trim(),
        if (l.lotId.text.trim().isNotEmpty) 'lotId': l.lotId.text.trim(),
        if (l.batch.text.trim().isNotEmpty) 'batchNumber': l.batch.text.trim(),
        if (l.supplierId.text.trim().isNotEmpty)
          'supplierId': l.supplierId.text.trim(),
      });
    }

    setState(() => _loading = true);
    try {
      final res = await _svc.createGoodsReceipt(
        companyId: _cid,
        warehouseId: wid,
        lines: out,
        notes: _notes.text.trim(),
        supplierOrderRef: _supplierOrderRef.text.trim(),
      );
      if (!mounted) return;
      final code = (res['receiptCode'] ?? '').toString();
      _snack(code.isNotEmpty ? 'Prijem $code kreiran.' : 'Prijem kreiran.');
      if (!widget.embedInHubShell && context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Prijem robe',
      body: AbsorbPointer(
        absorbing: _loading || _loadingWh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Više stavki u jednom dokumentu prijema. Sken artikla: etiketa ili ID; '
              'šarža: bilo koji barkod/tekst.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_loadingWh)
              const LinearProgressIndicator()
            else if (_warehouses.isEmpty)
              const Text('Nema magacina — dodaj ih u „Magacin / Hub”.')
            else
              DropdownButtonFormField<String>(
                initialValue: _warehouseId,
                decoration: const InputDecoration(labelText: 'Magacin'),
                items: _warehouses
                    .map(
                      (w) => DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(
                          w.label.isNotEmpty ? '${w.label} (${w.id})' : w.id,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _supplierOrderRef,
              decoration: const InputDecoration(
                labelText: 'Referenca narudžbe dobavljača (opcionalno)',
                hintText: 'PO / narudžbenica',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Napomena'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Stavke (${_lines.length}/$_maxLines)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _lines.length >= _maxLines ? null : _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj stavku'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_lines.length, (index) {
              final l = _lines[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Stavka ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (_lines.length > 1)
                            IconButton(
                              tooltip: 'Ukloni',
                              onPressed: () => _removeLine(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: l.itemId,
                              decoration: const InputDecoration(
                                labelText: 'ID artikla (products)',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Skeniraj',
                            onPressed: () async {
                              final id = await wmsScanProductId(
                                context,
                                companyData: widget.companyData,
                              );
                              if (!mounted || id == null || id.isEmpty) {
                                if (mounted && id == null) {
                                  _snack('Skeniraj ID proizvoda ili JSON etiketu.');
                                }
                                return;
                              }
                              setState(() => l.itemId.text = id);
                            },
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: l.qty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration:
                                  const InputDecoration(labelText: 'Količina'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: l.unit,
                              decoration:
                                  const InputDecoration(labelText: 'Jed.'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: l.lotId,
                              decoration: const InputDecoration(
                                labelText: 'Lot / šarža (opc.)',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Skeniraj šaržu / kod',
                            onPressed: () async {
                              final id = await wmsScanBarcodeRaw(
                                context,
                                companyData: widget.companyData,
                              );
                              if (!mounted || id == null || id.isEmpty) return;
                              setState(() => l.lotId.text = id);
                            },
                            icon: const Icon(Icons.qr_code_2_outlined),
                          ),
                        ],
                      ),
                      TextField(
                        controller: l.batch,
                        decoration: const InputDecoration(
                          labelText: 'Batch (opc.)',
                        ),
                      ),
                      TextField(
                        controller: l.supplierId,
                        decoration: const InputDecoration(
                          labelText: 'Supplier ID (opc.)',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: const Text('Kreiraj prijem'),
            ),
          ],
        ),
      ),
    );
  }
}
