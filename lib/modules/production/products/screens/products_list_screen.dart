import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import 'product_create_screen.dart';
import 'product_details_screen.dart';
import '../services/product_service.dart';

class ProductsListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductsListScreen({super.key, required this.companyData});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final ProductService _productService = ProductService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canCreateProduct =>
      _role == 'admin' || _role == 'production_manager';

  String _s(dynamic value) => (value ?? '').toString().trim();

  Future<void> _loadProducts() async {
    if (_companyId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Nedostaje companyData';
        _products = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _productService.getProducts(companyId: _companyId);

      if (!mounted) return;

      setState(() {
        _products = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppErrorMapper.toMessage(e);
        _isLoading = false;
        _products = <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _openCreateProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCreateScreen(companyData: widget.companyData),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      await _loadProducts();
    }
  }

  Future<void> _openProductDetails(Map<String, dynamic> product) async {
    final productId = _s(product['productId']);
    if (productId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nedostaje productId.')));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          companyData: widget.companyData,
          productId: productId,
        ),
      ),
    );

    if (!mounted) return;
    await _loadProducts();
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Aktivan';
      case 'inactive':
        return 'Neaktivan';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proizvodi')),
        body: const Center(child: Text('Nedostaje companyData')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proizvodi'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _isLoading ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreateProduct
          ? FloatingActionButton.extended(
              onPressed: _openCreateProduct,
              icon: const Icon(Icons.add),
              label: const Text('Novi proizvod'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nema unesenih proizvoda.', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _products[index];

        final productCode = _s(product['productCode']);
        final productName = _s(product['productName']);
        final customerName = _s(product['customerName']);
        final status = _s(product['status']);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openProductDetails(product),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        productCode.isEmpty ? '-' : productCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _statusColor(status).withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productName.isEmpty ? '-' : productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (customerName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Kupac: $customerName',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
