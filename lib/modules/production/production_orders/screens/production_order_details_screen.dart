import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/production_order_model.dart';
import '../services/production_order_service.dart';
import 'production_order_edit_screen.dart';

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

  bool _isLoading = true;
  bool _isReleasing = false;
  String? _error;
  ProductionOrderModel? _order;

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();
  String get _userId => (widget.companyData['userId'] ?? 'system').toString();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().toLowerCase();

  bool get _canEdit => _role == 'admin' || _role == 'production_manager';

  bool get _canRelease => _role == 'admin' || _role == 'production_manager';

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _isLoading = false;
      });
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

  Widget _buildContent(BuildContext context, ProductionOrderModel order) {
    final statusColor = _statusColor(order.status, context);
    final qrData =
        '${order.companyId}|${order.plantKey}|${order.productionOrderCode}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                QrImageView(data: qrData, size: 180),
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

        // ================= EDIT BUTTON =================
        if (_canEdit)
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
      appBar: AppBar(title: const Text('Detalji proizvodnog naloga')),
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
