import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../models/order_model.dart';
import '../order_status_ui.dart';
import '../services/orders_service.dart';
import 'order_line_production_create_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final OrderModel order;

  const OrderDetailsScreen({
    super.key,
    required this.companyData,
    required this.order,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrdersService _ordersService = OrdersService();

  late OrderModel _order;
  bool _refreshing = false;
  String? _error;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreatePnFromLine => ProductionAccessHelper.canManage(
        role: _role,
        card: ProductionDashboardCard.productionOrders,
      );

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _load();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _error = 'Nedostaje companyId';
      });
      return;
    }

    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      final fresh = await _ordersService.loadOrderModelWithItems(
        companyId: _companyId,
        orderId: widget.order.id,
      );

      if (!mounted) return;

      setState(() {
        if (fresh != null) {
          _order = fresh;
        }
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _refreshing = false;
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String _formatQty(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  String _typeLabel(OrderType type) {
    switch (type) {
      case OrderType.customer:
        return 'Kupac';
      case OrderType.supplier:
        return 'Dobavljač';
    }
  }

  String? _lineStatusLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = OrderStatusX.fromString(raw);
    return orderStatusLabel(s);
  }

  Widget _buildHeader() {
    final color = orderStatusColor(_order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _order.orderNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (_order.isLate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Kasni rok',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      orderStatusLabel(_order.status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _metaRow('Tip', _typeLabel(_order.orderType)),
          if ((_order.plantKey ?? '').isNotEmpty)
            _metaRow('Pogon', _order.plantKey!),
          if ((_order.currency ?? '').isNotEmpty)
            _metaRow('Valuta', _order.currency!),
        ],
      ),
    );
  }

  Widget _metaRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPartnerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Partner', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_order.partnerName, style: const TextStyle(fontSize: 15)),
          if (_order.partnerCode != null && _order.partnerCode!.isNotEmpty)
            Text(
              'Šifra: ${_order.partnerCode}',
              style: const TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datumi', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _metaRow('Datum narudžbe', _formatDate(_order.orderDate)),
          _metaRow('Tražena isporuka', _formatDate(_order.requestedDeliveryDate)),
          _metaRow('Potvrđena isporuka', _formatDate(_order.confirmedDeliveryDate)),
        ],
      ),
    );
  }

  Widget _buildMetaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sistem', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _metaRow('Kreirano', _formatDate(_order.createdAt)),
          _metaRow('Ažurirano', _formatDate(_order.updatedAt)),
          _metaRow('Ukupno naručeno', _formatQty(_order.totalQty)),
          if ((_order.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Napomena', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_order.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    if (_order.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Text(
          'Nema stavki u order_items (ili još nisu učitane).',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stavke (${_order.items.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._order.items.map((item) {
            final lineLbl = _lineStatusLabel(item.lineStatus);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.productCode} — ${item.productName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Količina: ${_formatQty(item.qty)} ${item.unit}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (item.dueDate != null)
                    Text(
                      'Rok: ${_formatDate(item.dueDate)}',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  if (lineLbl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Status linije: $lineLbl',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  if (item.linkedProductionOrderCodes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'PN: ${item.linkedProductionOrderCodes.join(', ')}',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  if (_order.orderType == OrderType.customer && _canCreatePnFromLine)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.precision_manufacturing, size: 18),
                          label: const Text('Kreiraj PN iz stavke'),
                          onPressed: () async {
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderLineProductionCreateScreen(
                                  companyData: widget.companyData,
                                  order: _order,
                                  item: item,
                                ),
                              ),
                            );
                            if (ok == true && mounted) {
                              await _load();
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Detalji narudžbe'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_refreshing) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ...[
            Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildHeader(),
          const SizedBox(height: 12),
          _buildPartnerCard(),
          const SizedBox(height: 12),
          _buildScheduleCard(),
          const SizedBox(height: 12),
          _buildMetaCard(),
          const SizedBox(height: 12),
          _buildItemsCard(),
        ],
      ),
    );
  }
}
