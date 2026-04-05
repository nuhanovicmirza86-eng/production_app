import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../products/services/product_lookup_service.dart';
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

  final ProductionOrderService _service = ProductionOrderService();
  final ProductLookupService _productLookupService = ProductLookupService();

  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(
    text: 'pcs',
  );

  DateTime? _scheduledEndAt;

  bool _isLoading = false;

  String? _productId;
  String? _customerId;

  // 🔥 NOVO – snapshot proizvoda
  Map<String, dynamic>? _productData;

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();
  String get _userId => (widget.companyData['userId'] ?? 'system').toString();

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledEndAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        _scheduledEndAt = picked;
      });
    }
  }

  Future<void> _lookupProduct() async {
    final code = _productCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _productId = null;
        _customerId = null;
        _productData = null;
        _productNameController.clear();
        _customerNameController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final product = await _productLookupService.getByCode(
        companyId: _companyId,
        productCode: code,
      );

      if (!mounted) return;

      if (product == null) {
        setState(() {
          _productId = null;
          _customerId = null;
          _productData = null;
          _productNameController.clear();
          _customerNameController.clear();
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Proizvod nije pronađen')));
        return;
      }

      setState(() {
        _productData = product;

        _productId = (product['productId'] ?? '').toString();

        _productNameController.text = (product['productName'] ?? '').toString();

        final productType = (product['productType'] ?? '').toString();

        if (productType == 'single_customer') {
          _customerId = product['defaultCustomerId']?.toString();
          _customerNameController.text = (product['customerName'] ?? '')
              .toString();
        } else {
          _customerId = null;
          _customerNameController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduledEndAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rok izrade je obavezan')));
      return;
    }

    if (_productId == null || _productId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prvo učitaj proizvod po šifri')),
      );
      return;
    }

    if (_productNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naziv proizvoda nije učitan')),
      );
      return;
    }

    if (_productData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaci proizvoda nisu učitani')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _service.createProductionOrder(
        companyId: _companyId,
        plantKey: _plantKey,
        productId: _productId!,
        productCode: _productCodeController.text.trim(),
        productName: _productNameController.text.trim(),
        plannedQty: double.parse(_qtyController.text.trim()),
        unit: _unitController.text.trim(),
        bomId: (_productData!['bomId'] ?? '').toString(),
        bomVersion: (_productData!['bomVersion'] ?? '').toString(),
        routingId: (_productData!['routingId'] ?? '').toString(),
        routingVersion: (_productData!['routingVersion'] ?? '').toString(),
        createdBy: _userId,
        scheduledEndAt: _scheduledEndAt!,
        customerId: _customerId,
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
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

      setState(() {
        _isLoading = false;
      });
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
    _productCodeController.dispose();
    _productNameController.dispose();
    _customerNameController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kreiranje proizvodnog naloga')),
        body: const Center(child: Text('Nedostaje companyData')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kreiranje proizvodnog naloga')),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _productCodeController,
                  decoration: _dec('Šifra proizvoda'),
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _lookupProduct(),
                  onChanged: (_) {
                    _productId = null;
                    _customerId = null;
                    _productData = null;
                    _productNameController.clear();
                    _customerNameController.clear();
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Obavezno polje';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _lookupProduct,
                  icon: const Icon(Icons.search),
                  label: const Text('Učitaj proizvod'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productNameController,
                  decoration: _dec('Naziv proizvoda'),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Prvo učitaj proizvod po šifri';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerNameController,
                  decoration: _dec('Kupac'),
                  readOnly: _customerId != null && _customerId!.isNotEmpty,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtyController,
                  decoration: _dec('Planirana količina'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Obavezno polje';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Neispravan broj';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  decoration: _dec('Jedinica'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _dec('Rok izrade'),
                    child: Text(
                      _scheduledEndAt == null
                          ? 'Odaberi datum'
                          : '${_scheduledEndAt!.day}.${_scheduledEndAt!.month}.${_scheduledEndAt!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _createOrder,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Kreiraj nalog'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
