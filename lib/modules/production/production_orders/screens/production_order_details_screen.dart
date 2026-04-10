import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../execution/screens/production_execution_screen.dart';
import '../../execution/services/production_execution_service.dart';
import '../../products/services/product_service.dart';
import '../models/production_order_model.dart';
import '../printing/bom_classification_catalog.dart';
import '../printing/production_order_pdf.dart';
import '../printing/production_order_qr_payload.dart';
import '../services/production_order_service.dart';
import 'production_order_edit_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String productionOrderId;

  const ProductionOrderDetailsScreen({
    super.key,
    required this.companyData,
    required this.productionOrderId,
  });

  @override
  State<ProductionOrderDetailsScreen> createState() =>
      _ProductionOrderDetailsScreenState();
}

class _ProductionOrderDetailsScreenState
    extends State<ProductionOrderDetailsScreen> {
  final ProductionOrderService _service = ProductionOrderService();
  final ProductionExecutionService _executionService =
      ProductionExecutionService();
  final ProductService _productService = ProductService();

  bool _isLoading = true;
  bool _isReleasing = false;
  bool _isLoadingExecutions = false;
  String? _error;
  ProductionOrderModel? _order;

  List<Map<String, dynamic>> _executions = const [];
  bool _hasMyActiveExecutionForStep = false;

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();
  String get _userId => (widget.companyData['userId'] ?? 'system').toString();

  /// Ime za etikete / ispis: profil firme, pa Firebase, pa ID.
  String get _operatorDisplayName {
    final fromProfile =
        (widget.companyData['userDisplayName'] ?? '').toString().trim();
    if (fromProfile.isNotEmpty) return fromProfile;

    final nick = (widget.companyData['nickname'] ?? '').toString().trim();
    if (nick.isNotEmpty) return nick;

    final u = FirebaseAuth.instance.currentUser;
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;

    final em = u?.email?.trim();
    if (em != null && em.isNotEmpty) return em;

    return _userId;
  }

  String get _role =>
      (widget.companyData['role'] ?? '').toString().toLowerCase();

  bool get _canEdit => _role == 'admin' || _role == 'production_manager';

  bool get _canRelease => _role == 'admin' || _role == 'production_manager';

  bool get _canExecute =>
      _role == 'production_operator' ||
      _role == 'supervisor' ||
      _role == 'production_manager' ||
      _role == 'admin';

  static const String _defaultStepId = 'STEP_1';
  static const String _defaultStepName = 'Glavni proces';
  static const String _defaultExecutionType = 'discrete';

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await _service.getById(
        id: widget.productionOrderId,
        companyId: _companyId,
        plantKey: _plantKey,
      );

      if (!mounted) return;

      setState(() {
        _order = order;
        _isLoading = false;
      });

      if (order != null) {
        await _loadExecutions(order.id);
      } else {
        setState(() {
          _executions = const [];
          _hasMyActiveExecutionForStep = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExecutions(String productionOrderId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingExecutions = true;
    });

    try {
      final executions = await _executionService.getExecutionsForOrder(
        companyId: _companyId,
        plantKey: _plantKey,
        productionOrderId: productionOrderId,
      );

      final hasMyActive = await _executionService
          .hasActiveExecutionForOperatorAndStep(
            companyId: _companyId,
            plantKey: _plantKey,
            productionOrderId: productionOrderId,
            stepId: _defaultStepId,
            operatorId: _userId,
          );

      if (!mounted) return;

      setState(() {
        _executions = executions;
        _hasMyActiveExecutionForStep = hasMyActive;
        _isLoadingExecutions = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _executions = const [];
        _hasMyActiveExecutionForStep = false;
        _isLoadingExecutions = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Future<void> _releaseOrder() async {
    final order = _order;
    if (order == null) return;

    setState(() {
      _isReleasing = true;
    });

    try {
      await _service.releaseProductionOrder(
        productionOrderId: order.id,
        companyId: _companyId,
        plantKey: _plantKey,
        releasedBy: _userId,
      );

      if (!mounted) return;

      await _loadOrder();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nalog je uspješno pušten.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (!mounted) return;

      setState(() {
        _isReleasing = false;
      });
    }
  }

  Future<void> _openExecutionScreen(ProductionOrderModel order) async {
    if (_hasMyActiveExecutionForStep) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Već imaš aktivan execution za ovaj nalog i ovaj korak.',
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionExecutionScreen(
          companyData: widget.companyData,
          orderData: {
            'id': order.id,
            'productionOrderCode': order.productionOrderCode,
            'productId': order.productId,
            'productCode': order.productCode,
            'productName': order.productName,
            'routingId': order.routingId,
            'routingVersion': order.routingVersion,
          },
          stepId: _defaultStepId,
          stepName: _defaultStepName,
          executionType: _defaultExecutionType,
        ),
      ),
    );

    if (result == true) {
      await _loadOrder();
    }
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

  Future<void> _printWorkOrder(ProductionOrderModel order) async {
    try {
      await Printing.layoutPdf(
        name: order.productionOrderCode,
        onLayout: (_) => ProductionOrderPdf.buildWorkOrderPdf(order: order),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  Future<void> _printClassificationLabels(
    ProductionOrderModel order,
    List<String> classifications,
  ) async {
    double? packagingQty;
    try {
      final product = await _productService.getProductById(
        productId: order.productId,
        companyId: _companyId,
      );
      if (product != null) {
        final p = product['packagingQty'];
        if (p is num && p > 0) {
          packagingQty = p.toDouble();
        }
      }
    } catch (_) {
      packagingQty = null;
    }

    if (!mounted) return;

    final confirmedQty = await showDialog<double>(
      context: context,
      builder: (ctx) => _PackagingQtyForLabelDialog(
        order: order,
        suggestedFromProduct: packagingQty,
      ),
    );

    if (!mounted) return;
    if (confirmedQty == null) return;

    final printedAt = DateTime.now();

    try {
      await Printing.layoutPdf(
        name: '${order.productionOrderCode}_etikete',
        onLayout: (_) => ProductionOrderPdf.buildClassificationLabelsPdf(
          order: order,
          classifications: classifications,
          packagingQty: confirmedQty,
          operatorName: _operatorDisplayName,
          printedAt: printedAt,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  void _openPrintMenu(BuildContext context, ProductionOrderModel order) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  title: Text(
                    'Ispis',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'A4 radni nalog i etikete po klasifikaciji sastavnice',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Radni nalog (A4)'),
                  subtitle: const Text(
                    'Kod, proizvod, količine, BOM/routing, QR s brojem naloga',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _printWorkOrder(order);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_outlined),
                  title: const Text('Etikete — sve klasifikacije'),
                  subtitle: const Text(
                    'Potvrda količine u pakovanju, zatim primarna / sekundarna / transportna (jedan PDF)',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _printClassificationLabels(
                      order,
                      List<String>.from(kBomClassificationCodes),
                    );
                  },
                ),
                ...kBomClassificationCodes.map(
                  (code) => ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text('Etiketa: ${bomClassificationTitleBs(code)}'),
                    subtitle: Text(bomClassificationLogisticsLabelBs(code)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _printClassificationLabels(order, [code]);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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
              onPressed: _loadOrder,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionStatusChip(String status, BuildContext context) {
    final color = _statusColor(status, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildExecutionCard(
    BuildContext context,
    Map<String, dynamic> execution,
  ) {
    final status = (execution['status'] ?? '').toString();
    final operatorName = (execution['operatorName'] ?? '').toString().trim();
    final operatorId = (execution['operatorId'] ?? '').toString().trim();
    final stepName = (execution['stepName'] ?? '').toString().trim();
    final goodQty = (execution['goodQty'] as num?)?.toDouble() ?? 0;
    final scrapQty = (execution['scrapQty'] as num?)?.toDouble() ?? 0;
    final reworkQty = (execution['reworkQty'] as num?)?.toDouble() ?? 0;
    final startedAt = (execution['startedAt'] as Timestamp?)?.toDate();
    final endedAt = (execution['endedAt'] as Timestamp?)?.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  stepName.isEmpty ? '-' : stepName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildExecutionStatusChip(status, context),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Operator',
              operatorName.isNotEmpty ? operatorName : operatorId,
            ),
            _buildInfoRow('Start', _formatDateTime(startedAt)),
            _buildInfoRow('Kraj', _formatDateTime(endedAt)),
            _buildInfoRow('Good qty', _formatQty(goodQty)),
            _buildInfoRow('Scrap qty', _formatQty(scrapQty)),
            _buildInfoRow('Rework qty', _formatQty(reworkQty)),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionSection(
    BuildContext context,
    ProductionOrderModel order,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Execution historija',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '🛈 Isti nalog može imati više execution sesija i više operatora.',
            ),
            if (_hasMyActiveExecutionForStep) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Već imaš aktivan execution za ovaj nalog i ovaj korak. Ne možeš pokrenuti novi dok ga ne završiš.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_canExecute)
              ElevatedButton.icon(
                onPressed: _isLoadingExecutions || _hasMyActiveExecutionForStep
                    ? null
                    : () => _openExecutionScreen(order),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Pokreni rad'),
              ),
            if (_canExecute) const SizedBox(height: 16),
            if (_isLoadingExecutions)
              const Center(child: CircularProgressIndicator())
            else if (_executions.isEmpty)
              const Text('Nema execution zapisa za ovaj nalog.')
            else
              Column(
                children: _executions
                    .map(
                      (execution) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildExecutionCard(context, execution),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProductionOrderModel order) {
    final statusColor = _statusColor(order.status, context);
    final qrData = buildProductionOrderQrPayload(
      companyId: order.companyId,
      plantKey: order.plantKey,
      productionOrderId: order.id,
      productionOrderCode: order.productionOrderCode,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26, width: 1),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: QrImageView(
                    data: qrData,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  order.productionOrderCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
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
                if (order.hasCriticalChanges) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Nalog izmijenjen',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Osnovni podaci',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Šifra proizvoda', order.productCode),
                _buildInfoRow('Naziv proizvoda', order.productName),
                _buildInfoRow(
                  'Planirana količina',
                  '${_formatQty(order.plannedQty)} ${order.unit}',
                ),
                _buildInfoRow(
                  'Rok izrade',
                  _formatDateTime(order.scheduledEndAt),
                ),
                _buildInfoRow(
                  'Proizvedeno dobro',
                  '${_formatQty(order.producedGoodQty)} ${order.unit}',
                ),
                _buildInfoRow(
                  'Proizvedeno škart',
                  '${_formatQty(order.producedScrapQty)} ${order.unit}',
                ),
                _buildInfoRow(
                  'Proizvedeno dorada',
                  '${_formatQty(order.producedReworkQty)} ${order.unit}',
                ),
                _buildInfoRow('Kupac', order.customerName ?? '-'),
                _buildInfoRow('Pogon', order.plantKey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tehničke reference',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('BOM ID', order.bomId),
                _buildInfoRow('BOM verzija', order.bomVersion),
                _buildInfoRow('Routing ID', order.routingId),
                _buildInfoRow('Routing verzija', order.routingVersion),
                _buildInfoRow('Linija', order.lineId ?? '-'),
                _buildInfoRow('Mašina', order.machineId ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Kreirano', _formatDateTime(order.createdAt)),
                _buildInfoRow('Kreirao', order.createdBy),
                _buildInfoRow('Ažurirano', _formatDateTime(order.updatedAt)),
                _buildInfoRow('Ažurirao', order.updatedBy),
                _buildInfoRow('Pušteno', _formatDateTime(order.releasedAt)),
                _buildInfoRow('Pustio', order.releasedBy ?? '-'),
                _buildInfoRow(
                  'Kritične izmjene',
                  order.hasCriticalChanges ? 'Da' : 'Ne',
                ),
                _buildInfoRow(
                  'Zadnja izmjena',
                  _formatDateTime(order.lastChangedAt),
                ),
                _buildInfoRow(
                  'Zadnju izmjenu uradio',
                  order.lastChangedBy ?? '-',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildExecutionSection(context, order),

        if (_canEdit) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductionOrderEditScreen(
                    companyData: widget.companyData,
                    order: order,
                  ),
                ),
              );

              if (result == true) {
                await _loadOrder();
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Izmijeni nalog'),
          ),
        ],

        if (_canRelease && order.status == 'draft') ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isReleasing ? null : _releaseOrder,
            icon: _isReleasing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.publish),
            label: const Text('Pusti nalog'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji proizvodnog naloga'),
        actions: [
          if (_order != null)
            IconButton(
              tooltip: 'Ispis',
              onPressed: () => _openPrintMenu(context, _order!),
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : order == null
          ? const Center(child: Text('Proizvodni nalog nije pronađen.'))
          : _buildContent(context, order),
    );
  }
}

/// Potvrda ili ručni unos količine u pakovanju prije ispisa etiketa.
class _PackagingQtyForLabelDialog extends StatefulWidget {
  final ProductionOrderModel order;
  final double? suggestedFromProduct;

  const _PackagingQtyForLabelDialog({
    required this.order,
    this.suggestedFromProduct,
  });

  @override
  State<_PackagingQtyForLabelDialog> createState() =>
      _PackagingQtyForLabelDialogState();
}

class _PackagingQtyForLabelDialogState
    extends State<_PackagingQtyForLabelDialog> {
  late final TextEditingController _controller;
  String? _error;

  static String _formatInitial(double s) {
    if (s <= 0) return '';
    if (s == s.roundToDouble()) return s.toInt().toString();
    return s.toString();
  }

  @override
  void initState() {
    super.initState();
    final s = widget.suggestedFromProduct;
    _controller = TextEditingController(
      text: s != null && s > 0 ? _formatInitial(s) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final p = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (p == null || p <= 0) {
      setState(() => _error = 'Unesite broj veći od 0.');
      return;
    }
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final hasSuggestion =
        widget.suggestedFromProduct != null &&
        widget.suggestedFromProduct! > 0;

    return AlertDialog(
      title: const Text('Količina za etiketu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasSuggestion
                  ? 'Proizvod ima definisanu količinu pakovanja. Potvrdite je ili '
                      'izmijenite (npr. manje komada u ovom pakovanju).'
                  : 'Količina pakovanja nije postavljena na proizvodu. Unesite '
                      'količinu koja vrijedi za ovu etiketu.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: !hasSuggestion,
              decoration: InputDecoration(
                labelText: 'Količina u pakovanju',
                suffixText: widget.order.unit.isEmpty ? null : widget.order.unit,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Potvrdi i ispiši'),
        ),
      ],
    );
  }
}
