import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../logistics/wms/wms_scan_helpers.dart';
import '../services/product_service.dart';

class ProductCreateScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Jedan ili više vanjskih kodova (EAN, QR sadržaj) vezanih uz ovaj proizvod.
  final List<String>? initialScanAliases;

  const ProductCreateScreen({
    super.key,
    required this.companyData,
    this.initialScanAliases,
  });

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(
    text: 'pcs',
  );
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _defaultPlantKeyController =
      TextEditingController();
  final TextEditingController _bomIdController = TextEditingController();
  final TextEditingController _bomVersionController = TextEditingController();
  final TextEditingController _routingIdController = TextEditingController();
  final TextEditingController _routingVersionController =
      TextEditingController();
  final TextEditingController _secondaryClassCodeController =
      TextEditingController();
  final TextEditingController _secondaryClassDescController =
      TextEditingController();
  final TextEditingController _packagingQtyController = TextEditingController();
  final TextEditingController _standardUnitPriceController =
      TextEditingController();
  final TextEditingController _currencyController = TextEditingController(
    text: 'KM',
  );
  final TextEditingController _externalScanController =
      TextEditingController();

  bool _isLoading = false;
  bool _isActive = true;
  String _status = 'active';

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();
  String get _userId =>
      (widget.companyData['userId'] ?? widget.companyData['uid'] ?? 'system')
          .toString()
          .trim();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialScanAliases;
    if (initial != null && initial.isNotEmpty) {
      _externalScanController.text = initial.first.trim();
    }
  }

  Future<void> _scanExternalCode() async {
    final raw = await wmsScanBarcodeRaw(
      context,
      companyData: widget.companyData,
    );
    if (!mounted || raw == null || raw.isEmpty) return;
    setState(() => _externalScanController.text = raw);
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(labelText: label, hintText: hint);
  }

  double? _optionalPositiveDouble(String text) {
    final s = text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  double? _optionalUnitPrice(String text) {
    final s = text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje companyData.companyId')),
      );
      return;
    }

    if (_userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nedostaje userId')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scanAliases = _externalScanController.text.trim().isEmpty
          ? null
          : [_externalScanController.text.trim()];

      await _productService.createProduct(
        companyId: _companyId,
        productCode: _productCodeController.text.trim(),
        productName: _productNameController.text.trim(),
        createdBy: _userId,
        status: _status,
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        customerId: _customerIdController.text.trim().isEmpty
            ? null
            : _customerIdController.text.trim(),
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        defaultPlantKey: _defaultPlantKeyController.text.trim().isEmpty
            ? (_plantKey.isEmpty ? null : _plantKey)
            : _defaultPlantKeyController.text.trim(),
        bomId: _bomIdController.text.trim().isEmpty
            ? null
            : _bomIdController.text.trim(),
        bomVersion: _bomVersionController.text.trim().isEmpty
            ? null
            : _bomVersionController.text.trim(),
        routingId: _routingIdController.text.trim().isEmpty
            ? null
            : _routingIdController.text.trim(),
        routingVersion: _routingVersionController.text.trim().isEmpty
            ? null
            : _routingVersionController.text.trim(),
        packagingQty: _optionalPositiveDouble(_packagingQtyController.text),
        secondaryClassificationCode:
            _secondaryClassCodeController.text.trim().isEmpty
            ? null
            : _secondaryClassCodeController.text.trim(),
        secondaryClassificationDescription:
            _secondaryClassDescController.text.trim().isEmpty
            ? null
            : _secondaryClassDescController.text.trim(),
        standardUnitPrice: _optionalUnitPrice(
          _standardUnitPriceController.text,
        ),
        currency: _currencyController.text.trim().isEmpty
            ? null
            : _currencyController.text.trim(),
        isActive: _isActive,
        scanAliases: scanAliases,
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
    _externalScanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Novi proizvod')),
        body: const Center(child: Text('Nedostaje companyData')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Novi proizvod')),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Vanjski barkod / QR (postojeći)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Operonix interna šifra može ostati GK/PP…; ovdje vežeš stvarnu '
                  'etiketu s linije da skeniranje u prijemu pronalazi proizvod.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _externalScanController,
                        decoration: _dec(
                          'Sadržaj etikete',
                          hint: 'EAN, QR ili interni kod',
                        ),
                        maxLines: 2,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Skeniraj',
                      onPressed: _isLoading ? null : _scanExternalCode,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _productCodeController,
                  decoration: _dec(
                    'Šifra proizvoda',
                    hint: 'Obavezno, mora biti jedinstvena',
                  ),
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
                  decoration: _dec(
                    'Default plantKey',
                    hint: _plantKey.isEmpty ? null : 'Trenutni: $_plantKey',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sekundarna klasifikacija i cijena (lista)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _secondaryClassCodeController,
                  decoration: _dec(
                    'Šifra sek. klasifikacije',
                    hint: 'npr. PP09',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secondaryClassDescController,
                  decoration: _dec(
                    'Opis sek. klasifikacije',
                    hint: 'npr. POLUPROIZVOD – …',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _packagingQtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec(
                    'Količina pakovanja',
                    hint: 'Za kolonu „Kol.“ na listi',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _standardUnitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec(
                    'Jedinična cijena',
                    hint: 'Za listu / izvještaje',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyController,
                  decoration: _dec('Valuta', hint: 'npr. KM, EUR'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aktivni BOM i Routing',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ova polja su privremeno ovdje dok ne napravimo Product Details i verzionisanje kroz UI.',
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
                      : const Text('Sačuvaj proizvod'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
