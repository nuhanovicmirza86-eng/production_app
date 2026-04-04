// lib/modules/production/production_orders/screens/production_orders_list_screen.dart

import 'package:flutter/material.dart';

import '../models/production_order_model.dart';
import '../services/production_order_service.dart';

class ProductionOrdersListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionOrdersListScreen({super.key, required this.companyData});

  @override
  State<ProductionOrdersListScreen> createState() =>
      _ProductionOrdersListScreenState();
}

class _ProductionOrdersListScreenState
    extends State<ProductionOrdersListScreen> {
  final ProductionOrderService _productionOrderService =
      ProductionOrderService();

  final List<String> _statuses = const [
    'all',
    'draft',
    'released',
    'in_progress',
    'paused',
    'completed',
    'closed',
    'cancelled',
  ];

  String _selectedStatus = 'all';

  bool _isLoading = true;
  String? _error;

  List<ProductionOrderModel> _orders = const [];

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _productionOrderService.getOrders(
        companyId: _companyId,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Greška pri učitavanju proizvodnih naloga.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadOrders();
  }

  void _onStatusChanged(String? value) {
    if (value == null || value == _selectedStatus) return;

    setState(() {
      _selectedStatus = value;
    });

    _loadOrders();
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'released':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'paused':
        return Colors.deepOrange;
      case 'completed':
        return Colors.green;
      case 'closed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'released':
        return 'Released';
      case 'in_progress':
        return 'In progress';
      case 'paused':
        return 'Paused';
      case 'completed':
        return 'Completed';
      case 'closed':
        return 'Closed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Widget _buildFilterCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Status filter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _statuses
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(
                          status == 'all' ? 'All' : _statusLabel(status),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onStatusChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Došlo je do greške.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nema proizvodnih naloga za odabrani filter.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, ProductionOrderModel order) {
    final statusColor = _statusColor(order.status, context);

    return Card(
      child: InkWell(
        onTap: () {
          // Details screen ide u sljedećem koraku.
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.productionOrderCode,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                order.productName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text('Product code: ${order.productCode}'),
              const SizedBox(height: 4),
              Text(
                'Planned qty: ${_formatQty(order.plannedQty)} ${order.unit}',
              ),
              const SizedBox(height: 4),
              Text(
                'Produced good: ${_formatQty(order.producedGoodQty)} ${order.unit}',
              ),
              const SizedBox(height: 4),
              Text('Plant: ${order.plantKey}'),
              if ((order.customerName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Customer: ${order.customerName}'),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Created: ${_formatDateTime(order.createdAt)}'),
                  Text('Updated: ${_formatDateTime(order.updatedAt)}'),
                  if (order.releasedAt != null)
                    Text('Released: ${_formatDateTime(order.releasedAt)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOrderCard(context, order),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Production Orders')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nedostaje companyId u companyData.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Production Orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilterCard(context),
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create screen ide u sljedećem koraku.
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
