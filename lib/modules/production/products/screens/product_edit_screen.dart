import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/product_service.dart';

class ProductEditScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final Map<String, dynamic> productData;

  const ProductEditScreen({
    super.key,
    required this.companyData,
    required this.productData,
  });

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  late final TextEditingController _productCodeController;
  late final TextEditingController _productNameController;
  late final TextEditingController _unitController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _customerIdController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _defaultPlantKeyController;
  late final TextEditingController _bomIdController;
  late final TextEditingController _bomVersionController;
  late final TextEditingController _routingIdController;
  late final TextEditingController _routingVersionController;
  late final TextEditingController _secondaryClassCodeController;
  late final TextEditingController _secondaryClassDescController;
  late final TextEditingController _packagingQtyController;
  late final TextEditingController _standardUnitPriceController;
  late final TextEditingController _currencyController;

  bool _isLoading = false;
  late bool _isActive;
  late String _status;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _userId =>
      (widget.companyData['userId'] ?? widget.companyData['uid'] ?? 'system')
          .toString()
          .trim();

  String get _productId =>
      (widget.productData['productId'] ?? '').toString().trim();

  String _s(dynamic value) => (value ?? '').toString().trim();

  String _formatNumForField(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      final d = v.toDouble();
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    return _s(v);
  }

  @override
  void initState() {
    super.initState();

    _productCodeController = TextEditingController(
      text: _s(widget.productData['productCode']),
    );
    _productNameController = TextEditingController(
      text: _s(widget.productData['productName']),
    );
    _unitController = TextEditingController(
      text: _s(widget.productData['unit']),
    );
    _descriptionController = TextEditingController(
      text: _s(widget.productData['description']),
    );
    _customerIdController = TextEditingController(
      text: _s(widget.productData['customerId']),
    );
    _customerNameController = TextEditingController(
      text: _s(widget.productData['customerName']),
    );
    _defaultPlantKeyController = TextEditingController(
      text: _s(widget.productData['defaultPlantKey']),
    );
    _bomIdController = TextEditingController(
      text: _s(widget.productData['bomId']),
    );
    _bomVersionController = TextEditingController(
      text: _s(widget.productData['bomVersion']),
    );
    _routingIdController = TextEditingController(
      text: _s(widget.productData['routingId']),
    );
    _routingVersionController = TextEditingController(
      text: _s(widget.productData['routingVersion']),
    );
    _secondaryClassCodeController = TextEditingController(
      text: _s(widget.productData['secondaryClassificationCode']),
    );
    _secondaryClassDescController = TextEditingController(
      text: _s(widget.productData['secondaryClassificationDescription']),
    );
    _packagingQtyController = TextEditingController(
      text: _formatNumForField(widget.productData['packagingQty']),
    );
    _standardUnitPriceController = TextEditingController(
      text: _formatNumForField(widget.productData['standardUnitPrice']),
    );
    _currencyController = TextEditingController(
      text: _s(widget.productData['currency']).isEmpty
          ? 'KM'
          : _s(widget.productData['currency']),
    );

    _status = _s(widget.productData['status']).isEmpty
        ? 'active'
        : _s(widget.productData['status']).toLowerCase();
    _isActive =
        (widget.productData['isActive'] as bool?) ?? (_status == 'active');
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(labelText: label, hintText: hint);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    double? parseUpdateDouble(String text, {required String label}) {
      final s = text.trim().replaceAll(',', '.');
      if (s.isEmpty) return 0.0;
      final v = double.tryParse(s);
      if (v == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Neispravan broj: $label')));
        return null;
      }
      return v;
    }

    final priceUp = parseUpdateDouble(
      _standardUnitPriceController.text,
      label: 'Jedinična cijena',
    );
    if (priceUp == null) return;

    final packUp = parseUpdateDouble(
      _packagingQtyController.text,
      label: 'Količina pakovanja',
    );
    if (packUp == null) return;

    if (_companyId.isEmpty || _productId.isEmpty || _userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaju obavezni podaci za update.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _productService.updateProduct(
        productId: _productId,
        companyId: _companyId,
        updatedBy: _userId,
        productCode: _productCodeController.text.trim(),
        productName: _productNameController.text.trim(),
        status: _status,
        unit: _unitController.text.trim(),
        description: _descriptionController.text.trim(),
        customerId: _customerIdController.text.trim(),
        customerName: _customerNameController.text.trim(),
        defaultPlantKey: _defaultPlantKeyController.text.trim(),
        bomId: _bomIdController.text.trim(),
        bomVersion: _bomVersionController.text.trim(),
        routingId: _routingIdController.text.trim(),
        routingVersion: _routingVersionController.text.trim(),
        packagingQty: packUp,
        secondaryClassificationCode: _secondaryClassCodeController.text.trim(),
        secondaryClassificationDescription: _secondaryClassDescController.text
            .trim(),
        standardUnitPrice: priceUp,
        currency: _currencyController.text.trim(),
        isActive: _isActive,
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

  @override
  void dispose() {
    _productCodeController.dispose();
    _productNameController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _customerIdController.dispose();
    _customerNameController.dispose();
    _defaultPlantKeyController.dispose();
    _bomIdController.dispose();
    _bomVersionController.dispose();
    _routingIdController.dispose();
    _routingVersionController.dispose();
    _secondaryClassCodeController.dispose();
    _secondaryClassDescController.dispose();
    _packagingQtyController.dispose();
    _standardUnitPriceController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _productId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uredi proizvod')),
        body: const Center(child: Text('Nedostaje companyData ili productId')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Uredi proizvod')),
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
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Šifra proizvoda je obavezna';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productNameController,
                  decoration: _dec('Naziv proizvoda'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Naziv proizvoda je obavezan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: _dec('Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Aktivan')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Neaktivan'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _status = value;
                      _isActive = value == 'active';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  decoration: _dec('Jedinica'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _dec('Opis'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerIdController,
                  decoration: _dec('Customer ID'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerNameController,
                  decoration: _dec('Kupac'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _defaultPlantKeyController,
                  decoration: _dec('Default plantKey'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sekundarna klasifikacija i cijena (lista)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _secondaryClassCodeController,
                  decoration: _dec('Šifra sek. klasifikacije'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secondaryClassDescController,
                  decoration: _dec('Opis sek. klasifikacije'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _packagingQtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec(
                    'Količina pakovanja',
                    hint: 'Prazno = ukloni',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _standardUnitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec('Jedinična cijena', hint: 'Prazno = ukloni'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyController,
                  decoration: _dec('Valuta'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aktivni BOM i Routing',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Privremeno uređivanje direktno na product dokumentu dok ne završimo puni versioned flow.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bomIdController,
                  decoration: _dec('Aktivni BOM ID'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bomVersionController,
                  decoration: _dec('Aktivna BOM verzija'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _routingIdController,
                  decoration: _dec('Aktivni Routing ID'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _routingVersionController,
                  decoration: _dec('Aktivna Routing verzija'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Sačuvaj izmjene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
