import 'package:flutter/material.dart';

import '../../../../core/date/date_range_utils.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/date_range_filter_controls.dart';
import '../export/orders_list_pdf_export.dart';
import '../models/order_model.dart';
import '../order_status_ui.dart';
import '../services/orders_service.dart';
import 'order_create_screen.dart';
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

  DateTime? _dateFrom;
  DateTime? _dateTo;

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

      final matchesStatus = _selectedStatus.matches(o);

      final matchesType = _selectedType == OrderTypeFilter.all
          ? true
          : o.orderType == _selectedType.toOrderType();

      final refDate = o.orderDate ?? o.createdAt;
      final matchesDate =
          dateInInclusiveRange(refDate, _dateFrom, _dateTo);

      return matchesSearch && matchesStatus && matchesType && matchesDate;
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

  String _typeLabel(OrderType type) {
    switch (type) {
      case OrderType.customer:
        return 'Kupac';
      case OrderType.supplier:
        return 'Dobavljač';
    }
  }

  bool _isOpen(OrderModel order) {
    switch (order.status) {
      case OrderStatus.fulfilled:
      case OrderStatus.closed:
      case OrderStatus.cancelled:
      case OrderStatus.received:
        return false;
      default:
        return true;
    }
  }

  bool _isLate(OrderModel order) {
    return order.isLate || order.status == OrderStatus.late;
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedStatus != OrderStatusFilter.all) count++;
    if (_selectedType != OrderTypeFilter.all) count++;
    if (_dateFrom != null || _dateTo != null) count++;
    return count;
  }

  String _companyDisplayName() {
    final n = (widget.companyData['companyName'] ??
            widget.companyData['name'] ??
            '')
        .toString()
        .trim();
    return n.isEmpty ? '—' : n;
  }

  String? _filterDescriptionForPdf() {
    final parts = <String>[];
    if (_dateFrom != null || _dateTo != null) {
      parts.add(
        'Datum narudžbe/kreiranja: ${formatCalendarDay(_dateFrom)} – ${formatCalendarDay(_dateTo)}',
      );
    }
    if (_selectedStatus != OrderStatusFilter.all) {
      parts.add('Status: ${_selectedStatus.label}');
    }
    if (_selectedType != OrderTypeFilter.all) {
      parts.add('Tip: ${_selectedType.label}');
    }
    if (parts.isEmpty) return null;
    return parts.join('  |  ');
  }

  Future<void> _pickDateFrom() async {
    final initial = _dateFrom ?? _dateTo ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _dateFrom = d;
      if (_dateTo != null) {
        final a = DateTime(d.year, d.month, d.day);
        final b = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day);
        if (b.isBefore(a)) _dateTo = d;
      }
    });
  }

  Future<void> _pickDateTo() async {
    final initial = _dateTo ?? _dateFrom ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      _dateTo = d;
      if (_dateFrom != null) {
        final a = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        final b = DateTime(d.year, d.month, d.day);
        if (a.isAfter(b)) _dateFrom = d;
      }
    });
  }

  void _clearDateRange() => setState(() {
        _dateFrom = null;
        _dateTo = null;
      });

  Future<void> _exportPdf() async {
    final list = _filteredOrders;
    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema narudžbi za izvoz (filtrirani pregled je prazan).'),
        ),
      );
      return;
    }
    try {
      await OrdersListPdfExport.preview(
        orders: list,
        reportTitle: 'Pregled narudžbi',
        companyLine: _companyDisplayName(),
        filterDescription: _filterDescriptionForPdf(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
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
                    tooltip: 'Export PDF (filtrirani pregled)',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: _isLoading ? null : _exportPdf,
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
                            '• Filtriranje po statusu, tipu i datumu (od–do)\n'
                            '• Export trenutnog pregleda u PDF\n'
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
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderCreateScreen(
                            companyData: widget.companyData,
                          ),
                        ),
                      );
                      if (created == true && mounted) {
                        await _loadOrders();
                      }
                    },
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
              tooltip: 'Export PDF (filtrirani pregled)',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _isLoading ? null : _exportPdf,
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
                      '• Filtriranje po statusu, tipu i datumu (od–do)\n'
                      '• Export trenutnog pregleda u PDF\n'
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
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderCreateScreen(companyData: widget.companyData),
                    ),
                  );
                  if (created == true && mounted) {
                    await _loadOrders();
                  }
                },
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
    final open = _orders.where(_isOpen).length;
    final late = _orders.where(_isLate).length;
    final completed = _orders
        .where(
          (o) =>
              o.status == OrderStatus.fulfilled ||
              o.status == OrderStatus.closed ||
              o.status == OrderStatus.received,
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
                  const SizedBox(height: 16),
                  DateRangeFilterControls(
                    sectionTitle: 'Datum (narudžbe ili kreiranje)',
                    helpText:
                        'Filtar se odnosi na datum narudžbe ako postoji, inače na datum kreiranja zapisa.',
                    from: _dateFrom,
                    to: _dateTo,
                    onPickFrom: _pickDateFrom,
                    onPickTo: _pickDateTo,
                    onClear: _clearDateRange,
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
    final color = orderStatusColor(o.status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              companyData: widget.companyData,
              order: o,
            ),
          ),
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
                          orderStatusLabel(o.status),
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
                        orderStatusLabel(o.status),
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

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrders,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildKpis(),
                      const SizedBox(height: 16),
                      _buildSearch(),
                      const SizedBox(height: 12),
                      _buildFilters(),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (list.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text('Nema narudžbi'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildOrderCard(list[i]),
                      childCount: list.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum OrderStatusFilter {
  all,
  draft,
  confirmed,
  inProduction,
  partial,
  late,
  done,
  cancelled,
}

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
      case OrderStatusFilter.partial:
        return 'Djelomično';
      case OrderStatusFilter.late:
        return 'Kasni';
      case OrderStatusFilter.done:
        return 'Završene';
      case OrderStatusFilter.cancelled:
        return 'Otkazane';
    }
  }

  bool matches(OrderModel o) {
    switch (this) {
      case OrderStatusFilter.all:
        return true;
      case OrderStatusFilter.draft:
        return o.status == OrderStatus.draft;
      case OrderStatusFilter.confirmed:
        return o.status == OrderStatus.confirmed;
      case OrderStatusFilter.inProduction:
        return o.status == OrderStatus.inProduction ||
            (o.orderType == OrderType.supplier && o.status == OrderStatus.open);
      case OrderStatusFilter.partial:
        return o.status == OrderStatus.partiallyFulfilled ||
            o.status == OrderStatus.partiallyReceived;
      case OrderStatusFilter.late:
        return o.status == OrderStatus.late || o.isLate;
      case OrderStatusFilter.done:
        return o.status == OrderStatus.fulfilled ||
            o.status == OrderStatus.received ||
            o.status == OrderStatus.closed;
      case OrderStatusFilter.cancelled:
        return o.status == OrderStatus.cancelled;
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
