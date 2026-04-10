import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/production_order_model.dart';
import '../services/production_order_service.dart';

class ProductionOrderEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final ProductionOrderModel order;

  const ProductionOrderEditScreen({
    super.key,
    required this.companyData,
    required this.order,
  });

  @override
  State<ProductionOrderEditScreen> createState() =>
      _ProductionOrderEditScreenState();
}

class _ProductionOrderEditScreenState extends State<ProductionOrderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductionOrderService();

  late TextEditingController _qtyController;
  late TextEditingController _reasonController;

  DateTime? _scheduledEndAt;
  bool _isSaving = false;

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();

  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();

  String get _userId => (widget.companyData['userId'] ?? '').toString();

  String get _userRole => (widget.companyData['role'] ?? '').toString();

  @override
  void initState() {
    super.initState();

    _qtyController = TextEditingController(
      text: widget.order.plannedQty.toString(),
    );
    _reasonController = TextEditingController();
    _scheduledEndAt = widget.order.scheduledEndAt;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledEndAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledEndAt ?? now),
    );

    if (time == null) return;

    setState(() {
      _scheduledEndAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final plannedQty = double.tryParse(_qtyController.text.trim());
    final reason = _reasonController.text.trim();

    if (plannedQty == null || _scheduledEndAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Neispravni podaci')));
      return;
    }

    final originalQty = widget.order.plannedQty;
    final originalDate = widget.order.scheduledEndAt;

    final hasChanges =
        plannedQty != originalQty || _scheduledEndAt != originalDate;

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema izmjena za spremanje')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _service.updateProductionOrder(
        productionOrderId: widget.order.id,
        companyId: _companyId,
        plantKey: _plantKey,
        actorUserId: _userId,
        actorRole: _userRole,
        plannedQty: plannedQty,
        scheduledEndAt: _scheduledEndAt,
        changeReason: reason,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';

    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.order.status;
    if (st == 'completed' || st == 'closed' || st == 'cancelled') {
      return Scaffold(
        appBar: AppBar(title: const Text('Izmjena naloga')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Kritične izmjene (plan / rok) nisu dozvoljene za nalog u statusu '
              '„$st“.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Izmjena naloga')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Kritične izmjene',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '🛈 Izmjena količine ili roka izrade će biti auditirana.',
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Planirana količina',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obavezno polje';
                  if (double.tryParse(v) == null) return 'Neispravan broj';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              ListTile(
                title: const Text('Rok izrade'),
                subtitle: Text(_formatDateTime(_scheduledEndAt)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDateTime,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Razlog izmjene'),
                maxLines: 3,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Razlog je obavezan';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Sačuvaj izmjene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
