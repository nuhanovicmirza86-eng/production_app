import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/date/date_range_utils.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/date_range_filter_controls.dart';
import '../../../../core/ui/standard_list_components.dart';
import '../../../logistics/inventory/services/product_warehouse_stock_service.dart';
import '../export/orders_list_pdf_export.dart';
import '../models/order_model.dart';
import '../order_status_ui.dart';
import '../services/orders_service.dart';
import '../../assessment/screens/unified_assessment_run_screen.dart';
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
  final ProductWarehouseStockService _stockService =
      ProductWarehouseStockService();

  bool _isLoading = true;
  String? _errorMessage;
  bool _searchStripExpanded = false;

  List<OrderModel> _orders = [];
  final Map<String, double> _stockByProductId = {};
  bool _stockLoading = false;
  Timer? _stockDebounce;

  final TextEditingController _searchController = TextEditingController();

  OrderStatusFilter _selectedStatus = OrderStatusFilter.all;
  OrderTypeFilter _selectedType = OrderTypeFilter.all;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  bool get _canCreateOrder =>
      _role == 'admin' ||
      _role == 'production_manager' ||
      _role == 'sales' ||
      _role == 'purchasing' ||
      _role == 'logistics_manager';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadOrders();
  }

  @override
  void dispose() {
    _stockDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleStockRefresh();
  }

  void _scheduleStockRefresh() {
    _stockDebounce?.cancel();
    _stockDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _refreshStockForFiltered();
    });
  }

  Future<void> _refreshStockForFiltered() async {
    final ids = <String>{};
    for (final o in _filteredOrders) {
      for (final it in o.items) {
        final pid = it.productId.trim();
        if (pid.isNotEmpty) ids.add(pid);
      }
    }
    if (ids.isEmpty) {
      if (mounted) setState(() => _stockByProductId.clear());
      return;
    }

    setState(() => _stockLoading = true);

    final next = <String, double>{};
    const batch = 8;
    final list = ids.toList();
    for (var i = 0; i < list.length; i += batch) {
      final end = i + batch > list.length ? list.length : i + batch;
      final chunk = list.sublist(i, end);
      await Future.wait(
        chunk.map((pid) async {
          try {
            final lines = await _stockService.loadStockLinesForProduct(
              companyId: _companyId,
              productId: pid,
              plantKey: _plantKey.isEmpty ? null : _plantKey,
            );
            final sum = lines.fold<double>(0, (a, b) => a + b.quantityOnHand);
            next[pid] = sum;
          } catch (_) {
            next[pid] = 0;
          }
        }),
      );
    }

    if (!mounted) return;
    setState(() {
      _stockByProductId
        ..clear()
        ..addAll(next);
      _stockLoading = false;
    });
  }

  Future<void> _loadOrders() async {
    if (_companyId.isEmpty) {
      setState(() {
        _errorMessage = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
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

      final itemsByOrder = await _ordersService.loadOrderItemsGroupedByOrderId(
        companyId: _companyId,
      );

      final withItems = merged.map((o) {
        final fromCol = itemsByOrder[o.id];
        if (fromCol != null && fromCol.isNotEmpty) {
          return o.copyWith(items: fromCol);
        }
        return o;
      }).toList();

      if (!mounted) return;

      setState(() {
        _orders = withItems;
        _isLoading = false;
      });
      _scheduleStockRefresh();
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
          ((o.partnerCode ?? '').toLowerCase().contains(q)) ||
          o.items.any(
            (it) =>
                it.productCode.toLowerCase().contains(q) ||
                it.productName.toLowerCase().contains(q),
          );

      final matchesStatus = _selectedStatus.matches(o);

      final matchesType = _selectedType == OrderTypeFilter.all
          ? true
          : o.orderType == _selectedType.toOrderType();

      final refDate = o.orderDate ?? o.createdAt;
      final matchesDate = dateInInclusiveRange(refDate, _dateFrom, _dateTo);

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

  int get _searchStripActiveCount =>
      _activeFiltersCount + (_searchController.text.trim().isNotEmpty ? 1 : 0);

  String _companyDisplayName() {
    final n =
        (widget.companyData['companyName'] ?? widget.companyData['name'] ?? '')
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
    _scheduleStockRefresh();
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
    _scheduleStockRefresh();
  }

  void _clearDateRange() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _scheduleStockRefresh();
  }

  Future<void> _exportPdf() async {
    final list = _filteredOrders;
    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nema narudžbi za izvoz (filtrirani pregled je prazan).',
          ),
        ),
      );
      return;
    }
    try {
      await _refreshStockForFiltered();
      if (!mounted) return;
      await OrdersListPdfExport.preview(
        orders: list,
        reportTitle: 'Pregled narudžbi (detaljno)',
        companyLine: _companyDisplayName(),
        filterDescription: _filterDescriptionForPdf(),
        stockByProductId: _stockByProductId.isEmpty
            ? null
            : Map<String, double>.from(_stockByProductId),
        companyId: _companyId,
        companyData: widget.companyData,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactListBreakpoint;

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
                    tooltip:
                        'Export PDF — detaljno po stavkama (zalihe ako su učitane)',
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
                            '• Tabularni pregled po partneru (stavke, zalihe, zeleno = spremno)\n'
                            '• Široki ekran: tablica; uski ekran: kartice. ⋮ ili tap na karticu — detalji / procjena\n'
                            '• Export u PDF (isti raspored; zalihe ako su učitane)\n'
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
              tooltip:
                  'Export PDF — detaljno po stavkama (zalihe ako su učitane)',
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
                      '• Tabularni pregled po partneru (stavke, zalihe, zeleno = spremno)\n'
                      '• Export u PDF (isti raspored; zalihe ako su učitane)\n'
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

  Widget _buildKpis() {
    final total = _orders
        .where((o) => o.status != OrderStatus.cancelled)
        .length;
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

    return StandardKpiGrid(
      metrics: [
        KpiMetric(
          label: 'Ukupno',
          value: total,
          color: Colors.blue,
          icon: Icons.receipt_long_outlined,
        ),
        KpiMetric(
          label: 'Otvorene',
          value: open,
          color: Colors.orange,
          icon: Icons.pending_actions_outlined,
        ),
        KpiMetric(
          label: 'Kasne',
          value: late,
          color: Colors.red,
          icon: Icons.warning_amber_rounded,
        ),
        KpiMetric(
          label: 'Završene',
          value: completed,
          color: Colors.green,
          icon: Icons.task_alt_rounded,
        ),
      ],
    );
  }

  Widget _buildSearch({bool compact = false}) {
    return StandardSearchField(
      controller: _searchController,
      hintText:
          'Broj narudžbe, partner, šifra partnera, šifra/naziv proizvoda…',
      compact: compact,
    );
  }

  Widget _buildStatusTypeDateFilters() {
    final cs = Theme.of(context).colorScheme;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          children: OrderStatusFilter.values.map((status) {
            return chip(
              label: status.label,
              selected: _selectedStatus == status,
              onTap: () {
                setState(() => _selectedStatus = status);
                _scheduleStockRefresh();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Tip',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          children: OrderTypeFilter.values.map((type) {
            return chip(
              label: type.label,
              selected: _selectedType == type,
              onTap: () {
                setState(() => _selectedType = type);
                _scheduleStockRefresh();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
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
    );
  }

  Widget _buildSearchAndFiltersStrip() {
    return StandardFilterPanel(
      title: 'Pretraga i filteri',
      expanded: _searchStripExpanded,
      activeCount: _searchStripActiveCount,
      onToggle: () =>
          setState(() => _searchStripExpanded = !_searchStripExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearch(compact: true),
          const SizedBox(height: 10),
          _buildStatusTypeDateFilters(),
        ],
      ),
    );
  }

  /// Širina kolone „Broj nar.“ — dovoljno za `SO-2026-000002` u jednom redu.
  static const double _colOrderNumber = 132;

  /// Status (npr. „U proizvodnji”, „Djelomično isporučeno”) u jednom redu.
  static const double _colStatus = 168;

  /// Meni po redu (detalji / procjena) — ne širi red tapom na cijelu širinu.
  static const double _colActions = 44;

  /// Isto kao kompaktno zaglavlje — ispod ove širine: kartice umjesto široke tabele.
  static const double _compactListBreakpoint = 700;

  static const double _orderTableWidth =
      1180 - 92 + _colOrderNumber - 76 + _colStatus + _colActions;

  DateTime _deadlineSortKey(OrderModel o, OrderItemModel? it) {
    final lineDue = it?.dueDate;
    if (lineDue != null) return lineDue;
    return o.requestedDeliveryDate ??
        o.orderDate ??
        o.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Najraniji rok među stavkama (za sort kartičnog prikaza).
  DateTime _orderCompactSortKey(OrderModel o) {
    if (o.items.isEmpty) return _deadlineSortKey(o, null);
    var best = _deadlineSortKey(o, o.items.first);
    for (var i = 1; i < o.items.length; i++) {
      final k = _deadlineSortKey(o, o.items[i]);
      if (k.isBefore(best)) best = k;
    }
    return best;
  }

  String? _partnerRef(OrderModel o) {
    switch (o.orderType) {
      case OrderType.customer:
        final r = o.customerReference?.trim();
        return (r == null || r.isEmpty) ? null : r;
      case OrderType.supplier:
        final r = o.supplierReference?.trim();
        return (r == null || r.isEmpty) ? null : r;
    }
  }

  double _remainingQty(OrderModel o, OrderItemModel? it) {
    if (it == null) return 0;
    if (it.openQty > 0) return it.openQty;
    if (o.orderType == OrderType.customer) {
      final v = it.qty - it.deliveredQty;
      return v > 0 ? v : 0;
    }
    final v = it.qty - it.receivedQty;
    return v > 0 ? v : 0;
  }

  double _fulfilledQty(OrderModel o, OrderItemModel? it) {
    if (it == null) return 0;
    return o.orderType == OrderType.customer ? it.deliveredQty : it.receivedQty;
  }

  bool _rowReady(OrderModel o, OrderItemModel? it) {
    if (it == null) return false;
    if (o.status == OrderStatus.cancelled) return false;
    final rem = _remainingQty(o, it);
    if (rem <= 0) return false;
    final pid = it.productId.trim();
    if (pid.isEmpty) return false;
    final stock = _stockByProductId[pid] ?? 0;
    return stock + 1e-9 >= rem;
  }

  List<({OrderModel o, OrderItemModel? it})> _sortedLinesForOrders(
    List<OrderModel> orders,
  ) {
    final lines = <({OrderModel o, OrderItemModel? it})>[];
    for (final o in orders) {
      if (o.items.isEmpty) {
        lines.add((o: o, it: null));
      } else {
        for (final it in o.items) {
          lines.add((o: o, it: it));
        }
      }
    }
    lines.sort((a, b) {
      final c = _deadlineSortKey(
        a.o,
        a.it,
      ).compareTo(_deadlineSortKey(b.o, b.it));
      if (c != 0) return c;
      final n = a.o.orderNumber.compareTo(b.o.orderNumber);
      if (n != 0) return n;
      return (a.it?.productCode ?? '').compareTo(b.it?.productCode ?? '');
    });
    return lines;
  }

  Future<void> _openOrder(OrderModel o) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderDetailsScreen(companyData: widget.companyData, order: o),
      ),
    );
    if (mounted) await _loadOrders();
  }

  Future<void> _openOrderUnifiedAssessment(OrderModel o) async {
    final pkOrder = (o.plantKey ?? '').toString().trim();
    final pkCompany = _plantKey;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedAssessmentRunScreen(
          companyId: _companyId,
          plantKey: pkOrder.isNotEmpty ? pkOrder : pkCompany,
          entityType: 'production_order',
          entityId: o.id,
          entityLabel: '${o.orderNumber} • ${o.partnerName}'.trim(),
          userRole: _role,
        ),
      ),
    );
  }

  Widget _orderTableHeaderRow() {
    final cs = Theme.of(context).colorScheme;
    final headerStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    Widget th(String text, double w) {
      return SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(text, style: headerStyle),
        ),
      );
    }

    Widget thExp(String text) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(text, style: headerStyle),
        ),
      );
    }

    return Container(
      width: _orderTableWidth,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          th('Broj nar.', _colOrderNumber),
          th('Datum nar.', 82),
          th('Ref.', 84),
          th('Rok isporuke', 88),
          th('Tip', 52),
          th('Status', _colStatus),
          th('Šifra', 84),
          thExp('Naziv'),
          th('MJ', 44),
          th('Naručeno', 52),
          th('Isp./Prim.', 52),
          th('Ostalo', 52),
          th('Stanje', 52),
          SizedBox(
            width: _colActions,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Icon(Icons.more_vert, size: 16, color: headerStyle.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderDataRow(OrderModel o, OrderItemModel? it) {
    final cs = Theme.of(context).colorScheme;
    final ready = _rowReady(o, it);
    final bg = ready
        ? Color.alphaBlend(
            const Color(0xFFC8E6C9).withValues(alpha: 0.85),
            cs.surface,
          )
        : cs.surface;
    final border = Border.all(color: cs.outlineVariant, width: 1);
    final cellTextStyle = TextStyle(fontSize: 11, color: cs.onSurface);

    Widget td(
      String text,
      double w, {
      bool right = false,
      int maxLines = 3,
      bool softWrap = true,
    }) {
      return Container(
        width: w,
        decoration: BoxDecoration(color: bg, border: border),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          text,
          style: cellTextStyle,
          maxLines: maxLines,
          softWrap: softWrap,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    Widget tdExp(String text) {
      return Expanded(
        child: Container(
          decoration: BoxDecoration(color: bg, border: border),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            text,
            style: cellTextStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final ref = _partnerRef(o);
    final rok = _formatDate(
      it?.dueDate ?? o.requestedDeliveryDate ?? o.confirmedDeliveryDate,
    );
    final pid = (it?.productId ?? '').trim();
    final stock = pid.isEmpty ? null : (_stockByProductId[pid]);

    final nar = it == null ? '—' : _formatQty(it.qty);
    final isp = it == null ? '—' : _formatQty(_fulfilledQty(o, it));
    final ost = it == null ? '—' : _formatQty(_remainingQty(o, it));
    final stText = stock == null ? '—' : _formatQty(stock);

    Widget rowMenu() {
      return Container(
        width: _colActions,
        decoration: BoxDecoration(color: bg, border: border),
        alignment: Alignment.center,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(Icons.more_vert, size: 20, color: cs.onSurface),
          onSelected: (v) {
            if (v == 'det') _openOrder(o);
            if (v == 'asm') _openOrderUnifiedAssessment(o);
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'det', child: Text('Detalji narudžbe')),
            PopupMenuItem(value: 'asm', child: Text('Procjena (šablon)')),
          ],
        ),
      );
    }

    final innerW = _orderTableWidth - _colActions;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: _orderTableWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: innerW,
              child: InkWell(
                onTap: () => _openOrder(o),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    td(
                      o.orderNumber,
                      _colOrderNumber,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    td(_formatDate(o.orderDate ?? o.createdAt), 82),
                    td(ref ?? '—', 84),
                    td(rok, 88),
                    td(_typeLabel(o.orderType), 52),
                    td(
                      orderStatusLabel(o.status),
                      _colStatus,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    td(it?.productCode ?? '—', 84),
                    tdExp(it?.productName ?? 'Nema učitanih stavki'),
                    td(() {
                      final u = (it?.unit ?? '').trim();
                      return u.isEmpty ? '—' : u;
                    }(), 44),
                    td(nar, 72, right: true),
                    td(isp, 72, right: true),
                    td(ost, 64, right: true),
                    td(stText, 72, right: true),
                  ],
                ),
              ),
            ),
            rowMenu(),
          ],
        ),
      ),
    );
  }

  Widget _orderPartnerFooter(String partner, List<OrderModel> orders) {
    final cs = Theme.of(context).colorScheme;
    final lines = _sortedLinesForOrders(orders);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        'Ukupno za $partner: narudžbi ${orders.length}, '
        'redova (stavki) ${lines.length}.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildGroupedOrderTables(List<OrderModel> list) {
    final byPartner = <String, List<OrderModel>>{};
    for (final o in list) {
      final k = o.partnerName.trim().isEmpty
          ? 'Nepoznat partner'
          : o.partnerName.trim();
      byPartner.putIfAbsent(k, () => []).add(o);
    }
    final keys = byPartner.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollW = constraints.maxWidth < _orderTableWidth
            ? _orderTableWidth
            : constraints.maxWidth;
        final cs = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pregled po kupcu / partneru — redovi sortirani po roku isporuke. '
              'Zelena pozadina: dovoljno zalihe za ostatak.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (var pi = 0; pi < keys.length; pi++) ...[
              if (pi > 0) const SizedBox(height: 14),
              Material(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    keys[pi],
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Material(
                color: cs.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 2, right: 4),
                  child: SizedBox(
                    width: scrollW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _orderTableHeaderRow(),
                        for (final line in _sortedLinesForOrders(
                          byPartner[keys[pi]]!,
                        ))
                          _orderDataRow(line.o, line.it),
                      ],
                    ),
                  ),
                ),
              ),
              _orderPartnerFooter(keys[pi], byPartner[keys[pi]]!),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompactOrderCards(List<OrderModel> list) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<OrderModel>.from(list)
      ..sort(
        (a, b) => _orderCompactSortKey(a).compareTo(_orderCompactSortKey(b)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kartični prikaz — sort po najranijem roku. '
          'Zelena pozadina stavke: dovoljno zalihe za ostatak.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        ...sorted.map(_compactOrderCard),
      ],
    );
  }

  Widget _compactOrderCard(OrderModel o) {
    final cs = Theme.of(context).colorScheme;
    final ref = _partnerRef(o);

    Widget lineTile(OrderItemModel it) {
      final ready = _rowReady(o, it);
      final bg = ready
          ? Color.alphaBlend(
              const Color(0xFFC8E6C9).withValues(alpha: 0.75),
              cs.surface,
            )
          : cs.surfaceContainerHighest.withValues(alpha: 0.35);

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${it.productCode} — ${it.productName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Naručeno ${_formatQty(it.qty)} • ostalo ${_formatQty(_remainingQty(o, it))}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openOrder(o),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      o.partnerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_typeLabel(o.orderType)} • ${orderStatusLabel(o.status)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ref != null && ref.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ref: $ref',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Rok: ${_formatDate(o.requestedDeliveryDate ?? o.confirmedDeliveryDate)}'
                      ' • Nar.: ${_formatDate(o.orderDate ?? o.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (o.items.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      ...o.items.take(5).map(lineTile),
                      if (o.items.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${o.items.length - 5} stavki',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Nema stavki',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 2),
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onSelected: (v) {
                if (v == 'det') _openOrder(o);
                if (v == 'asm') _openOrderUnifiedAssessment(o);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'det', child: Text('Detalji narudžbe')),
                PopupMenuItem(value: 'asm', child: Text('Procjena (šablon)')),
              ],
            ),
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
                      _buildSearchAndFiltersStrip(),
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
                      child: Text(_errorMessage!, textAlign: TextAlign.center),
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
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < _compactListBreakpoint;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_stockLoading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: LinearProgressIndicator(minHeight: 3),
                              ),
                            if (compact)
                              _buildCompactOrderCards(list)
                            else
                              _buildGroupedOrderTables(list),
                          ],
                        );
                      },
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
        // Operativni pregled: otkazane su na filteru "Otkazane".
        return o.status != OrderStatus.cancelled;
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
