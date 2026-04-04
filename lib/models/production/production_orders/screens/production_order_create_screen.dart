// lib/modules/production/production_orders/screens/production_order_create_screen.dart

import 'package:flutter/material.dart';
import '../services/production_order_service.dart';

class ProductionOrderCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionOrderCreateScreen({super.key, required this.companyData});

  @override
  State<ProductionOrderCreateScreen> createState() =>
      _ProductionOrderCreateScreenState();
}

class _ProductionOrderCreateScreenState
    extends State<ProductionOrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _service = ProductionOrderService();

  final _codeController = TextEditingController();
  final _productCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _qtyController = TextEditingController();

  final _unitController = TextEditingController(text: 'pcs');

  bool _isLoading = false;

  String get _companyId => widget.companyData['companyId'] ?? '';
  String get _plantKey => widget.companyData['plantKey'] ?? '';
  String get _userId => widget.companyData['userId'] ?? 'system';

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _service.createProductionOrder(
        companyId: _companyId,
        plantKey: _plantKey,
        productionOrderCode: _codeController.text.trim(),
        productId: _productCodeController.text.trim(),
        productCode: _productCodeController.text.trim(),
        productName: _productNameController.text.trim(),
        plannedQty: double.parse(_qtyController.text),
        unit: _unitController.text.trim(),
        bomId: 'TEMP_BOM',
        bomVersion: 'v1',
        routingId: 'TEMP_ROUTING',
        routingVersion: 'v1',
        createdBy: _userId,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Greška pri kreiranju naloga')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _productCodeController.dispose();
    _productNameController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Production Order')),
        body: const Center(child: Text('Nedostaje companyData')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Production Order')),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: _dec('Order Code'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Obavezno polje' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productCodeController,
                  decoration: _dec('Product Code'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Obavezno polje' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productNameController,
                  decoration: _dec('Product Name'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Obavezno polje' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtyController,
                  decoration: _dec('Planned Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obavezno polje';
                    if (double.tryParse(v) == null) {
                      return 'Neispravan broj';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  decoration: _dec('Unit'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _createOrder,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create Order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
