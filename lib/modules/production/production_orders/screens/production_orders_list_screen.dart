import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/access/production_access_helper.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../../../core/date/date_range_utils.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/date_range_filter_controls.dart';
import '../../../../core/ui/export_list_popup_menu.dart';
import '../../../../core/ui/standard_list_components.dart';
import '../../../logistics/inventory/services/product_warehouse_stock_service.dart';
import '../export/production_orders_list_pdf_export.dart';
import '../models/production_order_model.dart';
import '../services/production_order_service.dart';
import '../../work_centers/models/work_center_model.dart';
import '../../work_centers/services/work_center_service.dart';
import 'production_order_create_screen.dart';
import 'production_order_details_screen.dart';

/// Koje opcijske kolone prikazati u tabu „Izvještaj“ (samo ako u grupi postoji podatak).
class _ReportColVis {
  const _ReportColVis({
    required this.showRn,
    required this.showPallet,
    required this.showNotes,
  });

  final bool showRn;
  final bool showPallet;
  final bool showNotes;
}

class ProductionOrdersListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Kad je postavljen (npr. s dashboarda „Praćenje“), lista otvara taj status filter.
  final ProductionOrderStatusFilter? initialStatusFilter;

  const ProductionOrdersListScreen({
    super.key,
    required this.companyData,
    this.initialStatusFilter,
  });

  @override
  State<ProductionOrdersListScreen> createState() =>
      _ProductionOrdersListScreenState();
}

class _ProductionOrdersListScreenState extends State<ProductionOrdersListScreen>
    with SingleTickerProviderStateMixin {
  final ProductionOrderService _service = ProductionOrderService();
  final WorkCenterService _workCenterService = WorkCenterService();
  final ProductWarehouseStockService _stockService =
      ProductWarehouseStockService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;

  /// Sklopivi blok: pretraga + kupac/proces/radni centar + status/datum.
  bool _searchStripExpanded = false;
  ProductionOrderStatusFilter _selectedStatus = ProductionOrderStatusFilter.all;
  List<ProductionOrderModel> _orders = const [];
  final Map<String, double> _stockByProductId = {};
  bool _stockLoading = false;
  Timer? _stockDebounce;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  late TabController _tabController;

  String? _filterCustomerName;
  String? _filterOperationName;

  /// `null` = svi, `__none__` = bez RC, inače `workCenterId`.
  String? _filterWorkCenterKey;

  List<WorkCenter> _workCenters = const [];

  /// Ljudski naziv pogona (iz šifrarnika); `null` = još učitavanje.
  String? _plantResolvedLabel;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreateOrder => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.productionOrders,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialStatusFilter != null) {
      _selectedStatus = widget.initialStatusFilter!;
    }
    _resolvePlantLabel();
    _searchController.addListener(() {
      if (mounted) setState(() {});
      _scheduleStockRefresh();
    });
    _loadWorkCenters();
    _loadOrders();
  }

  /// Povlačenje + nalozi (npr. nakon pull-to-refresh) da se šifrarnik RC uskladi s filterom.
  Future<void> _refreshListData() async {
    await Future.wait<void>([
      _loadWorkCenters(),
      _loadOrders(),
    ]);
  }

  Future<void> _loadWorkCenters() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) return;
    try {
      final list = await _workCenterService.listWorkCentersForPlant(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      if (!mounted) return;
      setState(() => _workCenters = list);
    } catch (_) {
      /* šifrarnik može biti prazan */
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stockDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolvePlantLabel() async {
    final cid = _companyId;
    final pk = _plantKey;
    if (cid.isEmpty || pk.isEmpty) return;
    final label = await CompanyPlantDisplayName.resolve(
      companyId: cid,
      plantKey: pk,
    );
    if (!mounted) return;
    setState(() => _plantResolvedLabel = label);
  }

  String _plantLineForDisplay() {
    if (_plantKey.isEmpty) return '—';
    if (_plantResolvedLabel == null) return '…';
    return _plantResolvedLabel!;
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
      final pid = o.productId.trim();
      if (pid.isNotEmpty) ids.add(pid);
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
            next[pid] = lines.fold<double>(0, (a, b) => a + b.quantityOnHand);
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
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = _companyId.isEmpty
            ? 'Nedostaje podatak o kompaniji u sesiji. Obrati se administratoru.'
            : 'Nedostaje podatak o pogonu u sesiji. Obrati se administratoru.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _service.getOrders(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
        if (_filterCustomerName != null &&
            !_distinctCustomerFilterKeys().contains(_filterCustomerName!)) {
          _filterCustomerName = null;
        }
        if (_filterOperationName != null &&
            _filterOperationName != '__bez_procesa__' &&
            !_distinctOperationNames().contains(_filterOperationName!)) {
          _filterOperationName = null;
        }
        if (_filterWorkCenterKey != null &&
            _filterWorkCenterKey != '__none__') {
          final k = _filterWorkCenterKey!;
          final inCatalog = _workCenters.any((w) => w.id == k);
          final inOrders = orders.any(
            (o) => (o.workCenterId ?? '').trim() == k,
          );
          if (!inCatalog && !inOrders) {
            _filterWorkCenterKey = null;
          }
        }
      });
      _scheduleStockRefresh();
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
        builder: (_) =>
            ProductionOrderCreateScreen(companyData: widget.companyData),
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
      final cust = _customerGroupKey(o);
      final op = (o.operationName ?? '').trim();
      final wcCode = (o.workCenterCode ?? '').trim().toLowerCase();
      final wcName = (o.workCenterName ?? '').trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          o.productionOrderCode.toLowerCase().contains(q) ||
          o.productCode.toLowerCase().contains(q) ||
          o.productName.toLowerCase().contains(q) ||
          (o.customerName ?? '').toLowerCase().contains(q) ||
          (o.sourceCustomerName ?? '').toLowerCase().contains(q) ||
          op.toLowerCase().contains(q) ||
          wcCode.contains(q) ||
          wcName.contains(q);
      final matchesStatus = _selectedStatus.matches(o.status);
      final matchesDate = dateInInclusiveRange(o.createdAt, _dateFrom, _dateTo);
      final matchesCustomer =
          _filterCustomerName == null || cust == _filterCustomerName;
      final matchesOp =
          _filterOperationName == null ||
          (_filterOperationName == '__bez_procesa__' && op.isEmpty) ||
          op == _filterOperationName;
      final wid = (o.workCenterId ?? '').trim();
      final matchesWc = _filterWorkCenterKey == null
          ? true
          : _filterWorkCenterKey == '__none__'
          ? wid.isEmpty
          : wid == _filterWorkCenterKey;
      return matchesSearch &&
          matchesStatus &&
          matchesDate &&
          matchesCustomer &&
          matchesOp &&
          matchesWc;
    }).toList();
  }

  int get _activeFiltersCount {
    int n = 0;
    if (_selectedStatus != ProductionOrderStatusFilter.all) n++;
    if (_dateFrom != null || _dateTo != null) n++;
    if (_filterCustomerName != null) n++;
    if (_filterOperationName != null) n++;
    if (_filterWorkCenterKey != null) n++;
    return n;
  }

  int get _searchStripActiveCount =>
      _activeFiltersCount + (_searchController.text.trim().isNotEmpty ? 1 : 0);

  List<String> _distinctCustomerFilterKeys() {
    final s = <String>{};
    for (final o in _orders) {
      final k = _customerGroupKey(o);
      if (k != 'Bez naziva kupca') s.add(k);
    }
    return s.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _distinctOperationNames() {
    final s = <String>{};
    for (final o in _orders) {
      final v = (o.operationName ?? '').trim();
      if (v.isNotEmpty) s.add(v);
    }
    return s.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Kalendarski dani od datuma narudžbe (ili kreiranja naloga ako narudžba nije snimljena)
  /// do roka isporuke (traženi rok, inače planirani kraj izrade).
  int? _leadDaysOrderToDelivery(ProductionOrderModel o) {
    final end =
        o.requestedDeliveryDate ?? o.scheduledEndAt ?? o.scheduledStartAt;
    if (end == null) return null;
    final start = o.sourceOrderDate ?? o.createdAt;
    final sd = DateTime(start.year, start.month, start.day);
    final ed = DateTime(end.year, end.month, end.day);
    return ed.difference(sd).inDays;
  }

  String _leadDaysLabel(ProductionOrderModel o) {
    final d = _leadDaysOrderToDelivery(o);
    if (d == null) return '—';
    return '$d';
  }

  _ReportColVis _reportColVisFor(List<ProductionOrderModel> rows) {
    var showRn = false;
    var showPallet = false;
    var showNotes = false;
    for (final o in rows) {
      if (o.workOrderDate != null ||
          (o.workOrderNumber?.trim().isNotEmpty ?? false)) {
        showRn = true;
      }
      if (o.palletCount != null || o.piecesPerPallet != null) {
        showPallet = true;
      }
      if ((o.notes?.trim().isNotEmpty ?? false)) {
        showNotes = true;
      }
    }
    return _ReportColVis(
      showRn: showRn,
      showPallet: showPallet,
      showNotes: showNotes,
    );
  }

  String _rnCellText(ProductionOrderModel o) {
    final parts = <String>[];
    if (o.workOrderDate != null) {
      parts.add(_formatDate(o.workOrderDate));
    }
    final wo = o.workOrderNumber?.trim();
    if (wo != null && wo.isNotEmpty) parts.add(wo);
    if (parts.isEmpty) return '—';
    return parts.join('\n');
  }

  String _rnCellOneLine(ProductionOrderModel o) =>
      _rnCellText(o).replaceAll('\n', ' · ');

  String _palletOneLine(ProductionOrderModel o) {
    final pc = o.palletCount;
    final up = o.piecesPerPallet;
    if (pc == null && up == null) return '—';
    if (pc != null && up != null && up > 0) {
      return '${_formatQty(pc)} × ${_formatQty(up)}';
    }
    if (pc != null) return '${_formatQty(pc)} pal.';
    return '${_formatQty(up!)} kom/pal.';
  }

  Widget _reportProductCodeCell(ProductionOrderModel o) {
    final pc = o.productCode.trim();
    return Text(
      pc.isEmpty ? '—' : pc,
      style: const TextStyle(fontSize: 10.5, height: 1.25),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }

  List<DropdownMenuItem<String?>> _workCenterFilterItems() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Svi radni centri'),
      ),
      const DropdownMenuItem<String?>(
        value: '__none__',
        child: Text('(bez radnog centra)'),
      ),
    ];
    final seen = <String>{};
    for (final w in _workCenters) {
      final id = w.id.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      items.add(
        DropdownMenuItem<String?>(
          value: id,
          child: Text(
            '${w.workCenterCode} — ${w.name}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    for (final o in _orders) {
      final id = (o.workCenterId ?? '').trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      final label = [
        (o.workCenterCode ?? '').trim(),
        (o.workCenterName ?? '').trim(),
      ].where((s) => s.isNotEmpty).join(' — ');
      items.add(
        DropdownMenuItem<String?>(
          value: id,
          child: Text(
            label.isEmpty ? id : label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    final k = _filterWorkCenterKey;
    if (k != null &&
        k != '__none__' &&
        !items.any((e) => e.value == k)) {
      items.add(
        DropdownMenuItem<String?>(
          value: k,
          child: Text(k, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return items;
  }

  Widget _buildPnAxisFilters() {
    final customers = _distinctCustomerFilterKeys();
    final ops = _distinctOperationNames();

    Widget axisDropdown<T>({
      required String label,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required ValueChanged<T?> onChanged,
    }) {
      final cs = Theme.of(context).colorScheme;
      return DropdownButtonFormField<T?>(
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: cs.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: kOperonixProductionBrandGreen,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        initialValue: value,
        items: items,
        onChanged: onChanged,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 560;
        final customerItems = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Svi kupci'),
          ),
          ...customers.map(
            (n) => DropdownMenuItem<String?>(
              value: n,
              child: Text(n, overflow: TextOverflow.ellipsis),
            ),
          ),
        ];
        final opItems = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Svi procesi'),
          ),
          const DropdownMenuItem<String?>(
            value: '__bez_procesa__',
            child: Text('(bez oznake procesa)'),
          ),
          ...ops.map(
            (n) => DropdownMenuItem<String?>(
              value: n,
              child: Text(n, overflow: TextOverflow.ellipsis),
            ),
          ),
        ];
        final wcItems = _workCenterFilterItems();

        final plantLabel = _plantLineForDisplay();

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: axisDropdown<String?>(
                  label: 'Kupac',
                  value: _filterCustomerName,
                  items: customerItems,
                  onChanged: (v) {
                    setState(() => _filterCustomerName = v);
                    _scheduleStockRefresh();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: axisDropdown<String?>(
                  label: 'Proces / segment',
                  value: _filterOperationName,
                  items: opItems,
                  onChanged: (v) {
                    setState(() => _filterOperationName = v);
                    _scheduleStockRefresh();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: axisDropdown<String?>(
                  label: 'Radni centar',
                  value: _filterWorkCenterKey,
                  items: wcItems,
                  onChanged: (v) {
                    setState(() => _filterWorkCenterKey = v);
                    _scheduleStockRefresh();
                  },
                ),
              ),
              Text(
                'Pogon: $plantLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Kupac',
                      value: _filterCustomerName,
                      items: customerItems,
                      onChanged: (v) {
                        setState(() => _filterCustomerName = v);
                        _scheduleStockRefresh();
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Proces / segment',
                      value: _filterOperationName,
                      items: opItems,
                      onChanged: (v) {
                        setState(() => _filterOperationName = v);
                        _scheduleStockRefresh();
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: axisDropdown<String?>(
                label: 'Radni centar',
                value: _filterWorkCenterKey,
                items: wcItems,
                onChanged: (v) {
                  setState(() => _filterWorkCenterKey = v);
                  _scheduleStockRefresh();
                },
              ),
            ),
            Text(
              'Pogon: $plantLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  String _workCenterFilterLabelForExport() {
    final k = _filterWorkCenterKey;
    if (k == null) return '';
    if (k == '__none__') return '(bez radnog centra)';
    WorkCenter? fromCat;
    for (final w in _workCenters) {
      if (w.id == k) {
        fromCat = w;
        break;
      }
    }
    if (fromCat != null) {
      return '${fromCat.workCenterCode} — ${fromCat.name}';
    }
    for (final o in _orders) {
      if ((o.workCenterId ?? '').trim() != k) continue;
      final t = [
        (o.workCenterCode ?? '').trim(),
        (o.workCenterName ?? '').trim(),
      ].where((s) => s.isNotEmpty).join(' — ');
      return t.isEmpty ? k : t;
    }
    return k;
  }

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
        'Datum kreiranja: ${formatCalendarDay(_dateFrom)} – ${formatCalendarDay(_dateTo)}',
      );
    }
    if (_selectedStatus != ProductionOrderStatusFilter.all) {
      parts.add('Status: ${_selectedStatus.label}');
    }
    if (_filterCustomerName != null) {
      parts.add('Kupac: ${_filterCustomerName!}');
    }
    if (_filterOperationName != null) {
      parts.add(
        'Proces: ${_filterOperationName == '__bez_procesa__' ? '(bez oznake)' : _filterOperationName!}',
      );
    }
    if (_filterWorkCenterKey != null) {
      parts.add('Radni centar: ${_workCenterFilterLabelForExport()}');
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
          content: Text('Nema naloga za izvoz (filtrirani pregled je prazan).'),
        ),
      );
      return;
    }
    try {
      await _refreshStockForFiltered();
      if (!mounted) return;
      await ProductionOrdersListPdfExport.preview(
        orders: list,
        reportTitle: 'Pregled proizvodnih naloga (detaljno)',
        companyLine:
            '${_companyDisplayName()}  ·  Pogon: ${_plantLineForDisplay()}',
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

  Future<void> _exportCsv() async {
    final list = _filteredOrders;
    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema naloga za izvoz (filtrirani pregled je prazan).'),
        ),
      );
      return;
    }
    try {
      await _refreshStockForFiltered();
      if (!mounted) return;
      final fn =
          'proizvodni_nalozi_${DateTime.now().millisecondsSinceEpoch}.csv';
      await ProductionOrdersListPdfExport.shareCsv(
        orders: list,
        stockByProductId: _stockByProductId.isEmpty
            ? null
            : Map<String, double>.from(_stockByProductId),
        fileName: fn,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Future<void> _exportPdfShare() async {
    final list = _filteredOrders;
    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema naloga za izvoz (filtrirani pregled je prazan).'),
        ),
      );
      return;
    }
    try {
      await _refreshStockForFiltered();
      if (!mounted) return;
      await ProductionOrdersListPdfExport.sharePdfFile(
        orders: list,
        reportTitle: 'Pregled proizvodnih naloga (detaljno)',
        companyLine:
            '${_companyDisplayName()}  ·  Pogon: ${_plantLineForDisplay()}',
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

  Widget _exportMenuButton() {
    return ExportListPopupMenu(
      enabled: !_isLoading,
      onCsv: () {
        _exportCsv();
      },
      onPdfPreview: () {
        _exportPdf();
      },
      onPdfShare: () {
        _exportPdfShare();
      },
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _formatQty(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
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
                '• Filtriranje po statusu i datumu kreiranja (od–do)\n'
                '• Tab „Zalihe i status“: plan / ostalo / stanje zalihe (zeleno = spremno)\n'
                '• Tab „Izvještaj“: detaljnija tabela po kupcu (opcijske kolone samo ako postoje podaci)\n'
                '• Filteri: kupac, proces (operationName), radni centar, status, datum kreiranja\n'
                '• Izvoz: CSV, PDF (pregled/ispis), dijeljenje PDF-a; detalji naloga\n\n'
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
                beforeInfoAction: _exportMenuButton(),
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
          beforeInfoAction: _exportMenuButton(),
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
    final done = _orders
        .where((o) => o.status == 'completed' || o.status == 'closed')
        .length;

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

  Widget _buildSearch({bool compact = false}) {
    return StandardSearchField(
      controller: _searchController,
      hintText: 'Kod naloga, proizvod, kupac…',
      compact: compact,
    );
  }

  Widget _buildStatusDateFilters() {
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          children: ProductionOrderStatusFilter.values.map((status) {
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
        DateRangeFilterControls(
          sectionTitle: 'Datum kreiranja naloga',
          helpText: 'Od–do po danu kreiranja naloga.',
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
          _buildPnAxisFilters(),
          const SizedBox(height: 10),
          _buildStatusDateFilters(),
        ],
      ),
    );
  }

  Map<int, TableColumnWidth> _pnColumnWidths() {
    final m = <int, TableColumnWidth>{};
    var i = 0;
    TableColumnWidth intr() => const IntrinsicColumnWidth();
    void addIntr() => m[i++] = intr();
    addIntr(); // Broj PN
    addIntr(); // Kreirano
    addIntr(); // Narudžba
    addIntr(); // Rok
    addIntr(); // Dana
    addIntr(); // Status
    addIntr(); // Šifra
    m[i++] = const FlexColumnWidth(1); // Naziv
    addIntr(); // MJ
    addIntr(); // Plan
    addIntr(); // Dobro
    addIntr(); // Ostalo
    addIntr(); // Stanje
    return m;
  }

  Widget _pnOrdersTable(List<ProductionOrderModel> rows) {
    final cs = Theme.of(context).colorScheme;
    final headerBg = cs.surfaceContainerHighest;
    final headerStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = TextStyle(fontSize: 11, color: cs.onSurface);
    const padH = 8.0;
    const padV = 8.0;

    Widget hText(String t, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: padH, vertical: 10),
        child: Align(
          alignment: align == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            t,
            style: headerStyle,
            textAlign: align,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }

    TableCell h(String t, {TextAlign align = TextAlign.left}) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: ColoredBox(
          color: headerBg,
          child: hText(t, align: align),
        ),
      );
    }

    TableCell d(
      ProductionOrderModel o,
      Widget child, {
      Color? rowBg,
      Alignment align = Alignment.centerLeft,
    }) {
      final bg = rowBg ?? cs.surface;
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.top,
        child: Material(
          color: bg,
          child: InkWell(
            onTap: () => _openDetailsScreen(o),
            hoverColor: cs.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
              ),
              child: Align(
                alignment: align,
                child: DefaultTextStyle(style: cellStyle, child: child),
              ),
            ),
          ),
        ),
      );
    }

    Widget oneLine(String text) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }

    final headerRow = TableRow(
      children: [
        h('Broj PN'),
        h('Kreirano'),
        h('Narudžba'),
        h('Rok (plan)'),
        h('Dana', align: TextAlign.right),
        h('Status'),
        h('Šifra'),
        h('Naziv'),
        h('MJ', align: TextAlign.right),
        h('Plan', align: TextAlign.right),
        h('Dobro', align: TextAlign.right),
        h('Ostalo', align: TextAlign.right),
        h('Stanje', align: TextAlign.right),
      ],
    );

    final dataRows = rows.map((o) {
      final ready = _pnRowReady(o);
      final rowBg = ready
          ? Color.alphaBlend(
              const Color(0xFFC8E6C9).withValues(alpha: 0.85),
              cs.surface,
            )
          : null;
      final pid = o.productId.trim();
      final stock = pid.isEmpty ? null : _stockByProductId[pid];
      final rok = _formatDate(
        o.requestedDeliveryDate ?? o.scheduledEndAt ?? o.scheduledStartAt,
      );
      final src = (o.sourceOrderNumber ?? '').trim().isEmpty
          ? '—'
          : o.sourceOrderNumber!;
      return TableRow(
        children: [
          d(
            o,
            Tooltip(
              message: o.productionOrderCode,
              child: oneLine(o.productionOrderCode),
            ),
            rowBg: rowBg,
          ),
          d(o, oneLine(_formatDate(o.createdAt)), rowBg: rowBg),
          d(o, oneLine(src), rowBg: rowBg),
          d(o, oneLine(rok), rowBg: rowBg),
          d(
            o,
            oneLine(_leadDaysLabel(o)),
            rowBg: rowBg,
            align: Alignment.centerRight,
          ),
          d(o, oneLine(_statusLabel(o.status)), rowBg: rowBg),
          d(o, oneLine(o.productCode), rowBg: rowBg),
          d(o, oneLine(o.productName), rowBg: rowBg),
          d(
            o,
            oneLine(o.unit.isNotEmpty ? o.unit : '—'),
            rowBg: rowBg,
            align: Alignment.centerRight,
          ),
          d(
            o,
            oneLine(_formatQty(o.plannedQty)),
            rowBg: rowBg,
            align: Alignment.centerRight,
          ),
          d(
            o,
            oneLine(_formatQty(o.producedGoodQty)),
            rowBg: rowBg,
            align: Alignment.centerRight,
          ),
          d(
            o,
            oneLine(_formatQty(_pnRemaining(o))),
            rowBg: rowBg,
            align: Alignment.centerRight,
          ),
          d(
            o,
            oneLine(stock == null ? '—' : _formatQty(stock)),
            rowBg: rowBg,
            align: Alignment.centerRight,
          ),
        ],
      );
    }).toList();

    return Table(
      columnWidths: _pnColumnWidths(),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder.all(color: cs.outlineVariant, width: 1),
      children: [headerRow, ...dataRows],
    );
  }

  String _customerGroupKey(ProductionOrderModel o) {
    final a = (o.customerName ?? '').trim();
    if (a.isNotEmpty) return a;
    final b = (o.sourceCustomerName ?? '').trim();
    if (b.isNotEmpty) return b;
    return 'Bez naziva kupca';
  }

  DateTime _pnDeadlineSort(ProductionOrderModel o) {
    return o.scheduledEndAt ??
        o.scheduledStartAt ??
        o.releasedAt ??
        o.createdAt;
  }

  double _pnRemaining(ProductionOrderModel o) {
    if (o.status == 'completed' ||
        o.status == 'closed' ||
        o.status == 'cancelled') {
      return 0;
    }
    final v = o.plannedQty - o.producedGoodQty;
    return v > 0 ? v : 0;
  }

  bool _pnRowReady(ProductionOrderModel o) {
    if (o.status == 'cancelled') return false;
    final rem = _pnRemaining(o);
    if (rem <= 0) return false;
    final pid = o.productId.trim();
    if (pid.isEmpty) return false;
    final stock = _stockByProductId[pid] ?? 0;
    return stock + 1e-9 >= rem;
  }

  Map<int, TableColumnWidth> _reportColumnWidths(_ReportColVis v) {
    final m = <int, TableColumnWidth>{};
    var i = 0;
    TableColumnWidth intr() => const IntrinsicColumnWidth();
    void addIntr() => m[i++] = intr();
    addIntr(); // Kreiran
    addIntr(); // Broj naloga
    addIntr(); // Rok
    addIntr(); // Dana
    if (v.showRn) addIntr();
    addIntr(); // Šifra
    m[i++] = const FlexColumnWidth(
      1,
    ); // Naziv — popunjava preostalu širinu ekrana
    addIntr(); // Plan
    addIntr(); // Izrađeno
    addIntr(); // Ostalo
    if (v.showPallet) addIntr();
    if (v.showNotes) addIntr();
    return m;
  }

  Widget _reportOrdersTable(List<ProductionOrderModel> rows, _ReportColVis v) {
    final cs = Theme.of(context).colorScheme;
    final headerBg = cs.surfaceContainerHighest;
    final headerStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final cellStyle = TextStyle(
      fontSize: 10.5,
      height: 1.25,
      color: cs.onSurface,
    );
    const padH = 10.0;
    const padV = 8.0;

    Widget hText(String t, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: padH,
          vertical: padV + 2,
        ),
        child: Align(
          alignment: align == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            t,
            style: headerStyle,
            textAlign: align,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }

    TableCell h(String t, {TextAlign align = TextAlign.left}) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: ColoredBox(
          color: headerBg,
          child: hText(t, align: align),
        ),
      );
    }

    TableCell cell(
      ProductionOrderModel o,
      Widget child, {
      Alignment align = Alignment.centerLeft,
    }) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.top,
        child: Material(
          color: cs.surface,
          child: InkWell(
            onTap: () => _openDetailsScreen(o),
            hoverColor: cs.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
              ),
              child: Align(
                alignment: align,
                child: DefaultTextStyle(style: cellStyle, child: child),
              ),
            ),
          ),
        ),
      );
    }

    Widget oneLine(String text) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }

    final headerRow = TableRow(
      children: [
        h('Kreiran'),
        h('Broj naloga'),
        h('Rok isporuke'),
        h('Dana', align: TextAlign.right),
        if (v.showRn) h('Radni nalog'),
        h('Šifra'),
        h('Naziv'),
        h('Plan', align: TextAlign.right),
        h('Izrađeno', align: TextAlign.right),
        h('Ostalo', align: TextAlign.right),
        if (v.showPallet) h('Palete'),
        if (v.showNotes) h('Napomena'),
      ],
    );

    final dataRows = rows.map((o) {
      final rokOut =
          o.requestedDeliveryDate ?? o.scheduledEndAt ?? o.scheduledStartAt;
      final notes = o.notes?.trim();
      final noteLine = (notes == null || notes.isEmpty)
          ? '—'
          : notes.replaceAll('\n', ' ');
      return TableRow(
        children: [
          cell(o, oneLine(_formatDate(o.createdAt))),
          cell(
            o,
            Tooltip(
              message: o.productionOrderCode,
              child: oneLine(o.productionOrderCode),
            ),
          ),
          cell(o, oneLine(_formatDate(rokOut))),
          cell(o, oneLine(_leadDaysLabel(o)), align: Alignment.centerRight),
          if (v.showRn) cell(o, oneLine(_rnCellOneLine(o))),
          cell(o, _reportProductCodeCell(o)),
          cell(o, oneLine(o.productName)),
          cell(
            o,
            oneLine(_formatQty(o.plannedQty)),
            align: Alignment.centerRight,
          ),
          cell(
            o,
            oneLine(_formatQty(o.producedGoodQty)),
            align: Alignment.centerRight,
          ),
          cell(
            o,
            oneLine(_formatQty(_pnRemaining(o))),
            align: Alignment.centerRight,
          ),
          if (v.showPallet) cell(o, oneLine(_palletOneLine(o))),
          if (v.showNotes) cell(o, oneLine(noteLine)),
        ],
      );
    }).toList();

    return Table(
      columnWidths: _reportColumnWidths(v),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder.all(color: cs.outlineVariant, width: 1),
      children: [headerRow, ...dataRows],
    );
  }

  Widget _reportCustomerFooter(
    String customer,
    List<ProductionOrderModel> rows,
  ) {
    final cs = Theme.of(context).colorScheme;
    double sumPlan = 0;
    double sumGood = 0;
    double sumRem = 0;
    for (final o in rows) {
      sumPlan += o.plannedQty;
      sumGood += o.producedGoodQty;
      sumRem += _pnRemaining(o);
    }
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
        'Ukupno za $customer: plan ${_formatQty(sumPlan)}, '
        'izrađeno ${_formatQty(sumGood)}, ostalo ${_formatQty(sumRem)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildReportGroupedTables(List<ProductionOrderModel> list) {
    final byCustomer = <String, List<ProductionOrderModel>>{};
    for (final o in list) {
      final k = _customerGroupKey(o);
      byCustomer.putIfAbsent(k, () => []).add(o);
    }
    final keys = byCustomer.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final cs = Theme.of(context).colorScheme;
    final blocks = <Widget>[
      Text(
        'Dana: narudžba → rok isporuke. RN / palete / napomena samo ako postoje u grupi.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 10),
    ];

    for (final customer in keys) {
      final rows = List<ProductionOrderModel>.from(byCustomer[customer]!)
        ..sort((a, b) {
          final c = _pnDeadlineSort(a).compareTo(_pnDeadlineSort(b));
          if (c != 0) return c;
          return a.productionOrderCode.compareTo(b.productionOrderCode);
        });
      final vis = _reportColVisFor(rows);

      blocks.add(
        Material(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              customer,
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
      blocks.add(const SizedBox(height: 6));
      blocks.add(
        Material(
          color: cs.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (ctx, cons) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 2, right: 4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: cons.maxWidth),
                  child: IntrinsicWidth(child: _reportOrdersTable(rows, vis)),
                ),
              );
            },
          ),
        ),
      );
      blocks.add(_reportCustomerFooter(customer, rows));
      blocks.add(const SizedBox(height: 14));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  Widget _buildGroupedPnTables(List<ProductionOrderModel> list) {
    final byCustomer = <String, List<ProductionOrderModel>>{};
    for (final o in list) {
      final k = _customerGroupKey(o);
      byCustomer.putIfAbsent(k, () => []).add(o);
    }
    final keys = byCustomer.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Zeleno: zaliha pokriva ostatak plana.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            for (final customer in keys) ...[
              Material(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    customer,
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
                child: LayoutBuilder(
                  builder: (ctx, cons) {
                    final sorted =
                        List<ProductionOrderModel>.from(byCustomer[customer]!)
                          ..sort((a, b) {
                            final c = _pnDeadlineSort(
                              a,
                            ).compareTo(_pnDeadlineSort(b));
                            if (c != 0) return c;
                            return a.productionOrderCode.compareTo(
                              b.productionOrderCode,
                            );
                          });
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 2, right: 4),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: cons.maxWidth),
                        child: IntrinsicWidth(child: _pnOrdersTable(sorted)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildReportMetaLine() {
    final now = DateTime.now();
    final op = _filterOperationName == null
        ? ''
        : _filterOperationName == '__bez_procesa__'
        ? ' · proces: (bez oznake)'
        : ' · proces: $_filterOperationName';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '${_companyDisplayName()}  ·  Pogon: ${_plantLineForDisplay()}'
        '  ·  Datum ispisa: ${_formatDate(now)}$op',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;

    Widget loadingBody() => const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );

    Widget errorBody() => Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: Text(_error!, textAlign: TextAlign.center)),
    );

    Widget emptyBody() => const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Text('Nema proizvodnih naloga za trenutne filtere.'),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _isLoading
            ? loadingBody()
            : _error != null
            ? errorBody()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildKpis(),
                        const SizedBox(height: 12),
                        _buildSearchAndFiltersStrip(),
                      ],
                    ),
                  ),
                  if (list.isEmpty)
                    Expanded(child: emptyBody())
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildReportMetaLine(),
                          Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: TabBar(
                              controller: _tabController,
                              labelColor: Theme.of(context).colorScheme.primary,
                              unselectedLabelColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              tabs: const [
                                Tab(text: 'Zalihe i status'),
                                Tab(text: 'Izvještaj'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshListData,
                        child: TabBarView(
                          controller: _tabController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [
                                if (_stockLoading)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                    ),
                                  ),
                                _buildGroupedPnTables(list),
                              ],
                            ),
                            ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [_buildReportGroupedTables(list)],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
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
