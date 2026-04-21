import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/partner_models.dart';
import '../services/supplier_evaluations_service.dart';

class SupplierEvaluationsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final SupplierModel supplier;

  const SupplierEvaluationsScreen({
    super.key,
    required this.companyData,
    required this.supplier,
  });

  @override
  State<SupplierEvaluationsScreen> createState() =>
      _SupplierEvaluationsScreenState();
}

class _SupplierEvaluationsScreenState extends State<SupplierEvaluationsScreen> {
  final SupplierEvaluationsService _service = SupplierEvaluationsService();
  final _formKey = GlobalKey<FormState>();

  final _periodController = TextEditingController();
  final _qualityController = TextEditingController(text: '0');
  final _deliveryController = TextEditingController(text: '0');
  final _responseController = TextEditingController(text: '0');
  final _complianceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<SupplierEvaluationModel> _evaluations = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canEvaluate =>
      _role == 'admin' ||
      _role == 'production_manager' ||
      _role == 'purchasing' ||
      _role == 'supervisor';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    _periodController.text = '${now.year}-Q$q';
    _load();
  }

  @override
  void dispose() {
    _periodController.dispose();
    _qualityController.dispose();
    _deliveryController.dispose();
    _responseController.dispose();
    _complianceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.listForSupplier(
        companyId: _companyId,
        supplierId: widget.supplier.id,
      );
      if (!mounted) return;
      setState(() {
        _evaluations = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  double _parseRating(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.')) ?? -1;
    if (v < 0 || v > 100) {
      throw Exception('Ocjene moraju biti u rasponu 0-100.');
    }
    return v;
  }

  Future<void> _createEvaluation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quality = _parseRating(_qualityController);
      final delivery = _parseRating(_deliveryController);
      final response = _parseRating(_responseController);
      final compliance = _parseRating(_complianceController);

      await _service.createEvaluation(
        companyData: widget.companyData,
        supplierId: widget.supplier.id,
        supplierCode: widget.supplier.code,
        supplierName: widget.supplier.name,
        periodKey: _periodController.text.trim(),
        qualityRating: quality,
        deliveryRating: delivery,
        responseRating: response,
        complianceRating: compliance,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      _notesController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _scoreTag(double score) {
    final risk = SupplierEvaluationsService.riskLevelFromScore(score);
    final approval = SupplierEvaluationsService.approvalStatusFromScore(score);
    return 'Score: ${score.toStringAsFixed(1)} • Risk: $risk • Status: $approval';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluacija: ${widget.supplier.code}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saving) const LinearProgressIndicator(minHeight: 2),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.supplier.code} — ${widget.supplier.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trenutno: ${_scoreTag(widget.supplier.overallScore)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova evaluacija (IATF scorecard)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _periodController,
                      decoration: const InputDecoration(
                        labelText: 'Period (npr. 2026-Q2)',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Obavezno' : null,
                    ),
                    const SizedBox(height: 10),
                    _ratingField(_qualityController, 'Quality rating (0-100)'),
                    const SizedBox(height: 10),
                    _ratingField(
                      _deliveryController,
                      'Delivery rating (0-100)',
                    ),
                    const SizedBox(height: 10),
                    _ratingField(
                      _responseController,
                      'Response rating (0-100)',
                    ),
                    const SizedBox(height: 10),
                    _ratingField(
                      _complianceController,
                      'Compliance rating (0-100)',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Napomena'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: (!_canEvaluate || _saving)
                          ? null
                          : _createEvaluation,
                      icon: const Icon(Icons.assessment_outlined),
                      label: const Text('Snimi evaluaciju'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_evaluations.isEmpty)
            const Text('Nema evaluacija za ovog dobavljača.')
          else
            ..._evaluations.map(
              (e) => Card(
                child: ListTile(
                  title: Text(
                    '${e.periodKey} • ${e.overallScore.toStringAsFixed(1)}',
                  ),
                  subtitle: Text(
                    'Q:${e.qualityRating.toStringAsFixed(1)} '
                    'D:${e.deliveryRating.toStringAsFixed(1)} '
                    'R:${e.responseRating.toStringAsFixed(1)} '
                    'C:${e.complianceRating.toStringAsFixed(1)}\n'
                    'Risk: ${e.riskLevel} • Status: ${e.approvalStatus}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ratingField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
        if (n == null) return 'Unesi broj';
        if (n < 0 || n > 100) return 'Raspon 0-100';
        return null;
      },
    );
  }
}
