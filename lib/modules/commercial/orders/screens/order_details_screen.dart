import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/user_display_label.dart';
import '../../partners/services/suppliers_service.dart';
import '../export/supplier_order_pdf_export.dart';
import '../models/order_model.dart';
import '../order_status_ui.dart';
import '../services/document_pdf_settings_service.dart';
import '../services/order_status_engine.dart';
import '../services/orders_service.dart';
import 'document_pdf_settings_screen.dart';
import '../../assessment/screens/unified_assessment_run_screen.dart';
import 'order_edit_screen.dart';
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
  final DocumentPdfSettingsService _pdfSettingsService =
      DocumentPdfSettingsService();
  final SuppliersService _suppliersService = SuppliersService();
  static const OrderStatusEngine _statusTransitions = OrderStatusEngine();

  late OrderModel _order;
  bool _refreshing = false;
  String? _error;

  /// Čitljivi akteri (nikad sirovi UID u UI — vidi [UserDisplayLabel.resolveStored]).
  late String _actorCreatedLabel;
  late String _actorUpdatedLabel;
  int _actorResolveGen = 0;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreatePnFromLine => ProductionAccessHelper.canManage(
    role: _role,
    card: ProductionDashboardCard.productionOrders,
  );

  String get _userId => (widget.companyData['userId'] ?? '').toString().trim();

  bool get _canManageOrder =>
      _role == 'admin' ||
      _role == 'production_manager' ||
      _role == 'sales' ||
      _role == 'purchasing' ||
      _role == 'logistics_manager';

  bool get _canEditOrder =>
      _canManageOrder &&
      _order.status != OrderStatus.cancelled &&
      _order.status != OrderStatus.closed;

  bool get _canCloseOrder =>
      _canManageOrder &&
      _statusTransitions.canManualTransition(
        orderType: _order.orderType.value,
        currentStatus: _order.status.value,
        newStatus: OrderStatus.closed.value,
      );

  bool get _canCancelOrder =>
      _canManageOrder &&
      _statusTransitions.canManualTransition(
        orderType: _order.orderType.value,
        currentStatus: _order.status.value,
        newStatus: OrderStatus.cancelled.value,
      );

  Future<void> _openEdit() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderEditScreen(companyData: widget.companyData, order: _order),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openOrderUnifiedAssessment() async {
    final pkOrder = (_order.plantKey ?? '').toString().trim();
    final pkCompany = (widget.companyData['plantKey'] ?? '').toString().trim();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedAssessmentRunScreen(
          companyId: _companyId,
          plantKey: pkOrder.isNotEmpty ? pkOrder : pkCompany,
          entityType: 'production_order',
          entityId: _order.id,
          entityLabel: '${_order.orderNumber} • ${_order.partnerName}'.trim(),
          userRole: _role,
        ),
      ),
    );
  }

  Future<void> _confirmClose() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zatvori narudžbu'),
        content: const Text(
          'Zatvorena narudžba se više ne smatra aktivnom u operativnom smislu. '
          'Nastaviti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (_companyId.isEmpty || _userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje companyId ili userId.')),
      );
      return;
    }
    try {
      await _ordersService.updateOrderStatus(
        companyId: _companyId,
        orderId: _order.id,
        newStatus: OrderStatus.closed.value,
        updatedBy: _userId,
        reason: 'Zatvaranje iz detalja narudžbe',
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Narudžba je zatvorena.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Future<void> _confirmCancel() async {
    final reasonController = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkaži narudžbu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Otkazana narudžba se neće dalje obraditi. Možete unijeti razlog (opcionalno).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Razlog'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Otkaži'),
          ),
        ],
      ),
    );
    if (go != true) {
      reasonController.dispose();
      return;
    }
    if (!mounted) {
      reasonController.dispose();
      return;
    }
    if (_companyId.isEmpty || _userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje companyId ili userId.')),
      );
      reasonController.dispose();
      return;
    }
    final reason = reasonController.text.trim();
    reasonController.dispose();
    try {
      await _ordersService.updateOrderStatus(
        companyId: _companyId,
        orderId: _order.id,
        newStatus: OrderStatus.cancelled.value,
        updatedBy: _userId,
        reason: reason.isEmpty ? 'Otkazivanje iz detalja narudžbe' : reason,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Narudžba je otkazana.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _applySessionActorLabelsSync();
    _resolveActorLabelsAsync();
    _load();
  }

  String get _sessionUserId =>
      (widget.companyData['userId'] ?? '').toString().trim();

  /// Brzo: vlastiti UID → ime/email iz sesije; ostalo privremeno „…“ dok [resolveStored] ne završi.
  void _applySessionActorLabelsSync() {
    _actorCreatedLabel = _actorLabelSyncOnly(_order.createdBy);
    _actorUpdatedLabel = _actorLabelSyncOnly(_order.updatedBy);
  }

  String _actorLabelSyncOnly(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return '—';
    if (t.contains('@')) return t;
    final sid = _sessionUserId;
    if (sid.isNotEmpty && t == sid) {
      return UserDisplayLabel.fromSessionMap(widget.companyData);
    }
    return '…';
  }

  Future<void> _resolveActorLabelsAsync() async {
    final gen = ++_actorResolveGen;
    final order = _order;
    final fs = FirebaseFirestore.instance;
    final c = await UserDisplayLabel.resolveStored(
      fs,
      (order.createdBy ?? '').trim(),
    );
    final u = await UserDisplayLabel.resolveStored(
      fs,
      (order.updatedBy ?? '').trim(),
    );
    if (!mounted || gen != _actorResolveGen) return;
    setState(() {
      _actorCreatedLabel = c;
      _actorUpdatedLabel = u;
    });
  }

  Future<void> _openDocumentPdfSettings() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentPdfSettingsScreen(companyData: widget.companyData),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postavke dokumenta su ažurirane.')),
      );
    }
  }

  Future<void> _previewSupplierOrderPdf() async {
    if (_order.orderType != OrderType.supplier) return;
    if (_companyId.isEmpty) return;
    try {
      final settings = await _pdfSettingsService.load(_companyId);
      final logoBytes = await SupplierOrderPdfExport.loadLogoBytes(
        companyId: _companyId,
        settings: settings,
        companyData: widget.companyData,
      );
      final supplier = await _suppliersService.getById(
        companyId: _companyId,
        supplierId: _order.partnerId,
      );
      await SupplierOrderPdfExport.preview(
        order: _order,
        settings: settings,
        companyData: widget.companyData,
        supplier: supplier,
        logoBytes: logoBytes,
        responsiblePersonLabel: _actorCreatedLabel,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Future<void> _shareSupplierOrderPdf() async {
    if (_order.orderType != OrderType.supplier) return;
    if (_companyId.isEmpty) return;
    try {
      final settings = await _pdfSettingsService.load(_companyId);
      final logoBytes = await SupplierOrderPdfExport.loadLogoBytes(
        companyId: _companyId,
        settings: settings,
        companyData: widget.companyData,
      );
      final supplier = await _suppliersService.getById(
        companyId: _companyId,
        supplierId: _order.partnerId,
      );
      final bytes = await SupplierOrderPdfExport.buildPdfBytes(
        order: _order,
        settings: settings,
        companyData: widget.companyData,
        supplier: supplier,
        logoBytes: logoBytes,
        responsiblePersonLabel: _actorCreatedLabel,
      );
      final dir = await getTemporaryDirectory();
      final safe = _order.orderNumber.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final path = '${dir.path}/narudzba_$safe.pdf';
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Narudžba ${_order.orderNumber}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
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
      if (fresh != null && mounted) {
        _applySessionActorLabelsSync();
        await _resolveActorLabelsAsync();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _refreshing = false;
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    final date = _formatDate(d);
    final t =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date, $t';
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
          _metaRow(
            'Tražena isporuka',
            _formatDate(_order.requestedDeliveryDate),
          ),
          _metaRow(
            'Potvrđena isporuka',
            _formatDate(_order.confirmedDeliveryDate),
          ),
          if ((_order.deliveryAddress ?? '').trim().isNotEmpty)
            _metaRow('Adresa isporuke', _order.deliveryAddress!.trim()),
          if ((_order.shippingTerms ?? '').trim().isNotEmpty)
            _metaRow('Dostava / uvjeti', _order.shippingTerms!.trim()),
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
          _metaRow('Kreirano', _formatDateTime(_order.createdAt)),
          _metaRow('Kreirao', _actorCreatedLabel),
          _metaRow('Ažurirano', _formatDateTime(_order.updatedAt)),
          _metaRow('Ažurirao', _actorUpdatedLabel),
          _metaRow('Ukupno naručeno', _formatQty(_order.totalQty)),
          if ((_order.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Napomena',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
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
        child: const Text('Nema stavki u order_items (ili još nisu učitane).'),
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
                  if (_order.orderType == OrderType.supplier)
                    Text(
                      'Cijena: ${item.unitPrice.toStringAsFixed(2)} '
                      '${(_order.currency ?? '').trim().isNotEmpty ? _order.currency! : 'EUR'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (item.dueDate != null)
                    Text(
                      'Rok: ${_formatDate(item.dueDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  if (lineLbl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Status linije: $lineLbl',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  if (item.linkedProductionOrderCodes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'PN: ${item.linkedProductionOrderCodes.join(', ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  if (_order.orderType == OrderType.customer &&
                      _canCreatePnFromLine)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.precision_manufacturing,
                            size: 18,
                          ),
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
          if (_order.orderType == OrderType.supplier)
            PopupMenuButton<String>(
              tooltip: 'PDF narudžbe',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onSelected: (v) {
                if (v == 'print') {
                  _previewSupplierOrderPdf();
                } else if (v == 'share') {
                  _shareSupplierOrderPdf();
                } else if (v == 'settings') {
                  _openDocumentPdfSettings();
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'print',
                  child: Text('Pregled i štampa PDF…'),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text('Dijeli PDF…'),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Text('Postavke PDF dokumenta…'),
                ),
              ],
            ),
          if (_canEditOrder)
            IconButton(
              tooltip: 'Uredi narudžbu',
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Procjena (šablon)',
            onPressed: _openOrderUnifiedAssessment,
            icon: const Icon(Icons.table_chart_outlined),
          ),
          if (_canCloseOrder || _canCancelOrder)
            PopupMenuButton<String>(
              tooltip: 'Zatvori ili otkaži',
              icon: const Icon(Icons.more_vert),
              itemBuilder: (ctx) => [
                if (_canCloseOrder)
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Zatvori narudžbu'),
                  ),
                if (_canCancelOrder)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Otkaži narudžbu'),
                  ),
              ],
              onSelected: (v) {
                if (v == 'close') {
                  _confirmClose();
                } else if (v == 'cancel') {
                  _confirmCancel();
                }
              },
            ),
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
