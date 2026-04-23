import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../ooe/models/ooe_loss_reason.dart';
import '../../ooe/services/ooe_loss_reason_service.dart';
import '../services/production_execution_service.dart';

class ProductionExecutionScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  // order + routing snapshot
  final Map<String, dynamic> orderData;

  // step (minimal MVP)
  final String stepId;
  final String stepName;
  final String executionType;

  /// Nastavak postojeće sesije (started/paused) umjesto novog Start-a.
  final String? resumeExecutionId;

  const ProductionExecutionScreen({
    super.key,
    required this.companyData,
    required this.orderData,
    required this.stepId,
    required this.stepName,
    required this.executionType,
    this.resumeExecutionId,
  });

  @override
  State<ProductionExecutionScreen> createState() =>
      _ProductionExecutionScreenState();
}

class _ProductionExecutionScreenState extends State<ProductionExecutionScreen> {
  final _service = ProductionExecutionService();
  final _ooeLossReasonService = OoeLossReasonService();

  /// Šifra iz `ooe_loss_reasons`; prazno = pauza bez MES/OOE razloga.
  String _pauseOoeReasonCode = '';

  bool _isLoading = false;
  bool _initializingResume = false;
  String? _executionId;

  final _goodController = TextEditingController();
  final _scrapController = TextEditingController();
  final _reworkController = TextEditingController();
  final _notesController = TextEditingController();

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();

  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();

  String get _userId => (widget.companyData['userId'] ?? '').toString();

  String get _userName {
    final a = (widget.companyData['userDisplayName'] ?? '').toString().trim();
    if (a.isNotEmpty) return a;
    final b = (widget.companyData['nickname'] ?? '').toString().trim();
    if (b.isNotEmpty) return b;
    return (widget.companyData['displayName'] ?? '').toString().trim();
  }

  String get _role =>
      (widget.companyData['role'] ?? '').toString().toLowerCase();

  bool get _canMutateExecution =>
      _role == 'production_operator' ||
      _role == 'supervisor' ||
      _role == 'production_manager' ||
      _role == 'admin';

  Map<String, dynamic> get _order => widget.orderData;

  double? _parse(String value) {
    return double.tryParse(value.trim());
  }

  static String _formatQtyField(dynamic v) {
    if (v is! num) return '';
    final d = v.toDouble();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }

  @override
  void initState() {
    super.initState();
    final r = widget.resumeExecutionId?.trim();
    if (r != null && r.isNotEmpty) {
      _initializingResume = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryLoadResumeExecution(r);
      });
    }
  }

  Future<void> _tryLoadResumeExecution(String rid) async {
    try {
      final doc = await _service.getById(
        executionId: rid,
        companyId: _companyId,
        plantKey: _plantKey,
      );
      if (!mounted) return;
      if (doc == null) {
        _show('Sesija rada nije pronađena.');
        return;
      }
      final st = (doc['status'] ?? '').toString().toLowerCase();
      if (st == 'completed') {
        _show('Ova sesija je već završena.');
        return;
      }
      setState(() {
        _executionId = rid;
        _goodController.text = _formatQtyField(doc['goodQty']);
        _scrapController.text = _formatQtyField(doc['scrapQty']);
        _reworkController.text = _formatQtyField(doc['reworkQty']);
        _notesController.text = (doc['notes'] ?? '').toString();
      });
    } catch (e) {
      if (mounted) _show(AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _initializingResume = false);
    }
  }

  Future<void> _start() async {
    if (!_canMutateExecution) {
      _show('Nemaš pravo pokretanja izvršenja.');
      return;
    }

    final st = (_order['status'] ?? '').toString().toLowerCase();
    if (st != 'released' && st != 'in_progress') {
      _show('Nalog mora biti pušten ili u toku da bi se pokrenuo rad.');
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
        operatorName: _userName.isEmpty ? null : _userName,
        createdBy: _userId,
      );

      setState(() {
        _executionId = id;
      });

      _show('Rad je pokrenut');
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pause() async {
    if (!_canMutateExecution) return;
    if (_executionId == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.pauseExecution(
        executionId: _executionId!,
        companyId: _companyId,
        plantKey: _plantKey,
        updatedBy: _userId,
        ooePauseReasonCode: _pauseOoeReasonCode.trim().isEmpty
            ? null
            : _pauseOoeReasonCode.trim(),
        goodQty: _parse(_goodController.text),
        scrapQty: _parse(_scrapController.text),
        reworkQty: _parse(_reworkController.text),
        notes: _notesController.text,
      );

      _show('Pauzirano');
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resume() async {
    if (!_canMutateExecution) return;
    if (_executionId == null) return;

    setState(() => _isLoading = true);

    try {
      await _service.resumeExecution(
        executionId: _executionId!,
        companyId: _companyId,
        plantKey: _plantKey,
        updatedBy: _userId,
      );

      _show('Nastavljeno');
    } catch (e) {
      _show(AppErrorMapper.toMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _complete() async {
    if (!_canMutateExecution) return;
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

      _show('Sesija završena');
      if (mounted) Navigator.pop(context, true);
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    if (_initializingResume) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final started = _executionId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Izvršenje proizvodnje')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              widget.stepName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              (_order['productName'] ?? '').toString().trim().isEmpty
                  ? 'Proizvod'
                  : (_order['productName'] ?? '').toString(),
              style:
                  Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ) ??
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              (_order['customerName'] ?? '').toString().trim().isEmpty
                  ? 'Kupac nije naveden'
                  : (_order['customerName'] ?? '').toString().trim(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Šifra: ${(_order['productCode'] ?? '').toString()}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 4),
            Text(
              'Referenca naloga: ${(_order['productionOrderCode'] ?? '').toString()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip procesa: ${widget.executionType}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),

            const SizedBox(height: 20),

            _buildField('Dobra količina', _goodController),
            _buildField('Škart', _scrapController),
            _buildField('Dorada', _reworkController),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Napomena'),
            ),

            const SizedBox(height: 24),

            if (!started)
              ElevatedButton(
                onPressed: (_isLoading || !_canMutateExecution) ? null : _start,
                child: const Text('Start'),
              ),

            if (started) ...[
              StreamBuilder<List<OoeLossReason>>(
                stream: _ooeLossReasonService.watchActiveReasons(
                  companyId: _companyId,
                  plantKey: _plantKey,
                ),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        AppErrorMapper.toMessage(snap.error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }
                  final reasons = snap.data ?? const <OoeLossReason>[];
                  if (reasons.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Nema aktivnih OOE razloga u katalogu — dodaj ih u OOE katalogu.',
                        style: TextStyle(fontSize: 13),
                      ),
                    );
                  }
                  final validValue = _pauseOoeReasonCode.isEmpty
                      ? ''
                      : (reasons.any((r) => r.code == _pauseOoeReasonCode)
                          ? _pauseOoeReasonCode
                          : '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Razlog pauze (OOE, opcionalno)',
                        helperText:
                            'Isti kod kao u katalogu razloga; za TPM/Pareto i segment stanja.',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: validValue,
                          items: <DropdownMenuItem<String>>[
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('— bez OOE kategorije'),
                            ),
                            ...reasons.map(
                              (r) => DropdownMenuItem<String>(
                                value: r.code,
                                child: Text('${r.code} — ${r.name}'),
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (v) {
                                  setState(
                                    () => _pauseOoeReasonCode = v ?? '',
                                  );
                                },
                        ),
                      ),
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _pause,
                child: const Text('Pauza'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _resume,
                child: const Text('Nastavi'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _complete,
                child: const Text('Završi sesiju'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
