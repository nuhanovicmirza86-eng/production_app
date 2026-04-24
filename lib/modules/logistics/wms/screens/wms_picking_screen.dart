import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../production/products/services/product_lookup_service.dart';
import '../../warehouse_hub/services/warehouse_hub_service.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';
import '../wms_scan_helpers.dart';

class WmsPickingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  const WmsPickingScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  @override
  State<WmsPickingScreen> createState() => _WmsPickingScreenState();
}

class _WmsPickingScreenState extends State<WmsPickingScreen> {
  final _svc = WarehouseWmsService();
  final _hub = WarehouseHubService();
  final _artiklCaption = TextEditingController();

  String? _productIdInternal;
  String? _warehouseId;
  List<({String id, String label})> _warehouses = const [];
  bool _loadingWh = true;
  bool _busy = false;
  Map<String, dynamic>? _result;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _artiklCaption.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWh = true);
    try {
      final rows = await _hub.listWarehouses(companyId: _cid);
      setState(() {
        _warehouses = rows.map((r) {
          final name = r.name.trim();
          final code = r.code.trim();
          final label = name.isNotEmpty
              ? name
              : (code.isNotEmpty ? code : 'Magacin');
          return (id: r.id, label: label);
        }).toList();
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

  void _applyProduct(ProductLookupItem item) {
    _productIdInternal = item.productId;
    _artiklCaption.text = '${item.productCode} — ${item.productName}';
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductLookupItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WmsPickingProductSheet(companyId: _cid),
    );
    if (!mounted || picked == null) return;
    setState(() => _applyProduct(picked));
  }

  Future<void> _fetch() async {
    final wid = _warehouseId?.trim();
    final item = _productIdInternal?.trim();
    if (wid == null || wid.isEmpty || item == null || item.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi magacin i artikl.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final r = await _svc.getFifoLotsForItem(
        companyId: _cid,
        warehouseId: wid,
        itemId: item,
      );
      if (!mounted) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fifo = _result == null
        ? <dynamic>[]
        : (_result!['fifoOrderedLots'] as List<dynamic>?) ?? const [];

    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'FIFO picking',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadingWh)
            const LinearProgressIndicator()
          else if (_warehouses.isEmpty)
            const Text('Nema magacina.')
          else
            DropdownButtonFormField<String>(
              initialValue: _warehouseId,
              decoration: const InputDecoration(labelText: 'Magacin'),
              items: _warehouses
                  .map(
                    (w) => DropdownMenuItem<String>(
                      value: w.id,
                      child: Text(w.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _warehouseId = v),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _artiklCaption,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Artikl',
                    hintText: 'Odaberi ili skeniraj',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Odaberi',
                onPressed: _busy ? null : _pickProduct,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Skeniraj',
                onPressed: _busy
                    ? null
                    : () async {
                        final item = await wmsScanResolvedProduct(
                          context,
                          companyData: widget.companyData,
                        );
                        if (!mounted) return;
                        if (item == null) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Artikl nije prepoznat.'),
                            ),
                          );
                          return;
                        }
                        setState(() => _applyProduct(item));
                      },
                icon: const Icon(Icons.qr_code_scanner_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _fetch,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Dohvati FIFO redoslijed'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            if ((_result!['message'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _result!['message'].toString(),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ...fifo.map((row) {
              final m = Map<String, dynamic>.from(row as Map);
              final lot = (m['lotId'] ?? '').toString();
              final qty = (m['availableQty'] ?? '').toString();
              final loc = (m['locationSummary'] ?? '').toString();
              return Card(
                child: ListTile(
                  title: Text(
                    lot.isNotEmpty ? 'Lot $lot' : 'Lot',
                  ),
                  subtitle: Text(
                    [
                      if (qty.isNotEmpty) 'Dostupno: $qty',
                      if (loc.isNotEmpty) loc,
                    ].join('\n'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: loc.isNotEmpty && qty.isNotEmpty,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Isti UX kao donja lista u prijemu — lokalna kopija da ne izvozimo privatni sheet.
class _WmsPickingProductSheet extends StatefulWidget {
  const _WmsPickingProductSheet({required this.companyId});

  final String companyId;

  @override
  State<_WmsPickingProductSheet> createState() =>
      _WmsPickingProductSheetState();
}

class _WmsPickingProductSheetState extends State<_WmsPickingProductSheet> {
  final _q = TextEditingController();
  final _lookup = ProductLookupService();
  List<ProductLookupItem> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _lookup.searchProducts(
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
          const Text(
            'Odaberi artikl',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Šifra ili naziv',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          SizedBox(
            height: 320,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, unused) => const Divider(height: 1),
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
