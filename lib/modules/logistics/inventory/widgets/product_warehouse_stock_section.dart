import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/product_warehouse_stock_service.dart';

/// Prikaz zalihe proizvoda po magacinima (čita `warehouses` + `inventory_balances`).
class ProductWarehouseStockSection extends StatefulWidget {
  final String companyId;
  final String productId;
  final String? plantKey;
  final String? fallbackUnit;

  const ProductWarehouseStockSection({
    super.key,
    required this.companyId,
    required this.productId,
    this.plantKey,
    this.fallbackUnit,
  });

  @override
  State<ProductWarehouseStockSection> createState() =>
      _ProductWarehouseStockSectionState();
}

class _ProductWarehouseStockSectionState
    extends State<ProductWarehouseStockSection> {
  final ProductWarehouseStockService _service = ProductWarehouseStockService();

  bool _loading = false;
  String? _error;
  List<ProductWarehouseStockLine> _lines = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductWarehouseStockSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.productId != widget.productId ||
        oldWidget.plantKey != widget.plantKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final cid = widget.companyId.trim();
    final pid = widget.productId.trim();
    if (cid.isEmpty || pid.isEmpty) {
      setState(() {
        _lines = const [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final lines = await _service.loadStockLinesForProduct(
        companyId: cid,
        productId: pid,
        plantKey: widget.plantKey,
      );
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  static String _formatQty(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final cid = widget.companyId.trim();
    final pid = widget.productId.trim();
    if (cid.isEmpty || pid.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Zaliha po magacinima',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Osvježi',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ],
            if (!_loading && _error == null && _lines.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nema aktivnih magacina za ovu kompaniju'
                '${(widget.plantKey ?? '').trim().isNotEmpty ? ' (filtar: pogon)' : ''}.',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._lines.map((line) {
                final unit = (line.unit ?? widget.fallbackUnit ?? '').trim();
                final unitSuffix = unit.isEmpty ? '' : ' $unit';
                final plant = (line.warehousePlantKey ?? '').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${line.warehouseCode} — ${line.warehouseName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (plant.isNotEmpty)
                              Text(
                                'Pogon: $plant',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${_formatQty(line.quantityOnHand)}$unitSuffix',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              Builder(
                builder: (context) {
                  final total = _lines.fold<double>(
                    0,
                    (a, b) => a + b.quantityOnHand,
                  );
                  String? firstUnit;
                  for (final line in _lines) {
                    final u = (line.unit ?? '').trim();
                    if (u.isNotEmpty) {
                      firstUnit = u;
                      break;
                    }
                  }
                  final u =
                      firstUnit ?? (widget.fallbackUnit ?? '').trim();
                  final unitSuffix = u.isEmpty ? '' : ' $u';
                  return Text(
                    'Ukupno: ${_formatQty(total)}$unitSuffix',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
