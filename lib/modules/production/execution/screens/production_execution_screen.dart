import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/production_execution_service.dart';

class ProductionExecutionScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  // order + routing snapshot
  final Map<String, dynamic> orderData;

  // step (minimal MVP)
  final String stepId;
  final String stepName;
  final String executionType;

  const ProductionExecutionScreen({
    super.key,
    required this.companyData,
    required this.orderData,
    required this.stepId,
    required this.stepName,
    required this.executionType,
  });

  @override
  State<ProductionExecutionScreen> createState() =>
      _ProductionExecutionScreenState();
}

class _ProductionExecutionScreenState extends State<ProductionExecutionScreen> {
  final _service = ProductionExecutionService();

  bool _isLoading = false;
  String? _executionId;

  final _goodController = TextEditingController();
  final _scrapController = TextEditingController();
  final _reworkController = TextEditingController();
  final _notesController = TextEditingController();

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();

  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();

  String get _userId => (widget.companyData['userId'] ?? '').toString();

  String get _userName => (widget.companyData['displayName'] ?? '').toString();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().toLowerCase();

  bool get _canExecute => _role == 'production_operator';

  Map<String, dynamic> get _order => widget.orderData;

  double? _parse(String value) {
    return double.tryParse(value.trim());
  }

  Future<void> _start() async {
    if (!_canExecute) {
      _show('Nemaš pravo pokretanja execution-a');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final id = await _service.startExecution(
        companyId: _companyId,
        plantKey: _plantKey,
        productionOrderId: (_order['id'] ?? '').toString(),
        productionOrderCode: (_order['productionOrderCode'] ?? '').toString(),
        productId: (_order['productId'] ?? '').toString(),
        productCode: (_order['productCode'] ?? '').toString(),
        productName: (_order['productName'] ?? '').toString(),
        routingId: (_order['routingId'] ?? '').toString(),
        routingVersion: (_order['routingVersion'] ?? '').toString(),
        stepId: widget.stepId,
        stepName: widget.stepName,
        executionType: widget.executionType,
        operatorId: _userId,
        operatorName: _userName,
        createdBy: _userId,
      );

      setState(() {
        _executionId = id;
      });

      _show('Execution pokrenut');
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pause() async {
    if (_executionId == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.pauseExecution(
        executionId: _executionId!,
        companyId: _companyId,
        plantKey: _plantKey,
        updatedBy: _userId,
        goodQty: _parse(_goodController.text),
        scrapQty: _parse(_scrapController.text),
        reworkQty: _parse(_reworkController.text),
        notes: _notesController.text,
      );

      _show('Execution pauziran');
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resume() async {
    if (_executionId == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.resumeExecution(
        executionId: _executionId!,
        companyId: _companyId,
        plantKey: _plantKey,
        updatedBy: _userId,
      );

      _show('Execution nastavljen');
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _complete() async {
    if (_executionId == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.completeExecution(
        executionId: _executionId!,
        companyId: _companyId,
        plantKey: _plantKey,
        updatedBy: _userId,
        goodQty: _parse(_goodController.text),
        scrapQty: _parse(_scrapController.text),
        reworkQty: _parse(_reworkController.text),
        notes: _notesController.text,
      );

      _show('Execution završen');
      Navigator.pop(context, true);
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  void dispose() {
    _goodController.dispose();
    _scrapController.dispose();
    _reworkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final started = _executionId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Execution')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.stepName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Text('🛈 Tip procesa: ${widget.executionType}'),

            const SizedBox(height: 16),

            _buildField('Good qty', _goodController),
            _buildField('Scrap qty', _scrapController),
            _buildField('Rework qty', _reworkController),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Napomena'),
            ),

            const SizedBox(height: 24),

            if (!started)
              ElevatedButton(
                onPressed: _isLoading ? null : _start,
                child: const Text('Start'),
              ),

            if (started) ...[
              ElevatedButton(
                onPressed: _isLoading ? null : _pause,
                child: const Text('Pause'),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _resume,
                child: const Text('Resume'),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _complete,
                child: const Text('Complete'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
