import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
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
  final _itemId = TextEditingController();

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
    _itemId.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWh = true);
    try {
      final rows = await _hub.listWarehouses(companyId: _cid);
      setState(() {
        _warehouses = rows.map((r) => (id: r.id, label: r.name)).toList();
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

  Future<void> _fetch() async {
    final wid = _warehouseId?.trim();
    final item = _itemId.text.trim();
    if (wid == null || wid.isEmpty || item.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magacin i ID artikla su obavezni.')),
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
              value: _warehouseId,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _itemId,
                  decoration: const InputDecoration(
                    labelText: 'ID artikla',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Skeniraj',
                onPressed: _busy
                    ? null
                    : () async {
                        final id = await wmsScanProductId(
                          context,
                          companyData: widget.companyData,
                        );
                        if (!mounted || id == null || id.isEmpty) return;
                        setState(() => _itemId.text = id);
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
            Text(
              (_result!['message'] ?? '').toString().trim().isEmpty
                  ? 'Dostupni lotovi (APPROVED_STOCK / PICKING_STAGING):'
                  : _result!['message'].toString(),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ...fifo.map((row) {
              final m = Map<String, dynamic>.from(row as Map);
              final docId = (m['lotDocId'] ?? '').toString();
              final lot = (m['lotId'] ?? '').toString();
              final qty = (m['availableQty'] ?? '').toString();
              final loc = (m['locationSummary'] ?? '').toString();
              return Card(
                child: ListTile(
                  title: Text('$lot · dostupno $qty'),
                  subtitle: Text(
                    '$docId\n$loc',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
