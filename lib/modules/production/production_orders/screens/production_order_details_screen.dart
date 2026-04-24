import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/user_display_label.dart';
import '../../execution/screens/production_execution_screen.dart';
import '../../execution/services/production_execution_service.dart';
import '../../ooe/ooe_help_texts.dart';
import '../../ooe/services/machine_state_service.dart';
import '../../ooe/widgets/ooe_info_icon.dart';
import '../../ooe/widgets/ooe_timeline_widget.dart';
import '../../products/services/product_service.dart';
import '../models/production_order_model.dart';
import '../printing/bom_classification_catalog.dart';
import '../../../commercial/orders/services/company_print_identity_service.dart';
import '../printing/production_order_pdf.dart';
import '../printing/production_order_qr_payload.dart';
import '../services/production_order_service.dart';
import '../../work_centers/screens/work_center_details_screen.dart';
import 'production_order_edit_screen.dart';
import 'production_order_mes_assignment_screen.dart';

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
  final MachineStateService _ooeMachineStateService = MachineStateService();
  final ProductService _productService = ProductService();

  bool _isLoading = true;
  bool _isReleasing = false;
  bool _isLifecycleBusy = false;
  bool _isLoadingExecutions = false;
  String? _error;
  ProductionOrderModel? _order;

  List<Map<String, dynamic>> _executions = const [];
  bool _hasMyActiveExecutionForStep = false;

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();
  String get _userId => (widget.companyData['userId'] ?? 'system').toString();

  /// Ime za etikete / ispis (nikad sirovi UID u UI).
  String get _operatorDisplayName =>
      UserDisplayLabel.fromSessionMap(widget.companyData);

  String get _role =>
      (widget.companyData['role'] ?? '').toString().toLowerCase();

  bool get _canEdit => _role == 'admin' || _role == 'production_manager';

  bool get _canRelease => _role == 'admin' || _role == 'production_manager';

  bool get _canManageLifecycle =>
      _role == 'admin' || _role == 'production_manager';

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
        if (mounted) await _prefetchActorLabels(order);
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

  Future<void> _prefetchActorLabels(ProductionOrderModel order) async {
    final fs = FirebaseFirestore.instance;
    final ids = <String>{};

    void collect(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty || s == '-') return;
      if (s.contains('@')) return;
      if (!UserDisplayLabel.looksLikeFirebaseUid(s)) return;
      ids.add(s);
    }

    collect(order.createdBy);
    collect(order.updatedBy);
    collect(order.releasedBy);
    collect(order.lastChangedBy);

    for (final e in _executions) {
      final name = (e['operatorName'] ?? '').toString().trim();
      if (name.isEmpty) collect((e['operatorId'] ?? '').toString());
    }

    await UserDisplayLabel.prefetchUids(fs, ids);
    if (mounted) setState(() {});
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
      if (mounted) {
        setState(() {
          _isReleasing = false;
        });
      }
    }
  }

  String? _resumeExecutionIdForMyStep() {
    for (final e in _executions) {
      final st = (e['status'] ?? '').toString().toLowerCase();
      if (st != 'started' && st != 'paused') continue;
      if ((e['stepId'] ?? '').toString() != _defaultStepId) continue;
      if ((e['operatorId'] ?? '').toString().trim() != _userId.trim()) continue;
      final id = (e['id'] ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> _openExecutionScreen(
    ProductionOrderModel order, {
    String? resumeExecutionId,
  }) async {
    final canRunWork =
        order.status == 'released' || order.status == 'in_progress';

    if (resumeExecutionId == null || resumeExecutionId.isEmpty) {
      if (!canRunWork) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nalog mora biti pušten prije pokretanja rada (status: nacrt → pusti nalog).',
            ),
          ),
        );
        return;
      }
      if (_hasMyActiveExecutionForStep) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Već imaš aktivan rad za ovaj korak — koristi „Nastavi rad“.',
            ),
          ),
        );
        return;
      }
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionExecutionScreen(
          companyData: widget.companyData,
          orderData: {
            'id': order.id,
            'status': order.status,
            'productionOrderCode': order.productionOrderCode,
            'productId': order.productId,
            'productCode': order.productCode,
            'productName': order.productName,
            'customerName': order.customerName ?? '',
            'routingId': order.routingId,
            'routingVersion': order.routingVersion,
            'workCenterId': order.workCenterId ?? '',
            'workCenterCode': order.workCenterCode ?? '',
            'workCenterName': order.workCenterName ?? '',
            'machineId': order.machineId ?? '',
          },
          stepId: _defaultStepId,
          stepName: _defaultStepName,
          executionType: _defaultExecutionType,
          resumeExecutionId: resumeExecutionId,
        ),
      ),
    );

    if (result == true) {
      await _loadOrder();
    }
  }

  Future<void> _confirmCompleteOrder(ProductionOrderModel order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Završi nalog'),
        content: const Text(
          'Nalog će dobiti status „Završen“. Nastavak izvršenja i dalje je moguć po potrebi; zatvaranje je odvojen korak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Završi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLifecycleBusy = true);
    try {
      await _service.completeProductionOrder(
        productionOrderId: order.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUserId: _userId,
      );
      if (!mounted) return;
      await _loadOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nalog je označen kao završen.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _isLifecycleBusy = false);
    }
  }

  Future<void> _confirmCloseOrder(ProductionOrderModel order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zatvori nalog'),
        content: const Text(
          'Zatvoreni nalog se smatra arhiviranim za operativu. Nastavak izmjena treba biti izuzetak (admin).',
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
    if (ok != true || !mounted) return;
    setState(() => _isLifecycleBusy = true);
    try {
      await _service.closeProductionOrder(
        productionOrderId: order.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUserId: _userId,
      );
      if (!mounted) return;
      await _loadOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nalog je zatvoren.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _isLifecycleBusy = false);
    }
  }

  Future<void> _confirmCancelOrder(ProductionOrderModel order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkaži nalog'),
        content: const Text(
          'Otkazani nalog više nije dio aktivnog plana. Jeste li sigurni?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Otkaži nalog'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _isLifecycleBusy = true);
    try {
      await _service.cancelProductionOrder(
        productionOrderId: order.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUserId: _userId,
      );
      if (!mounted) return;
      await _loadOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nalog je otkazan.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _isLifecycleBusy = false);
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
      CompanyPrintIdentity? printIdentity;
      final cid = _companyId.trim();
      if (cid.isNotEmpty) {
        printIdentity = await CompanyPrintIdentityService().load(
          companyId: cid,
          companyData: widget.companyData,
        );
      }
      await Printing.layoutPdf(
        name: order.productionOrderCode,
        onLayout: (_) => ProductionOrderPdf.buildWorkOrderPdf(
          order: order,
          printedAt: DateTime.now(),
          printIdentity: printIdentity,
          companyData: widget.companyData,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
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
        color: color.withValues(alpha: 0.12),
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
              operatorName.isNotEmpty
                  ? operatorName
                  : UserDisplayLabel.labelForStored(operatorId),
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
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Imaš aktivnu sesiju rada za ovaj korak. Nastavi je ili je završi na ekranu izvršenja.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Builder(
              builder: (ctx) {
                final canRunWork =
                    order.status == 'released' || order.status == 'in_progress';
                final resumeId = _resumeExecutionIdForMyStep();
                if (!_canExecute) return const SizedBox.shrink();
                if (!canRunWork) {
                  return Text(
                    order.status == 'draft'
                        ? 'Pušti nalog prije pokretanja rada.'
                        : 'Rad se može pokrenuti samo za puštene naloge ili naloge u toku.',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasMyActiveExecutionForStep && resumeId != null) ...[
                      ElevatedButton.icon(
                        onPressed: _isLoadingExecutions
                            ? null
                            : () => _openExecutionScreen(
                                order,
                                resumeExecutionId: resumeId,
                              ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Nastavi rad'),
                      ),
                    ] else if (!_hasMyActiveExecutionForStep) ...[
                      ElevatedButton.icon(
                        onPressed: _isLoadingExecutions
                            ? null
                            : () => _openExecutionScreen(order),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Pokreni rad'),
                      ),
                    ],
                  ],
                );
              },
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26, width: 1),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: QrImageView(
                        data: qrData,
                        size: 132,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ) ??
                                const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (order.customerName ?? '').trim().isEmpty
                                ? 'Kupac nije naveden'
                                : order.customerName!.trim(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Šifra: ${order.productCode}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Referenca naloga: ${order.productionOrderCode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
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
                    if (order.hasCriticalChanges)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
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
                ),
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
                _buildInfoRow('Naziv proizvoda', order.productName),
                _buildInfoRow(
                  'Kupac',
                  (order.customerName ?? '').trim().isEmpty
                      ? '—'
                      : order.customerName!.trim(),
                ),
                _buildInfoRow('Šifra proizvoda', order.productCode),
                _buildInfoRow(
                  'Lot materijala (šarža)',
                  (order.inputMaterialLot ?? '').trim().isEmpty
                      ? '—'
                      : order.inputMaterialLot!.trim(),
                ),
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
                _buildInfoRow('Pogon', order.plantKey),
                if ((order.workCenterCode ?? '').trim().isNotEmpty ||
                    (order.workCenterName ?? '').trim().isNotEmpty)
                  _buildInfoRow(
                    'Radni centar',
                    [
                      (order.workCenterCode ?? '').trim(),
                      (order.workCenterName ?? '').trim(),
                    ].where((s) => s.isNotEmpty).join(' — '),
                  )
                else
                  _buildInfoRow('Radni centar', '—'),
              ],
            ),
          ),
        ),
        if (_canManageLifecycle &&
            order.status != 'closed' &&
            order.status != 'cancelled') ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => ProductionOrderMesAssignmentScreen(
                      companyData: widget.companyData,
                      order: order,
                    ),
                  ),
                );
                if (ok == true && mounted) await _loadOrder();
              },
              icon: const Icon(Icons.precision_manufacturing_outlined),
              label: const Text('Postavi radni centar / resurse'),
            ),
          ),
        ],
        if ((order.workCenterId ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WorkCenterDetailsScreen(
                      companyData: widget.companyData,
                      workCenterId: order.workCenterId!.trim(),
                      plantKey: _plantKey,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Otvori karticu radnog centra'),
            ),
          ),
        ],
        if (order.status == 'released' ||
            order.status == 'in_progress' ||
            order.status == 'completed') ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'OOE — segmenti stanja',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OoeInfoIcon(
                        tooltip: OoeHelpTexts.orderDetailsOoeTooltip,
                        dialogTitle: OoeHelpTexts.orderDetailsOoeTitle,
                        dialogBody: OoeHelpTexts.orderDetailsOoeBody,
                        iconSize: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: _ooeMachineStateService.watchEventsForOrder(
                      companyId: _companyId,
                      plantKey: _plantKey,
                      orderId: order.id,
                      limit: 20,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'OOE podaci trenutno nisu dostupni (${snapshot.error}).',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final events = snapshot.data!;
                      if (events.isEmpty) {
                        return Text(
                          'Nema segmenata',
                          style: TextStyle(color: Colors.grey.shade700),
                        );
                      }
                      return OoeTimelineWidget(events: events);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: const Text(
                'Tehnički podaci (BOM / linija)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'ID-evi u bazi — nisu potrebni za rad; otvori samo ako trebaš podršci',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _buildInfoRow('BOM ID', order.bomId),
                _buildInfoRow('BOM verzija', order.bomVersion),
                _buildInfoRow('Routing ID', order.routingId),
                _buildInfoRow('Routing verzija', order.routingVersion),
                _buildInfoRow('Linija', order.lineId ?? '-'),
                _buildInfoRow('Radni centar ID', order.workCenterId ?? '-'),
                _buildInfoRow('Radni centar šifra', order.workCenterCode ?? '-'),
                _buildInfoRow('Radni centar naziv', order.workCenterName ?? '-'),
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
                _buildInfoRow(
                  'Kreirao',
                  UserDisplayLabel.labelForStored(order.createdBy),
                ),
                _buildInfoRow('Ažurirano', _formatDateTime(order.updatedAt)),
                _buildInfoRow(
                  'Ažurirao',
                  UserDisplayLabel.labelForStored(order.updatedBy),
                ),
                _buildInfoRow('Pušteno', _formatDateTime(order.releasedAt)),
                _buildInfoRow(
                  'Pustio',
                  UserDisplayLabel.labelForStored(order.releasedBy ?? ''),
                ),
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
                  UserDisplayLabel.labelForStored(order.lastChangedBy ?? ''),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildExecutionSection(context, order),

        if (_canManageLifecycle) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Životni ciklus naloga',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Završi kada je proizvodnja operativno gotova; zatvori nakon knjiženja / revizije.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  if (order.status == 'released' ||
                      order.status == 'in_progress') ...[
                    OutlinedButton.icon(
                      onPressed: _isLifecycleBusy
                          ? null
                          : () => _confirmCompleteOrder(order),
                      icon: const Icon(Icons.done_all_outlined),
                      label: const Text('Završi nalog'),
                    ),
                  ],
                  if (order.status == 'completed') ...[
                    OutlinedButton.icon(
                      onPressed: _isLifecycleBusy
                          ? null
                          : () => _confirmCloseOrder(order),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Zatvori nalog'),
                    ),
                  ],
                  if (![
                    'completed',
                    'closed',
                    'cancelled',
                  ].contains(order.status)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isLifecycleBusy
                          ? null
                          : () => _confirmCancelOrder(order),
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: Colors.red.shade700,
                      ),
                      label: Text(
                        'Otkaži nalog',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

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
        widget.suggestedFromProduct != null && widget.suggestedFromProduct! > 0;

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
                suffixText: widget.order.unit.isEmpty
                    ? null
                    : widget.order.unit,
                errorText: _error,
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
        FilledButton(onPressed: _submit, child: const Text('Potvrdi i ispiši')),
      ],
    );
  }
}
