import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/order_model.dart';
import '../services/orders_service.dart';
import 'order_details_screen.dart';

class OrdersListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const OrdersListScreen({super.key, required this.companyData});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _isLoading = true;
  String? _errorMessage;
  bool _filtersExpanded = false;

  List<OrderModel> _orders = [];

  final TextEditingController _searchController = TextEditingController();

  OrderStatusFilter _selectedStatus = OrderStatusFilter.all;
  OrderTypeFilter _selectedType = OrderTypeFilter.all;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreateOrder =>
      _role == 'admin' ||
      _role == 'production_manager' ||
      _role == 'sales' ||
      _role == 'purchasing';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadOrders() async {
    if (_companyId.isEmpty) {
      setState(() {
        _errorMessage = 'Nedostaje companyId';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customerOrders = await _ordersService.searchOrders(
        companyId: _companyId,
        orderType: OrderType.customer.value,
      );

      final supplierOrders = await _ordersService.searchOrders(
        companyId: _companyId,
        orderType: OrderType.supplier.value,
      );

      final merged = <OrderModel>[...customerOrders, ...supplierOrders]
        ..sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;

      setState(() {
        _orders = merged;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppErrorMapper.toMessage(e);
        _isLoading = false;
      });
    }
  }

  List<OrderModel> get _filteredOrders {
    final q = _searchController.text.trim().toLowerCase();

    return _orders.where((o) {
      final matchesSearch =
          q.isEmpty ||
          o.orderNumber.toLowerCase().contains(q) ||
          o.partnerName.toLowerCase().contains(q) ||
          ((o.partnerCode ?? '').toLowerCase().contains(q));

      final matchesStatus = _selectedStatus == OrderStatusFilter.all
          ? true
          : o.status == _selectedStatus.toOrderStatus();

      final matchesType = _selectedType == OrderTypeFilter.all
          ? true
          : o.orderType == _selectedType.toOrderType();

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _formatQty(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
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

  String _typeLabel(OrderType type) {
    switch (type) {
      case OrderType.customer:
        return 'Kupac';
      case OrderType.supplier:
        return 'Dobavljač';
    }
  }

  bool _isOpen(OrderStatus status) {
    return status != OrderStatus.fulfilled &&
        status != OrderStatus.closed &&
        status != OrderStatus.cancelled;
  }

  bool _isLate(OrderModel order) {
    return order.status == OrderStatus.inProduction;
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedStatus != OrderStatusFilter.all) count++;
    if (_selectedType != OrderTypeFilter.all) count++;
    return count;
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Narudžbe',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Narudžbe'),
                          content: const Text(
                            'Ovaj ekran služi za upravljanje narudžbama.\n\n'
                            '• Kreiranje i pregled narudžbi\n'
                            '• Praćenje statusa\n'
                            '• Filtriranje po statusu i tipu\n'
                            '• Povezivanje sa proizvodnim nalozima\n\n'
                            'Ovdje pratiš komercijalni tok prije realizacije i proizvodnje.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Zatvori'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (_canCreateOrder) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Nova narudžba'),
                  ),
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Narudžbe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Narudžbe'),
                    content: const Text(
                      'Ovaj ekran služi za upravljanje narudžbama.\n\n'
                      '• Kreiranje i pregled narudžbi\n'
                      '• Praćenje statusa\n'
                      '• Filtriranje po statusu i tipu\n'
                      '• Povezivanje sa proizvodnim nalozima\n\n'
                      'Ovdje pratiš komercijalni tok prije realizacije i proizvodnje.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Zatvori'),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_canCreateOrder)
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Nova narudžba'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final total = _orders.length;
    final open = _orders.where((o) => _isOpen(o.status)).length;
    final late = _orders.where(_isLate).length;
    final completed = _orders
        .where(
          (o) =>
              o.status == OrderStatus.fulfilled ||
              o.status == OrderStatus.closed,
        )
        .length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'Ukupno',
                value: total,
                color: Colors.blue,
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                label: 'Otvorene',
                value: open,
                color: Colors.orange,
                icon: Icons.pending_actions_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'Kasne',
                value: late,
                color: Colors.red,
                icon: Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                label: 'Završene',
                value: completed,
                color: Colors.green,
                icon: Icons.task_alt_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Pretraga po broju, partneru ili šifri partnera',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blue.shade300),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: ChoiceChip(
          label: Text(label, overflow: TextOverflow.ellipsis),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filteri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_activeFiltersCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Aktivni: $_activeFiltersCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  Icon(
                    _filtersExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: OrderStatusFilter.values.map((status) {
                      return chip(
                        label: status.label,
                        selected: _selectedStatus == status,
                        onTap: () => setState(() => _selectedStatus = status),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tip',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: OrderTypeFilter.values.map((type) {
                      return chip(
                        label: type.label,
                        selected: _selectedType == type,
                        onTap: () => setState(() => _selectedType = type),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            alignment: Alignment.topCenter,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel o) {
    final color = _statusColor(o.status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: o)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              blurRadius: 12,
              offset: Offset(0, 4),
              color: Color(0x08000000),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.orderNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(o.status),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        o.orderNumber,
                        style: const TextStyle(
                          fontSize: 15,
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
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(o.status),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              o.partnerName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if ((o.partnerCode ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Šifra partnera: ${o.partnerCode}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaPill(
                  icon: Icons.swap_horiz_rounded,
                  label: _typeLabel(o.orderType),
                ),
                _buildMetaPill(
                  icon: Icons.inventory_2_outlined,
                  label: 'Qty: ${_formatQty(o.totalQty)}',
                ),
                _buildMetaPill(
                  icon: Icons.calendar_today_outlined,
                  label: _formatDate(o.createdAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Expanded(
        child: Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
      );
    }

    final list = _filteredOrders;

    if (list.isEmpty) {
      return const Expanded(child: Center(child: Text('Nema narudžbi')));
    }

    return Expanded(
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => _buildOrderCard(list[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildKpis(),
              const SizedBox(height: 16),
              _buildSearch(),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 12),
              _buildList(),
            ],
          ),
        ),
      ),
    );
  }
}

enum OrderStatusFilter { all, draft, confirmed, inProduction, closed }

extension OrderStatusFilterX on OrderStatusFilter {
  String get label {
    switch (this) {
      case OrderStatusFilter.all:
        return 'Svi';
      case OrderStatusFilter.draft:
        return 'Draft';
      case OrderStatusFilter.confirmed:
        return 'Potvrđena';
      case OrderStatusFilter.inProduction:
        return 'U proizvodnji';
      case OrderStatusFilter.closed:
        return 'Zatvorena';
    }
  }

  OrderStatus? toOrderStatus() {
    switch (this) {
      case OrderStatusFilter.all:
        return null;
      case OrderStatusFilter.draft:
        return OrderStatus.draft;
      case OrderStatusFilter.confirmed:
        return OrderStatus.confirmed;
      case OrderStatusFilter.inProduction:
        return OrderStatus.inProduction;
      case OrderStatusFilter.closed:
        return OrderStatus.closed;
    }
  }
}

enum OrderTypeFilter { all, customer, supplier }

extension OrderTypeFilterX on OrderTypeFilter {
  String get label {
    switch (this) {
      case OrderTypeFilter.all:
        return 'Svi';
      case OrderTypeFilter.customer:
        return 'Kupac';
      case OrderTypeFilter.supplier:
        return 'Dobavljač';
    }
  }

  OrderType? toOrderType() {
    switch (this) {
      case OrderTypeFilter.all:
        return null;
      case OrderTypeFilter.customer:
        return OrderType.customer;
      case OrderTypeFilter.supplier:
        return OrderType.supplier;
    }
  }
}
