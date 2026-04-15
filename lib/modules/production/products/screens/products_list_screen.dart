import 'dart:async';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/standard_list_components.dart';
import '../../../logistics/inventory/services/product_warehouse_stock_service.dart';
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
  final ProductWarehouseStockService _stockService =
      ProductWarehouseStockService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isImporting = false;
  bool _filtersExpanded = false;
  bool _stockLoading = false;
  ProductStatusFilter _selectedStatus = ProductStatusFilter.all;

  String? _errorMessage;
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];
  List<WarehouseRef> _warehouses = const [];

  /// null = svi
  String? _filterCustomerName;

  /// null = svi tipovi; vrijednosti: GK, PP, SK, MA, PM, __ostalo__
  String? _filterPieceTypeKey;

  /// null = sve ukupno (zbir po magacinima u kontekstu pogona)
  String? _filterWarehouseId;

  Timer? _searchDebounce;

  /// Keš linija zalihe po proizvodu (učitava se za trenutno filtriranu listu).
  final Map<String, List<ProductWarehouseStockLine>> _stockLinesByProductId =
      {};
  Map<String, double> _displayStockQty = <String, double>{};
  int _stockRequestId = 0;

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
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) unawaited(_refreshStockForFiltered());
      });
    });
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _s(dynamic value) => (value ?? '').toString().trim();

  String get _companyPlantKey => _s(widget.companyData['plantKey']).isEmpty
      ? ''
      : _s(widget.companyData['plantKey']);

  static const Set<String> _piecePrefixes = {'GK', 'PP', 'SK', 'MA', 'PM'};
  static const List<String> _pieceTypeOrder = [
    'GK',
    'PP',
    'SK',
    'MA',
    'PM',
    '__ostalo__',
  ];

  /// Tip komada po prva 2 znaka šifre (GK/PP/SK/MA/PM), inače „ostalo”.
  String _pieceTypeKey(Map<String, dynamic> p) {
    final raw = _s(p['productCode']);
    if (raw.length < 2) return '__ostalo__';
    final two = raw.substring(0, 2).toUpperCase();
    if (_piecePrefixes.contains(two)) return two;
    return '__ostalo__';
  }

  String _pieceTypeTitleFromKey(String key) {
    switch (key) {
      case 'GK':
        return 'GK – Gotov komad';
      case 'PP':
        return 'PP – Poluproizvod';
      case 'SK':
        return 'SK – Sirov komad';
      case 'MA':
        return 'MA – Materijali';
      case 'PM':
        return 'PM – Potrošni materijal';
      default:
        return 'Ostalo (šifra ne počinje sa GK/PP/SK/MA/PM)';
    }
  }

  String _customerLabel(Map<String, dynamic> p) =>
      _s(p['customerName']).isEmpty ? 'Bez kupca' : _s(p['customerName']);

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchController.text.trim().toLowerCase();
    return _products.where((p) {
      final code = _s(p['productCode']).toLowerCase();
      final name = _s(p['productName']).toLowerCase();
      final cust = _customerLabel(p).toLowerCase();
      final status = _s(p['status']).toLowerCase();
      final ptKey = _pieceTypeKey(p);
      final ptTitle = _pieceTypeTitleFromKey(ptKey).toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          code.contains(q) ||
          name.contains(q) ||
          cust.contains(q) ||
          ptKey.toLowerCase().contains(q) ||
          ptTitle.contains(q);
      final matchesStatus = _selectedStatus.matches(status);
      final matchesCustomer =
          _filterCustomerName == null ||
          _customerLabel(p) == _filterCustomerName;
      final matchesPiece =
          _filterPieceTypeKey == null ||
          _pieceTypeKey(p) == _filterPieceTypeKey;
      return matchesSearch && matchesStatus && matchesCustomer && matchesPiece;
    }).toList();
  }

  List<String> _distinctCustomers() {
    final s = <String>{};
    for (final p in _products) {
      final n = _customerLabel(p);
      if (n != 'Bez kupca') s.add(n);
    }
    final list = s.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _distinctPieceTypeKeys() {
    final s = <String>{};
    for (final p in _products) {
      s.add(_pieceTypeKey(p));
    }
    final list = s.toList()
      ..sort((a, b) {
        final ia = _pieceTypeOrder.indexOf(a);
        final ib = _pieceTypeOrder.indexOf(b);
        final va = ia < 0 ? 999 : ia;
        final vb = ib < 0 ? 999 : ib;
        final c = va.compareTo(vb);
        if (c != 0) return c;
        return a.compareTo(b);
      });
    return list;
  }

  String _fmtNum(double? v, {bool emptyAsDash = true}) {
    if (v == null) return emptyAsDash ? '—' : '0,00';
    if (v.isNaN) return '—';
    final t = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(2).replaceAll('.', ',');
    return t;
  }

  double? _displayQty(Map<String, dynamic> p) {
    final pq = _parseDouble(p['packagingQty']);
    if (pq != null && pq > 0) return pq;
    return null;
  }

  double? _unitPrice(Map<String, dynamic> p) {
    return _parseDouble(
      p['standardUnitPrice'] ?? p['unitPrice'] ?? p['listPrice'],
    );
  }

  String _currency(Map<String, dynamic> p) {
    final c = _s(p['currency']);
    return c.isEmpty ? 'KM' : c;
  }

  double? _lineTotal(Map<String, dynamic> p) {
    final q = _displayQty(p);
    final u = _unitPrice(p);
    if (q == null || u == null) return null;
    return q * u;
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
      final wh = await _stockService.listActiveWarehouses(
        companyId: _companyId,
        plantKey: _companyPlantKey.isEmpty ? null : _companyPlantKey,
      );

      if (!mounted) return;

      setState(() {
        _products = items;
        _warehouses = wh;
        _isLoading = false;
        _stockLinesByProductId.clear();
        _displayStockQty = <String, double>{};
        if (_filterCustomerName != null &&
            !_distinctCustomers().contains(_filterCustomerName)) {
          _filterCustomerName = null;
        }
        if (_filterPieceTypeKey != null &&
            !_distinctPieceTypeKeys().contains(_filterPieceTypeKey)) {
          _filterPieceTypeKey = null;
        }
        if (_filterWarehouseId != null &&
            !_warehouses.any((w) => w.id == _filterWarehouseId)) {
          _filterWarehouseId = null;
        }
      });
      await _refreshStockForFiltered();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppErrorMapper.toMessage(e);
        _isLoading = false;
        _products = <Map<String, dynamic>>[];
      });
    }
  }

  void _applyStockDisplay() {
    final wid = _filterWarehouseId;
    final next = <String, double>{};
    for (final p in _filteredProducts) {
      final id = _s(p['productId']);
      if (id.isEmpty) continue;
      final lines = _stockLinesByProductId[id];
      if (lines == null) continue;
      if (wid == null) {
        next[id] = lines.fold<double>(0, (a, b) => a + b.quantityOnHand);
      } else {
        next[id] = lines
            .where((l) => l.warehouseId == wid)
            .fold<double>(0, (a, b) => a + b.quantityOnHand);
      }
    }
    if (!mounted) return;
    setState(() => _displayStockQty = next);
  }

  Future<void> _refreshStockForFiltered() async {
    if (_companyId.isEmpty) return;

    final req = ++_stockRequestId;

    final ids = _filteredProducts
        .map((p) => _s(p['productId']))
        .where((id) => id.isNotEmpty)
        .toSet();

    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _displayStockQty = <String, double>{};
          _stockLoading = false;
        });
      }
      return;
    }

    _stockLinesByProductId.removeWhere((k, _) => !ids.contains(k));

    if (mounted) setState(() => _stockLoading = true);

    final plant = _companyPlantKey.isEmpty ? null : _companyPlantKey;
    const batchSize = 6;

    try {
      final idList = ids.toList();
      for (var i = 0; i < idList.length; i += batchSize) {
        if (!mounted || req != _stockRequestId) return;
        final chunk = idList.sublist(
          i,
          i + batchSize > idList.length ? idList.length : i + batchSize,
        );
        await Future.wait(
          chunk.map((id) async {
            if (_stockLinesByProductId.containsKey(id)) return;
            final lines = await _stockService.loadStockLinesForProduct(
              companyId: _companyId,
              productId: id,
              plantKey: plant,
            );
            if (req != _stockRequestId) return;
            _stockLinesByProductId[id] = lines;
          }),
        );
      }
      if (!mounted || req != _stockRequestId) return;
      _applyStockDisplay();
    } finally {
      if (mounted && req == _stockRequestId) {
        setState(() => _stockLoading = false);
      }
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
                  Text('• unit, description, status, packagingQty'),
                  Text('• customerId, customerName (ili kupac)'),
                  Text('• defaultPlantKey (ili plantKey, pogon)'),
                  Text(
                    '• secondaryClassificationCode, secondaryClassificationDescription',
                  ),
                  Text('• secondaryClassification (jedna kolona → opis)'),
                  Text(
                    '• standardUnitPrice (ili unitPrice, listPrice, jedinicnaCijena)',
                  ),
                  Text('• currency (ili valuta, npr. KM)'),
                  SizedBox(height: 12),
                  Text(
                    'Primjer reda:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'CAP-001 | Čep 28 mm | KOM | opis… | active | 12 | CUST1 | Kupac d.o.o. | '
                    'PLANT1 | PP09 | POLUPROIZVOD… | 0,42 | KM',
                  ),
                  SizedBox(height: 12),
                  Text(
                    '🛈 Ako status nije unesen, koristi se active. Neispravni brojevi '
                    '(cijena, packaging) preskaču red.',
                  ),
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
          'kolicinaPakovanja',
          'kolPakovanja',
        ]);
        final customerId = _readRowValue(row, headerIndex, const [
          'customerId',
          'kupacId',
        ]);
        final customerName = _readRowValue(row, headerIndex, const [
          'customerName',
          'kupac',
          'nazivKupca',
        ]);
        final defaultPlantKey = _readRowValue(row, headerIndex, const [
          'defaultPlantKey',
          'plantKey',
          'pogon',
        ]);
        final secCode = _readRowValue(row, headerIndex, const [
          'secondaryClassificationCode',
          'secondaryclassificationcode',
          'sekundarnaklasifikacijasifra',
          'sekklasifsifra',
          'sekklasifkod',
        ]);
        final secDesc = _readRowValue(row, headerIndex, const [
          'secondaryClassificationDescription',
          'secondaryclassificationdescription',
          'sekundarnaklasifikacijaopis',
          'sekklasifopis',
        ]);
        final secCombined = _readRowValue(row, headerIndex, const [
          'secondaryClassification',
          'secondaryclassification',
          'sekundarnaklasifikacija',
        ]);
        final standardPriceRaw = _readRowValue(row, headerIndex, const [
          'standardUnitPrice',
          'standardunitprice',
          'unitPrice',
          'unitprice',
          'listPrice',
          'listprice',
          'jedinicnacijena',
          'cijena',
        ]);
        final currencyRaw = _readRowValue(row, headerIndex, const [
          'currency',
          'valuta',
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
        if (packagingQtyRaw.trim().isNotEmpty && packagingQty == null) {
          skippedCount++;
          skippedRows.add(
            'Red ${rowIndex + 1}: neispravan packagingQty („$packagingQtyRaw”).',
          );
          continue;
        }

        final standardUnitPrice = _parseDouble(standardPriceRaw);
        if (standardPriceRaw.trim().isNotEmpty && standardUnitPrice == null) {
          skippedCount++;
          skippedRows.add(
            'Red ${rowIndex + 1}: neispravan standardUnitPrice („$standardPriceRaw”).',
          );
          continue;
        }

        var outSecCode = secCode.trim();
        var outSecDesc = secDesc.trim();
        if (outSecCode.isEmpty &&
            outSecDesc.isEmpty &&
            secCombined.trim().isNotEmpty) {
          outSecDesc = secCombined.trim();
        }

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
            customerId: customerId.isEmpty ? null : customerId,
            customerName: customerName.isEmpty ? null : customerName,
            defaultPlantKey: defaultPlantKey.isEmpty ? null : defaultPlantKey,
            secondaryClassificationCode: outSecCode.isEmpty ? null : outSecCode,
            secondaryClassificationDescription: outSecDesc.isEmpty
                ? null
                : outSecDesc,
            standardUnitPrice: standardUnitPrice,
            currency: currencyRaw.trim().isEmpty ? null : currencyRaw.trim(),
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
    final active = _products
        .where((e) => _s(e['status']).toLowerCase() == 'active')
        .length;
    final inactive = _products
        .where((e) => _s(e['status']).toLowerCase() == 'inactive')
        .length;
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
      hintText: 'Šifra, naziv, kupac, tip komada (GK, PP…)…',
    );
  }

  int get _axisFilterActiveCount =>
      (_filterCustomerName != null ? 1 : 0) +
      (_filterPieceTypeKey != null ? 1 : 0) +
      (_filterWarehouseId != null ? 1 : 0);

  Widget _buildAxisFilters() {
    final customers = _distinctCustomers();
    final pieceKeys = _distinctPieceTypeKeys();

    Widget axisDropdown<T>({
      required String label,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return DropdownButtonFormField<T?>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        value: value,
        items: items,
        onChanged: onChanged,
      );
    }

    List<DropdownMenuItem<String?>> customerItems() => [
      const DropdownMenuItem<String?>(value: null, child: Text('Svi')),
      ...customers.map(
        (n) => DropdownMenuItem<String?>(
          value: n,
          child: Text(n, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    List<DropdownMenuItem<String?>> pieceItems() => [
      const DropdownMenuItem<String?>(value: null, child: Text('Sve')),
      ...pieceKeys.map(
        (k) => DropdownMenuItem<String?>(
          value: k,
          child: Text(
            _pieceTypeTitleFromKey(k),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    List<DropdownMenuItem<String?>> warehouseItems() => [
      const DropdownMenuItem<String?>(value: null, child: Text('Sve ukupno')),
      ..._warehouses.map(
        (w) => DropdownMenuItem<String?>(
          value: w.id,
          child: Text('${w.code} – ${w.name}', overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Kupac',
                      value: _filterCustomerName,
                      items: customerItems(),
                      onChanged: (v) {
                        setState(() => _filterCustomerName = v);
                        unawaited(_refreshStockForFiltered());
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Klasifikacija (tip komada)',
                      value: _filterPieceTypeKey,
                      items: pieceItems(),
                      onChanged: (v) {
                        setState(() => _filterPieceTypeKey = v);
                        unawaited(_refreshStockForFiltered());
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Magacin',
                      value: _filterWarehouseId,
                      items: warehouseItems(),
                      onChanged: (v) {
                        setState(() => _filterWarehouseId = v);
                        _applyStockDisplay();
                      },
                    ),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Kupac',
                      value: _filterCustomerName,
                      items: customerItems(),
                      onChanged: (v) {
                        setState(() => _filterCustomerName = v);
                        unawaited(_refreshStockForFiltered());
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Klasifikacija (tip komada)',
                      value: _filterPieceTypeKey,
                      items: pieceItems(),
                      onChanged: (v) {
                        setState(() => _filterPieceTypeKey = v);
                        unawaited(_refreshStockForFiltered());
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: axisDropdown<String?>(
                      label: 'Magacin',
                      value: _filterWarehouseId,
                      items: warehouseItems(),
                      onChanged: (v) {
                        setState(() => _filterWarehouseId = v);
                        _applyStockDisplay();
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Text(
          'Tip komada: prva 2 znaka šifre (GK gotov komad, PP poluproizvod, SK sirov komad, '
          'MA materijali, PM potrošni materijal). Zaliha: odabrani magacin ili „Sve ukupno“ '
          '(magacini u kontekstu pogona iz companyData).',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
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

    final activeCount =
        _axisFilterActiveCount +
        (_selectedStatus == ProductStatusFilter.all ? 0 : 1);

    return StandardFilterPanel(
      expanded: _filtersExpanded,
      activeCount: activeCount,
      onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            children: ProductStatusFilter.values.map((status) {
              return chip(
                label: status.label,
                selected: _selectedStatus == status,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  unawaited(_refreshStockForFiltered());
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static const double _reportTableWidth = 1060;

  Widget _reportHeaderRow() {
    final cs = Theme.of(context).colorScheme;
    final border = BorderSide(color: cs.outlineVariant, width: 1);
    Widget cell(
      String t,
      double? w, {
      bool exp = false,
      bool right = false,
      bool bold = true,
    }) {
      final child = Text(
        t,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontSize: 11,
          color: cs.onSurface,
        ),
      );
      final box = Container(
        width: w,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: border.color, width: border.width),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      );
      if (exp) {
        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border.all(color: border.color, width: border.width),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            alignment: right ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          ),
        );
      }
      return box;
    }

    return SizedBox(
      width: _reportTableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell('Šifra', 104),
          cell('Naziv', null, exp: true),
          cell('Pakovanje', 76, right: true),
          cell('MJ', 44),
          cell('Zaliha', 72, right: true),
          cell('Jed. cij.', 78, right: true),
          cell('Ukupno', 78, right: true),
          cell('Val', 40),
          cell('Stat.', 64),
        ],
      ),
    );
  }

  Widget _reportDataRow(Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;
    final border = BorderSide(color: cs.outlineVariant, width: 1);
    final pid = _s(p['productId']);
    final code = _s(p['productCode']);
    final name = _s(p['productName']);
    final qty = _displayQty(p);
    final unit = _s(p['unit']).isEmpty ? 'KOM' : _s(p['unit']);
    final stock = _displayStockQty[pid];
    final up = _unitPrice(p);
    final tot = _lineTotal(p);
    final cur = _currency(p);
    final st = _s(p['status']);

    Widget cell(Widget child, double? w, {bool exp = false}) {
      final box = Container(
        width: w,
        decoration: BoxDecoration(
          border: Border.all(color: border.color, width: border.width),
          color: cs.surface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: 11, color: cs.onSurface),
          child: child,
        ),
      );
      if (exp) {
        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: border.color, width: border.width),
              color: cs.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 11, color: cs.onSurface),
              child: child,
            ),
          ),
        );
      }
      return box;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openProductDetails(p),
        child: SizedBox(
          width: _reportTableWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(Text(code.isEmpty ? '—' : code), 104),
              cell(
                Text(
                  name.isEmpty ? '—' : name,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                null,
                exp: true,
              ),
              cell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_fmtNum(qty)),
                ),
                76,
              ),
              cell(Text(unit), 44),
              cell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _stockLoading && !_displayStockQty.containsKey(pid)
                        ? '…'
                        : _fmtNum(stock),
                  ),
                ),
                72,
              ),
              cell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_fmtNum(up)),
                ),
                78,
              ),
              cell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(_fmtNum(tot)),
                ),
                78,
              ),
              cell(Text(cur), 40),
              cell(
                Text(
                  _statusLabel(st),
                  style: TextStyle(
                    color: _statusColor(st),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                64,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productGroupFooter(List<Map<String, dynamic>> rows) {
    final cs = Theme.of(context).colorScheme;
    final n = rows.length;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        'Ukupno u ovoj grupi: $n stavki.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildGroupedProductReport(List<Map<String, dynamic>> list) {
    final sorted = List<Map<String, dynamic>>.from(list)
      ..sort((a, b) {
        var c = _customerLabel(
          a,
        ).toLowerCase().compareTo(_customerLabel(b).toLowerCase());
        if (c != 0) return c;
        final ka = _pieceTypeKey(a);
        final kb = _pieceTypeKey(b);
        final ia = _pieceTypeOrder.indexOf(ka);
        final ib = _pieceTypeOrder.indexOf(kb);
        c = (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
        if (c != 0) return c;
        return _s(a['productCode']).compareTo(_s(b['productCode']));
      });

    final nested = <String, Map<String, List<Map<String, dynamic>>>>{};
    final custOrder = <String>[];
    final clsOrderByCust = <String, List<String>>{};

    for (final p in sorted) {
      final cust = _customerLabel(p);
      final cls = _pieceTypeKey(p);
      nested.putIfAbsent(cust, () => {});
      nested[cust]!.putIfAbsent(cls, () => []).add(p);
      clsOrderByCust.putIfAbsent(cust, () => []);
      if (!clsOrderByCust[cust]!.contains(cls)) {
        clsOrderByCust[cust]!.add(cls);
      }
      if (!custOrder.contains(cust)) {
        custOrder.add(cust);
      }
    }

    final blocks = <Widget>[];
    final cs = Theme.of(context).colorScheme;

    for (var ci = 0; ci < custOrder.length; ci++) {
      final cust = custOrder[ci];
      if (ci > 0) blocks.add(const SizedBox(height: 14));

      blocks.add(
        Material(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              cust,
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
      blocks.add(const SizedBox(height: 6));

      for (var ki = 0; ki < clsOrderByCust[cust]!.length; ki++) {
        final cls = clsOrderByCust[cust]![ki];
        final rows = nested[cust]![cls]!;
        if (rows.isEmpty) continue;
        final title = _pieceTypeTitleFromKey(cls);

        if (ki > 0) blocks.add(const SizedBox(height: 10));

        blocks.add(
          Material(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        );
        blocks.add(const SizedBox(height: 6));

        blocks.add(
          Material(
            color: cs.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 2, right: 4),
              child: SizedBox(
                width: _reportTableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_reportHeaderRow(), ...rows.map(_reportDataRow)],
                ),
              ),
            ),
          ),
        );
        blocks.add(_productGroupFooter(rows));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
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
                    '• Lista po kupcu i tipu komada (prefiks šifre: GK, PP, SK, MA, PM)\n'
                    '• Filteri: kupac, klasifikacija, magacin (zaliha po magacinu ili sve ukupno)\n'
                    '• Opcionalno u Firestoreu: standardUnitPrice, currency, sek. klasifikacija (import)\n'
                    '• Kreiranje i uređivanje proizvoda, status, Excel import\n'
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
                  _buildAxisFilters(),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverToBoxAdapter(
                child: _buildGroupedProductReport(list),
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
