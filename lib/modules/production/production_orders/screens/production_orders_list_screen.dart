import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/access/production_access_helper.dart';
import '../models/production_order_model.dart';
import '../services/production_order_service.dart';
import 'production_order_create_screen.dart';
import 'production_order_details_screen.dart';

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
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreateOrder => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.productionOrders,
  );

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    if (_companyId.isEmpty) {
      setState(() {
        _error = 'Nedostaje companyId u companyData.';
        _isLoading = false;
      });
      return;
    }

    if (_plantKey.isEmpty) {
      setState(() {
        _error = 'Nedostaje plantKey u companyData.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _productionOrderService.getOrders(
        companyId: _companyId,
        plantKey: _plantKey,
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
        _error = AppErrorMapper.toMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadOrders();
  }

  Future<void> _openCreateScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductionOrderCreateScreen(companyData: widget.companyData),
      ),
    );

    if (created == true) {
      await _loadOrders();
    }
  }

  Future<void> _openDetailsScreen(ProductionOrderModel order) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionOrderDetailsScreen(
          companyData: widget.companyData,
          productionOrderId: order.id,
        ),
      ),
    );

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
        return 'Nacrt';
      case 'released':
        return 'Pušten';
      case 'in_progress':
        return 'U toku';
      case 'paused':
        return 'Pauziran';
      case 'completed':
        return 'Završen';
      case 'closed':
        return 'Zatvoren';
      case 'cancelled':
        return 'Otkazan';
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
                'Filter statusa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _statuses
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(
                          status == 'all' ? 'Svi' : _statusLabel(status),
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
        onTap: () => _openDetailsScreen(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QrImageView(data: order.productionOrderCode, size: 72),
              const SizedBox(width: 16),
              Expanded(
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
                            color: statusColor.withOpacity(0.12),
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
                    Text('Šifra: ${order.productCode}'),
                    const SizedBox(height: 4),
                    Text(
                      'Planirano: ${_formatQty(order.plannedQty)} ${order.unit}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Proizvedeno: ${_formatQty(order.producedGoodQty)} ${order.unit}',
                    ),
                    const SizedBox(height: 4),
                    Text('Pogon: ${order.plantKey}'),
                    if ((order.customerName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Kupac: ${order.customerName}'),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text('Kreirano: ${_formatDateTime(order.createdAt)}'),
                        Text('Ažurirano: ${_formatDateTime(order.updatedAt)}'),
                        if (order.releasedAt != null)
                          Text('Pušten: ${_formatDateTime(order.releasedAt)}'),
                      ],
                    ),
                  ],
                ),
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
        appBar: AppBar(title: const Text('Proizvodni nalozi')),
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

    if (_plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proizvodni nalozi')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nedostaje plantKey u companyData.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Proizvodni nalozi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilterCard(context),
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
      floatingActionButton: _canCreateOrder
          ? FloatingActionButton(
              onPressed: _openCreateScreen,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
