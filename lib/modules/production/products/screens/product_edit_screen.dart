import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../logistics/wms/wms_scan_helpers.dart';
import '../services/product_lookup_service.dart';
import '../services/product_service.dart';
import '../services/product_tracking_label_service.dart';

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
  late final TextEditingController _shelfLifeDaysController;
  late final TextEditingController _minStockQtyController;
  late final TextEditingController _maxStockQtyController;
  late final TextEditingController _idealCycleSecondsController;

  bool _isLoading = false;
  late bool _isActive;
  late String _status;
  late bool _lotTrackingRequired;

  /// Prilagođena etiketa za ispis na stanici (upload u Storage).
  bool _hasCustomTrackingLabel = false;
  String _customLabelFileName = '';
  bool _labelBusy = false;

  late List<String> _scanAliases;

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

  String _formatIntForField(dynamic v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    if (v is num) return v.toInt().toString();
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

    _shelfLifeDaysController = TextEditingController(
      text: _formatIntForField(widget.productData['shelfLifeDays']),
    );
    _minStockQtyController = TextEditingController(
      text: _formatNumForField(widget.productData['minStockQty']),
    );
    _maxStockQtyController = TextEditingController(
      text: _formatNumForField(widget.productData['maxStockQty']),
    );
    _idealCycleSecondsController = TextEditingController(
      text: _formatNumForField(widget.productData['idealCycleTimeSeconds']),
    );

    _status = _s(widget.productData['status']).isEmpty
        ? 'active'
        : _s(widget.productData['status']).toLowerCase();
    _isActive =
        (widget.productData['isActive'] as bool?) ?? (_status == 'active');

    _lotTrackingRequired =
        (widget.productData['lotTrackingRequired'] as bool?) ?? false;

    _scanAliases = _readScanAliasesFromProduct(widget.productData);

    _hasCustomTrackingLabel =
        _s(widget.productData['customTrackingLabelStoragePath']).isNotEmpty;
    _customLabelFileName = _s(widget.productData['customTrackingLabelFileName']);
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(labelText: label, hintText: hint);
  }

  List<String> _readScanAliasesFromProduct(Map<String, dynamic> data) {
    final raw = data['scanAliases'];
    if (raw is! List) return [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _addScanAlias() async {
    final raw = await wmsScanBarcodeRaw(
      context,
      companyData: widget.companyData,
    );
    if (!mounted || raw == null || raw.isEmpty) return;
    final norm = ProductLookupService.normalizeScanAlias(raw);
    if (norm.isEmpty) return;

    final existing = await ProductLookupService().getByScanAlias(
      companyId: _companyId,
      raw: norm,
    );
    if (!mounted) return;
    if (existing != null && existing.productId != _productId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kod je već na proizvodu: ${existing.productCode}',
          ),
        ),
      );
      return;
    }
    if (_scanAliases.contains(norm)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taj kod je već na listi.')),
      );
      return;
    }
    if (_scanAliases.length >= ProductService.maxScanAliasesForProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Najviše ${ProductService.maxScanAliasesForProduct} kodova.',
          ),
        ),
      );
      return;
    }
    setState(() => _scanAliases = [..._scanAliases, norm]);
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

    int? shelfDaysUp;
    final shelfRaw = _shelfLifeDaysController.text.trim();
    if (shelfRaw.isEmpty) {
      shelfDaysUp = 0;
    } else {
      final si = int.tryParse(shelfRaw.replaceAll(',', '.'));
      if (si == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neispravan broj: rok trajanja (dani)')),
        );
        return;
      }
      shelfDaysUp = si;
    }

    final minUp = parseUpdateDouble(
      _minStockQtyController.text,
      label: 'Min. zaliha',
    );
    if (minUp == null) return;

    final maxUp = parseUpdateDouble(
      _maxStockQtyController.text,
      label: 'Max. zaliha',
    );
    if (maxUp == null) return;

    final idealUp = parseUpdateDouble(
      _idealCycleSecondsController.text,
      label: 'Idealni ciklus (s)',
    );
    if (idealUp == null) return;

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
        lotTrackingRequired: _lotTrackingRequired,
        shelfLifeDays: shelfDaysUp,
        minStockQty: minUp,
        maxStockQty: maxUp,
        idealCycleTimeSeconds: idealUp,
        scanAliases: _scanAliases,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadTrackingLabel() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nije moguće učitati datoteku.')),
      );
      return;
    }
    setState(() => _labelBusy = true);
    try {
      await ProductTrackingLabelService().upload(
        companyId: _companyId,
        productId: _productId,
        bytes: bytes,
        fileName: f.name,
        updatedBy: _userId,
      );
      if (!mounted) return;
      setState(() {
        _hasCustomTrackingLabel = true;
        _customLabelFileName = f.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prilagođena etiketa je spremljena.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _labelBusy = false);
    }
  }

  Future<void> _removeTrackingLabel() async {
    setState(() => _labelBusy = true);
    try {
      await ProductTrackingLabelService().remove(
        productId: _productId,
        updatedBy: _userId,
      );
      if (!mounted) return;
      setState(() {
        _hasCustomTrackingLabel = false;
        _customLabelFileName = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prilagođena etiketa je uklonjena.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _labelBusy = false);
    }
  }

  @override
  void dispose() {
    _idealCycleSecondsController.dispose();
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
    _shelfLifeDaysController.dispose();
    _minStockQtyController.dispose();
    _maxStockQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _productId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Uredi proizvod')),
        body: const Center(
          child: Text('Nedostaje proizvod ili podatak o kompaniji.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Uredi proizvod')),
      body: AbsorbPointer(
        absorbing: _isLoading || _labelBusy,
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
                  'Vanjski barkodovi / QR (postojeće etikete)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sken prijema robe prepoznaje artikl po ovim kodovima.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _scanAliases
                      .map(
                        (a) => InputChip(
                          label: Text(
                            a.length > 40 ? '${a.substring(0, 40)}…' : a,
                          ),
                          onDeleted: () => setState(
                            () => _scanAliases =
                                _scanAliases.where((x) => x != a).toList(),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _addScanAlias,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: const Text('Dodaj kod skeniranjem'),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idealCycleSecondsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec(
                    'Idealni ciklus (s/komad) za OOE',
                    hint: 'Prazno = ukloni (Performance)',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Zaliha / magacin (IATF)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Obavezno praćenje lota / šarže'),
                  value: _lotTrackingRequired,
                  onChanged: (v) => setState(() => _lotTrackingRequired = v),
                ),
                TextFormField(
                  controller: _shelfLifeDaysController,
                  keyboardType: TextInputType.number,
                  decoration: _dec(
                    'Rok trajanja (dani)',
                    hint: 'Prazno = ukloni',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minStockQtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec('Min. zaliha', hint: 'Prazno = ukloni'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxStockQtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec('Max. zaliha', hint: 'Prazno = ukloni'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Etiketa za praćenje (stanica)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ako kupac traži svoj dizajn etikete (svoje kodove i oznake), učitaj PDF ili sliku. '
                  'Pri ispisu na stanici koristi se ta datoteka umjesto sustavske etikete s QR-om, '
                  'ako je šifra u unosu povezana s ovim proizvodom.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (_hasCustomTrackingLabel) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _customLabelFileName.isEmpty
                          ? 'Postavljena je prilagođena etiketa'
                          : 'Postavljeno: $_customLabelFileName',
                    ),
                    subtitle: const Text(
                      'Maks. 10 MB · PDF, PNG ili JPG',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: _labelBusy ? null : _removeTrackingLabel,
                      child: const Text('Ukloni'),
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: _labelBusy ? null : _pickAndUploadTrackingLabel,
                  icon: _labelBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _hasCustomTrackingLabel
                        ? 'Zamijeni prilagođenu etiketu'
                        : 'Učitaj prilagođenu etiketu',
                  ),
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
