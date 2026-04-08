import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/product_service.dart';
import 'product_edit_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String productId;

  const ProductDetailsScreen({
    super.key,
    required this.companyData,
    required this.productId,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();

  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _product;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _productId => widget.productId.trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canEdit => _role == 'admin' || _role == 'production_manager';

  String _s(dynamic value) => (value ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    if (_companyId.isEmpty || _productId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Nedostaje companyData ili productId';
        _product = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final product = await _productService.getProductById(
        productId: _productId,
        companyId: _companyId,
      );

      if (!mounted) return;

      if (product == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Proizvod nije pronađen.';
          _product = null;
        });
        return;
      }

      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppErrorMapper.toMessage(e);
        _isLoading = false;
        _product = null;
      });
    }
  }

  Future<void> _openEdit() async {
    if (_product == null || !_canEdit) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditScreen(
          companyData: widget.companyData,
          productData: _product!,
        ),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      await _loadProduct();
    }
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  void _notImplemented(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label još nije implementiran.')));
  }

  Widget _buildHeader(Map<String, dynamic> product) {
    final productCode = _s(product['productCode']);
    final productName = _s(product['productName']);
    final status = _s(product['status']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  productCode.isEmpty ? '-' : productCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab(Map<String, dynamic> product) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _infoRow('Šifra', _s(product['productCode'])),
            _infoRow('Naziv', _s(product['productName'])),
            _infoRow('Status', _statusLabel(_s(product['status']))),
            _infoRow('Jedinica', _s(product['unit'])),
            _infoRow('Kupac', _s(product['customerName'])),
            _infoRow('Customer ID', _s(product['customerId'])),
            _infoRow('Default plantKey', _s(product['defaultPlantKey'])),
            _infoRow('Opis', _s(product['description'])),
          ],
        ),
      ],
    );
  }

  Widget _buildBomTab(Map<String, dynamic> product) {
    final bomId = _s(product['bomId']);
    final bomVersion = _s(product['bomVersion']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'BOM',
          subtitle:
              'Aktivni BOM se trenutno vodi direktno na product dokumentu dok ne završimo puni versioned flow.',
          children: [
            _infoRow('Aktivni BOM ID', bomId),
            _infoRow('Aktivna verzija', bomVersion),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _notImplemented('BOM detalji'),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Otvori BOM detalje'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoutingTab(Map<String, dynamic> product) {
    final routingId = _s(product['routingId']);
    final routingVersion = _s(product['routingVersion']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Routing',
          subtitle:
              'Aktivni Routing se trenutno vodi direktno na product dokumentu dok ne završimo puni versioned flow.',
          children: [
            _infoRow('Aktivni Routing ID', routingId),
            _infoRow('Aktivna verzija', routingVersion),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _notImplemented('Routing detalji'),
              icon: const Icon(Icons.alt_route),
              label: const Text('Otvori Routing detalje'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersTab(Map<String, dynamic> product) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Proizvodni nalozi',
          subtitle:
              'Ovdje će ići pregled ili shortcut na filtrirane naloge za ovaj proizvod.',
          children: [
            _infoRow('Product ID', _s(product['productId'])),
            _infoRow('Šifra proizvoda', _s(product['productCode'])),
            _infoRow('Naziv proizvoda', _s(product['productName'])),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _notImplemented('Filtrirani proizvodni nalozi'),
              icon: const Icon(Icons.assignment),
              label: const Text('Otvori naloge za ovaj proizvod'),
            ),
          ],
        ),
      ],
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
                onPressed: _loadProduct,
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );
    }

    if (_product == null) {
      return const Center(child: Text('Proizvod nije pronađen.'));
    }

    final product = _product!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildHeader(product),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Osnovni podaci'),
            Tab(text: 'BOM'),
            Tab(text: 'Routing'),
            Tab(text: 'Nalozi'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicInfoTab(product),
              _buildBomTab(product),
              _buildRoutingTab(product),
              _buildOrdersTab(product),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId.isEmpty || _productId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalji proizvoda')),
        body: const Center(child: Text('Nedostaje companyData ili productId')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji proizvoda'),
        actions: [
          if (_canEdit)
            IconButton(
              tooltip: 'Uredi',
              onPressed: (_isLoading || _product == null) ? null : _openEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _isLoading ? null : _loadProduct,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
