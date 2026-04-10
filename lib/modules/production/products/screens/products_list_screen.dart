import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/standard_list_components.dart';
import '../services/product_service.dart';
import 'product_create_screen.dart';
import 'product_details_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductsListScreen({super.key, required this.companyData});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isImporting = false;
  bool _filtersExpanded = false;
  ProductStatusFilter _selectedStatus = ProductStatusFilter.all;

  String? _errorMessage;
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();
  String get _userId => (widget.companyData['userId'] ?? '').toString().trim();

  bool get _canCreateProduct =>
      _role == 'admin' || _role == 'production_manager';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _s(dynamic value) => (value ?? '').toString().trim();

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchController.text.trim().toLowerCase();
    return _products.where((p) {
      final code = _s(p['productCode']).toLowerCase();
      final name = _s(p['productName']).toLowerCase();
      final status = _s(p['status']).toLowerCase();
      final matchesSearch = q.isEmpty || code.contains(q) || name.contains(q);
      final matchesStatus = _selectedStatus.matches(status);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  double? _parseDouble(dynamic value) {
    final text = _s(value).replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '').replaceAll('_', '');
  }

  String _cellText(dynamic cell) {
    try {
      final value = cell?.value;
      if (value == null) return '';
      return value.toString().trim();
    } catch (_) {
      return '';
    }
  }

  String _readRowValue(
    List<dynamic> row,
    Map<String, int> headerIndex,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final index = headerIndex[_normalizeHeader(alias)];
      if (index == null) continue;
      if (index < 0 || index >= row.length) continue;

      final text = _cellText(row[index]);
      if (text.isNotEmpty) return text;
    }

    return '';
  }

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

  Future<void> _showImportInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excel import proizvoda'),
          content: const SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Obavezne kolone:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('• productCode'),
                  Text('• productName'),
                  SizedBox(height: 12),
                  Text(
                    'Opcione kolone:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('• unit'),
                  Text('• description'),
                  Text('• packagingQty'),
                  Text('• status'),
                  SizedBox(height: 12),
                  Text(
                    'Primjer reda:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('CAP-001 | Čep 28 mm | KOM | 12 | active'),
                  SizedBox(height: 12),
                  Text('🛈 Ako status nije unesen, koristi se active.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('U redu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importProductsFromExcel() async {
    if (!_canCreateProduct) return;

    if (_companyId.isEmpty || _userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje companyId ili userId za import.'),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isImporting = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final PlatformFile pickedFile = result.files.first;
      final Uint8List? bytes = pickedFile.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Nije moguće učitati sadržaj Excel fajla.');
      }

      final excel = excel_pkg.Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception('Excel fajl nema nijedan sheet.');
      }

      final excel_pkg.Sheet table = excel.tables.values.first;
      final List<List<dynamic>> rows = table.rows
          .map((row) => row.cast<dynamic>())
          .toList();

      if (rows.isEmpty) {
        throw Exception('Excel fajl je prazan.');
      }

      final headerRow = rows.first;
      final Map<String, int> headerIndex = <String, int>{};

      for (int i = 0; i < headerRow.length; i++) {
        final header = _normalizeHeader(_cellText(headerRow[i]));
        if (header.isNotEmpty) {
          headerIndex[header] = i;
        }
      }

      final hasProductCode = headerIndex.containsKey('productcode');
      final hasProductName = headerIndex.containsKey('productname');

      if (!hasProductCode || !hasProductName) {
        throw Exception('Excel mora imati kolone productCode i productName.');
      }

      int createdCount = 0;
      int skippedCount = 0;
      final List<String> skippedRows = <String>[];

      for (int rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];

        final productCode = _readRowValue(row, headerIndex, const [
          'productCode',
        ]);
        final productName = _readRowValue(row, headerIndex, const [
          'productName',
        ]);
        final unit = _readRowValue(row, headerIndex, const ['unit']);
        final description = _readRowValue(row, headerIndex, const [
          'description',
        ]);
        final statusRaw = _readRowValue(row, headerIndex, const ['status']);
        final packagingQtyRaw = _readRowValue(row, headerIndex, const [
          'packagingQty',
        ]);

        if (productCode.isEmpty && productName.isEmpty) {
          continue;
        }

        if (productCode.isEmpty || productName.isEmpty) {
          skippedCount++;
          skippedRows.add(
            'Red ${rowIndex + 1}: nedostaje productCode ili productName.',
          );
          continue;
        }

        final normalizedStatus = statusRaw.isEmpty
            ? 'active'
            : statusRaw.toLowerCase().trim();

        if (normalizedStatus != 'active' && normalizedStatus != 'inactive') {
          skippedCount++;
          skippedRows.add(
            'Red ${rowIndex + 1}: status mora biti active ili inactive.',
          );
          continue;
        }

        final packagingQty = _parseDouble(packagingQtyRaw);

        try {
          await _productService.createProduct(
            companyId: _companyId,
            productCode: productCode,
            productName: productName,
            createdBy: _userId,
            status: normalizedStatus,
            unit: unit.isEmpty ? null : unit,
            description: description.isEmpty ? null : description,
            packagingQty: packagingQty,
          );
          createdCount++;
        } catch (e) {
          skippedCount++;
          skippedRows.add(
            'Red ${rowIndex + 1}: ${AppErrorMapper.toMessage(e)}',
          );
        }
      }

      if (!mounted) return;

      await _loadProducts();

      if (!mounted) return;

      final StringBuffer message = StringBuffer()
        ..write('Import završen. Kreirano: $createdCount');

      if (skippedCount > 0) {
        message.write(', preskočeno: $skippedCount');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message.toString())));

      if (skippedRows.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Rezultat importa'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.toString()),
                      const SizedBox(height: 12),
                      const Text(
                        'Preskočeni redovi:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...skippedRows.map(
                        (rowMessage) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $rowMessage'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Zatvori'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
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

  Widget _buildKpis() {
    final active = _products.where((e) => _s(e['status']).toLowerCase() == 'active').length;
    final inactive = _products.where((e) => _s(e['status']).toLowerCase() == 'inactive').length;
    return StandardKpiGrid(
      metrics: [
        KpiMetric(
          label: 'Ukupno',
          value: _products.length,
          color: Colors.blue,
          icon: Icons.inventory_2_outlined,
        ),
        KpiMetric(
          label: 'Aktivni',
          value: active,
          color: Colors.green,
          icon: Icons.check_circle_outline,
        ),
        KpiMetric(
          label: 'Neaktivni',
          value: inactive,
          color: Colors.grey,
          icon: Icons.pause_circle_outline,
        ),
        KpiMetric(
          label: 'Prikaz',
          value: _filteredProducts.length,
          color: Colors.orange,
          icon: Icons.filter_alt_outlined,
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return StandardSearchField(
      controller: _searchController,
      hintText: 'Pretraga po šifri ili nazivu proizvoda',
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildFilters() {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
    }

    final activeCount = _selectedStatus == ProductStatusFilter.all ? 0 : 1;

    return StandardFilterPanel(
      expanded: _filtersExpanded,
      activeCount: activeCount,
      onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            children: ProductStatusFilter.values.map((status) {
              return chip(
                label: status.label,
                selected: _selectedStatus == status,
                onTap: () => setState(() => _selectedStatus = status),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Proizvodi'),
                  content: const Text(
                    'Master šifrarnik proizvoda za planiranje i izvršenje.\n\n'
                    '• Kreiranje i uređivanje proizvoda\n'
                    '• Status active/inactive\n'
                    '• Excel import\n'
                    '• Ulaz u BOM, routing i povezane naloge',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zatvori'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_canCreateProduct)
            IconButton(
              tooltip: 'Info za Excel import',
              onPressed: _isImporting ? null : _showImportInfo,
              icon: const Icon(Icons.info_outline),
            ),
          if (_canCreateProduct)
            IconButton(
              tooltip: 'Excel import',
              onPressed: (_isLoading || _isImporting)
                  ? null
                  : _importProductsFromExcel,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
            ),
          IconButton(
            tooltip: 'Osvježi',
            onPressed: (_isLoading || _isImporting) ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreateProduct
          ? FloatingActionButton.extended(
              onPressed: (_isImporting || _isLoading)
                  ? null
                  : _openCreateProduct,
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

    final list = _filteredProducts;

    if (_products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nema unesenih proizvoda.', textAlign: TextAlign.center),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildKpis(),
                  const SizedBox(height: 16),
                  _buildSearch(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text('Nema proizvoda za odabrani filter.'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final product = list[index];

                  final productCode = _s(product['productCode']);
                  final productName = _s(product['productName']);
                  final packagingQty = _s(product['packagingQty']);
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
                                    color: _statusColor(status).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: _statusColor(status).withValues(alpha: 0.35),
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
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            if (packagingQty.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Pakovanje: $packagingQty',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
              ),
            ),
        ],
      ),
    );
  }
}

enum ProductStatusFilter { all, active, inactive }

extension ProductStatusFilterX on ProductStatusFilter {
  String get label {
    switch (this) {
      case ProductStatusFilter.all:
        return 'Svi';
      case ProductStatusFilter.active:
        return 'Aktivni';
      case ProductStatusFilter.inactive:
        return 'Neaktivni';
    }
  }

  bool matches(String status) {
    final s = status.toLowerCase().trim();
    switch (this) {
      case ProductStatusFilter.all:
        return true;
      case ProductStatusFilter.active:
        return s == 'active';
      case ProductStatusFilter.inactive:
        return s == 'inactive';
    }
  }
}
