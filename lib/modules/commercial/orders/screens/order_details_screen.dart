import 'package:flutter/material.dart';

import '../models/order_model.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _formatQty(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return 'Draft';
      case OrderStatus.confirmed:
        return 'Potvrđena';
      case OrderStatus.inProduction:
        return 'U proizvodnji';
      case OrderStatus.fulfilled:
        return 'Realizovana';
      case OrderStatus.cancelled:
        return 'Otkazana';
      case OrderStatus.closed:
        return 'Zatvorena';
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return Colors.grey;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.inProduction:
        return Colors.orange;
      case OrderStatus.fulfilled:
      case OrderStatus.closed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  Widget _buildHeader() {
    final color = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            order.orderNumber,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(order.status),
              style: TextStyle(color: color),
            ),
          ),
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
          Text(order.partnerName),
          if (order.partnerCode != null && order.partnerCode!.isNotEmpty)
            Text('Šifra: ${order.partnerCode}'),
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
          const Text('Meta', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Kreirano: ${_formatDate(order.createdAt)}'),
          Text('Ažurirano: ${_formatDate(order.updatedAt)}'),
          Text('Količina: ${_formatQty(order.totalQty)}'),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    if (order.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Text('Nema stavki'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stavke', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...order.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${item.productCode} - ${item.productName}'),
                  ),
                  Text('${_formatQty(item.qty)} ${item.unit}'),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Detalji narudžbe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildPartnerCard(),
            const SizedBox(height: 12),
            _buildMetaCard(),
            const SizedBox(height: 12),
            _buildItemsCard(),
          ],
        ),
      ),
    );
  }
}
