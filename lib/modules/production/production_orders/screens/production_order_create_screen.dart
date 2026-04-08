import 'dart:async';

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

  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(
    text: 'pcs',
  );

  final FocusNode _productSearchFocusNode = FocusNode();

  DateTime? _scheduledEndAt;

  bool _isLoading = false;
  bool _isSearchingProducts = false;
  bool _showProductSuggestions = false;

  String? _productId;
  String? _customerId;

  Map<String, dynamic>? _productData;
  List<ProductLookupItem> _productSuggestions = <ProductLookupItem>[];

  Timer? _productSearchDebounce;

  String get _companyId => (widget.companyData['companyId'] ?? '').toString();
  String get _plantKey => (widget.companyData['plantKey'] ?? '').toString();
  String get _userId => (widget.companyData['userId'] ?? 'system').toString();

  bool get _hasSelectedProduct => _productId != null && _productId!.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _productSearchFocusNode.addListener(() {
      if (!_productSearchFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          setState(() {
            _showProductSuggestions = false;
          });
        });
      } else if (_productSuggestions.isNotEmpty) {
        setState(() {
          _showProductSuggestions = true;
        });
      }
    });
  }

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

  void _clearSelectedProduct() {
    _productId = null;
    _customerId = null;
    _productData = null;
    _productCodeController.clear();
    _productNameController.clear();
    _customerNameController.clear();
  }

  void _clearSelectedProductAndSearch() {
    _productSearchController.clear();
    _clearSelectedProduct();
    _productSuggestions = <ProductLookupItem>[];
    _showProductSuggestions = false;
    _isSearchingProducts = false;
  }

  void _onProductSearchChanged(String value) {
    _productSearchDebounce?.cancel();

    _clearSelectedProduct();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _productSuggestions = <ProductLookupItem>[];
        _showProductSuggestions = false;
        _isSearchingProducts = false;
      });
      return;
    }

    setState(() {
      _isSearchingProducts = true;
      _showProductSuggestions = true;
    });

    _productSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await _productLookupService.searchProducts(
          companyId: _companyId,
          query: query,
          limit: 10,
        );

        if (!mounted) return;

        final stillSameQuery = _productSearchController.text.trim() == query;
        if (!stillSameQuery) return;

        setState(() {
          _productSuggestions = results;
          _showProductSuggestions = true;
          _isSearchingProducts = false;
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _productSuggestions = <ProductLookupItem>[];
          _showProductSuggestions = false;
          _isSearchingProducts = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
      }
    });
  }

  void _selectProduct(ProductLookupItem product) {
    setState(() {
      _productId = product.productId;
      _customerId = product.customerId;

      _productSearchController.text =
          '${product.productCode} - ${product.productName}';
      _productCodeController.text = product.productCode;
      _productNameController.text = product.productName;
      _customerNameController.text = product.customerName ?? '';
      _unitController.text = (product.unit ?? '').trim().isEmpty
          ? _unitController.text
          : product.unit!.trim();

      _productData = <String, dynamic>{
        'productId': product.productId,
        'productCode': product.productCode,
        'productName': product.productName,
        'customerId': product.customerId,
        'customerName': product.customerName,
        'unit': product.unit,
        'bomId': product.bomId,
        'bomVersion': product.bomVersion,
        'routingId': product.routingId,
        'routingVersion': product.routingVersion,
      };

      _productSuggestions = <ProductLookupItem>[];
      _showProductSuggestions = false;
    });

    _productSearchFocusNode.unfocus();
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
        const SnackBar(content: Text('Odaberi proizvod iz šifrarnika')),
      );
      return;
    }

    if (_productData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaci proizvoda nisu učitani')),
      );
      return;
    }

    final bomId = (_productData!['bomId'] ?? '').toString().trim();
    final bomVersion = (_productData!['bomVersion'] ?? '').toString().trim();
    final routingId = (_productData!['routingId'] ?? '').toString().trim();
    final routingVersion = (_productData!['routingVersion'] ?? '')
        .toString()
        .trim();

    if (bomId.isEmpty || bomVersion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odabrani proizvod nema aktivan BOM.')),
      );
      return;
    }

    if (routingId.isEmpty || routingVersion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odabrani proizvod nema aktivan Routing.'),
        ),
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
        bomId: bomId,
        bomVersion: bomVersion,
        routingId: routingId,
        routingVersion: routingVersion,
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

  Widget _buildProductSuggestions() {
    if (!_showProductSuggestions) {
      return const SizedBox.shrink();
    }

    if (_isSearchingProducts) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Pretraga proizvoda...')),
          ],
        ),
      );
    }

    if (_productSuggestions.isEmpty &&
        _productSearchController.text.trim().isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Nema rezultata za unesenu šifru ili naziv.'),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productSuggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Colors.grey.shade300),
        itemBuilder: (context, index) {
          final product = _productSuggestions[index];

          return ListTile(
            dense: true,
            title: Text(
              product.productCode,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(product.productName),
            trailing:
                product.customerName != null &&
                    product.customerName!.trim().isNotEmpty
                ? Text(
                    product.customerName!,
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
            onTap: () => _selectProduct(product),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _productSearchDebounce?.cancel();
    _productSearchController.dispose();
    _productCodeController.dispose();
    _productNameController.dispose();
    _customerNameController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    _productSearchFocusNode.dispose();
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
                  controller: _productSearchController,
                  focusNode: _productSearchFocusNode,
                  decoration: _dec('Šifra / naziv proizvoda').copyWith(
                    suffixIcon: _hasSelectedProduct
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _clearSelectedProductAndSearch();
                              });
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: _onProductSearchChanged,
                  validator: (value) {
                    if (_productId == null || _productId!.isEmpty) {
                      return 'Odaberi proizvod iz liste';
                    }
                    return null;
                  },
                ),
                _buildProductSuggestions(),
                if (_hasSelectedProduct) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Proizvod je odabran iz šifrarnika'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productCodeController,
                  decoration: _dec('Šifra proizvoda'),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Proizvod nije odabran';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productNameController,
                  decoration: _dec('Naziv proizvoda'),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Proizvod nije odabran';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerNameController,
                  decoration: _dec('Kupac'),
                  readOnly: true,
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
