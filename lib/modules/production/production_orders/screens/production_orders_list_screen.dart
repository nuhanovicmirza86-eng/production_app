import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/standard_list_components.dart';
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

class _ProductionOrdersListScreenState extends State<ProductionOrdersListScreen> {
  final ProductionOrderService _service = ProductionOrderService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  bool _filtersExpanded = false;
  ProductionOrderStatusFilter _selectedStatus = ProductionOrderStatusFilter.all;
  List<ProductionOrderModel> _orders = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreateOrder => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.productionOrders,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = _companyId.isEmpty
            ? 'Nedostaje companyId u companyData.'
            : 'Nedostaje plantKey u companyData.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _service.getOrders(companyId: _companyId, plantKey: _plantKey);
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

  Future<void> _openCreateScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionOrderCreateScreen(companyData: widget.companyData),
      ),
    );
    if (created == true && mounted) {
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
    if (mounted) await _loadOrders();
  }

  List<ProductionOrderModel> get _filteredOrders {
    final q = _searchController.text.trim().toLowerCase();
    return _orders.where((o) {
      final matchesSearch = q.isEmpty ||
          o.productionOrderCode.toLowerCase().contains(q) ||
          o.productCode.toLowerCase().contains(q) ||
          o.productName.toLowerCase().contains(q) ||
          (o.customerName ?? '').toLowerCase().contains(q);
      final matchesStatus = _selectedStatus.matches(o.status);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get _activeFiltersCount => _selectedStatus == ProductionOrderStatusFilter.all ? 0 : 1;

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _formatQty(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  Color _statusColor(String status) {
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
        return Colors.black54;
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

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;

        void infoAction() {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Proizvodni nalozi'),
              content: const Text(
                'Ovaj ekran služi za upravljanje proizvodnim nalozima.\n\n'
                '• Pregled i pretraga naloga\n'
                '• KPI praćenje statusa izvršenja\n'
                '• Filtriranje po statusu\n'
                '• Ulaz u detalje naloga i izvršenje\n\n'
                'Ovdje pratiš operativni tok proizvodnje od planiranog do završenog naloga.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zatvori'),
                ),
              ],
            ),
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StandardScreenHeader(
                title: 'Proizvodni nalozi',
                onBack: () => Navigator.of(context).pop(),
                onInfo: infoAction,
              ),
              if (_canCreateOrder) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openCreateScreen,
                    icon: const Icon(Icons.add),
                    label: const Text('Novi nalog'),
                  ),
                ),
              ],
            ],
          );
        }

        return StandardScreenHeader(
          title: 'Proizvodni nalozi',
          onBack: () => Navigator.of(context).pop(),
          onInfo: infoAction,
          action: _canCreateOrder
              ? ElevatedButton.icon(
                  onPressed: _openCreateScreen,
                  icon: const Icon(Icons.add),
                  label: const Text('Novi nalog'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildKpis() {
    final total = _orders.length;
    final open = _orders
        .where((o) => !['completed', 'closed', 'cancelled'].contains(o.status))
        .length;
    final inProgress = _orders.where((o) => o.status == 'in_progress').length;
    final done = _orders.where((o) => o.status == 'completed' || o.status == 'closed').length;

    return StandardKpiGrid(
      metrics: [
        KpiMetric(
          label: 'Ukupno',
          value: total,
          color: Colors.blue,
          icon: Icons.assignment_outlined,
        ),
        KpiMetric(
          label: 'Otvoreni',
          value: open,
          color: Colors.orange,
          icon: Icons.pending_actions_outlined,
        ),
        KpiMetric(
          label: 'U toku',
          value: inProgress,
          color: Colors.deepOrange,
          icon: Icons.play_circle_outline,
        ),
        KpiMetric(
          label: 'Završeni',
          value: done,
          color: Colors.green,
          icon: Icons.task_alt_rounded,
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return StandardSearchField(
      controller: _searchController,
      hintText: 'Pretraga po kodu naloga, proizvodu ili kupcu',
      onChanged: (_) => setState(() {}),
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

    return StandardFilterPanel(
      expanded: _filtersExpanded,
      activeCount: _activeFiltersCount,
      onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            children: ProductionOrderStatusFilter.values.map((status) {
              return chip(
                label: status.label,
                selected: _selectedStatus == status,
                onTap: () => setState(() => _selectedStatus = status),
              );
            }).toList(),
          ),
        ],
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(ProductionOrderModel o) {
    final color = _statusColor(o.status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetailsScreen(o),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.productionOrderCode,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(o.status),
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(o.productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Šifra proizvoda: ${o.productCode}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaPill(
                  icon: Icons.inventory_2_outlined,
                  label: 'Plan: ${_formatQty(o.plannedQty)} ${o.unit}',
                ),
                _buildMetaPill(
                  icon: Icons.task_alt_outlined,
                  label: 'Good: ${_formatQty(o.producedGoodQty)} ${o.unit}',
                ),
                _buildMetaPill(icon: Icons.factory_outlined, label: 'Pogon: ${o.plantKey}'),
                _buildMetaPill(icon: Icons.calendar_today_outlined, label: _formatDate(o.createdAt)),
              ],
            ),
          ],
        ),
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
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: Text(_error!, textAlign: TextAlign.center)),
                  ),
                )
              else if (list.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text('Nema proizvodnih naloga'),
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

enum ProductionOrderStatusFilter {
  all,
  draft,
  released,
  inProgress,
  paused,
  completed,
  closed,
  cancelled,
}

extension ProductionOrderStatusFilterX on ProductionOrderStatusFilter {
  String get label {
    switch (this) {
      case ProductionOrderStatusFilter.all:
        return 'Svi';
      case ProductionOrderStatusFilter.draft:
        return 'Nacrt';
      case ProductionOrderStatusFilter.released:
        return 'Pušten';
      case ProductionOrderStatusFilter.inProgress:
        return 'U toku';
      case ProductionOrderStatusFilter.paused:
        return 'Pauziran';
      case ProductionOrderStatusFilter.completed:
        return 'Završen';
      case ProductionOrderStatusFilter.closed:
        return 'Zatvoren';
      case ProductionOrderStatusFilter.cancelled:
        return 'Otkazan';
    }
  }

  bool matches(String status) {
    switch (this) {
      case ProductionOrderStatusFilter.all:
        return true;
      case ProductionOrderStatusFilter.draft:
        return status == 'draft';
      case ProductionOrderStatusFilter.released:
        return status == 'released';
      case ProductionOrderStatusFilter.inProgress:
        return status == 'in_progress';
      case ProductionOrderStatusFilter.paused:
        return status == 'paused';
      case ProductionOrderStatusFilter.completed:
        return status == 'completed';
      case ProductionOrderStatusFilter.closed:
        return status == 'closed';
      case ProductionOrderStatusFilter.cancelled:
        return status == 'cancelled';
    }
  }
}
