import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../logistics/inventory/widgets/product_warehouse_stock_section.dart';
import '../../bom/services/bom_service.dart';
import '../services/product_lookup_service.dart';
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
  final BomService _bomService = BomService();
  final ProductLookupService _lookupService = ProductLookupService();

  late final TabController _tabController;

  bool _isLoading = true;
  bool _isBomLoading = false;
  bool _isSavingBomItem = false;
  bool _isCreatingBomVersion = false;
  bool _isBomHistoryLoading = false;

  String? _errorMessage;
  String? _bomError;

  Map<String, dynamic>? _product;
  Map<String, dynamic>? _activeBom;

  String _selectedBomClassification = 'PRIMARY';
  List<Map<String, dynamic>> _bomItems = [];
  List<Map<String, dynamic>> _bomHistory = [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _productId => widget.productId.trim();

  String get _plantKeyHint =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  String get _userId {
    final fromCompanyData = (widget.companyData['userId'] ?? '')
        .toString()
        .trim();
    if (fromCompanyData.isNotEmpty) return fromCompanyData;

    final fromProduct = (_product?['createdBy'] ?? '').toString().trim();
    return fromProduct;
  }

  bool get _canEdit => _role == 'admin' || _role == 'production_manager';

  String _s(dynamic value) => (value ?? '').toString().trim();

  double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_s(value).replaceAll(',', '.')) ?? 0;
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';

    DateTime? dateTime;
    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) {
        dateTime = parsed;
      }
    }

    if (dateTime == null) {
      final raw = _s(value);
      return raw.isEmpty ? '-' : raw;
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  Future<String> _createNextBomVersionForChange() async {
    if (_companyId.isEmpty || _productId.isEmpty || _userId.isEmpty) {
      throw Exception('Nedostaje companyId, productId ili userId.');
    }

    return _bomService.createNewBomVersion(
      companyId: _companyId,
      productId: _productId,
      classification: _selectedBomClassification,
      changedBy: _userId,
    );
  }

  Future<Map<String, dynamic>> _findCopiedItemInNewBom({
    required String newBomId,
    required Map<String, dynamic> sourceItem,
  }) async {
    final sourceLineId = _s(sourceItem['lineId']);

    final newItems = await _bomService.getBomItems(
      companyId: _companyId,
      bomId: newBomId,
    );

    if (sourceLineId.isNotEmpty) {
      for (final item in newItems) {
        if (_s(item['lineId']) == sourceLineId) {
          return item;
        }
      }
    }

    for (final item in newItems) {
      if (_s(sourceItem['componentProductId']) ==
              _s(item['componentProductId']) &&
          _s(sourceItem['componentCode']) == _s(item['componentCode']) &&
          _s(sourceItem['componentName']) == _s(item['componentName']) &&
          _d(sourceItem['qtyPerUnit']) == _d(item['qtyPerUnit']) &&
          _s(sourceItem['unit']) == _s(item['unit']) &&
          _s(sourceItem['note']) == _s(item['note'])) {
        return item;
      }
    }

    throw Exception('Nije pronađena odgovarajuća stavka u novoj BOM verziji.');
  }

  Future<void> _loadBomHistory() async {
    if (_companyId.isEmpty || _productId.isEmpty) {
      setState(() {
        _bomHistory = [];
      });
      return;
    }

    setState(() {
      _isBomHistoryLoading = true;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('boms')
          .where('companyId', isEqualTo: _companyId)
          .where('productId', isEqualTo: _productId)
          .where('classification', isEqualTo: _selectedBomClassification)
          .get();

      final history = query.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      history.sort((a, b) {
        final aTime = a['changedAt'];
        final bTime = b['changedAt'];

        final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
        final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

        return bMs.compareTo(aMs);
      });

      if (!mounted) return;

      setState(() {
        _bomHistory = history;
        _isBomHistoryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _bomHistory = [];
        _isBomHistoryLoading = false;
      });
    }
  }

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

      await _loadBom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppErrorMapper.toMessage(e);
        _isLoading = false;
        _product = null;
      });
    }
  }

  Future<void> _loadBom() async {
    if (_companyId.isEmpty || _productId.isEmpty || _userId.isEmpty) {
      setState(() {
        _bomItems = [];
        _activeBom = null;
        _bomHistory = [];
        _bomError = _userId.isEmpty
            ? 'Nedostaje userId za učitavanje sastavnice.'
            : null;
      });
      return;
    }

    setState(() {
      _isBomLoading = true;
      _bomError = null;
    });

    try {
      final result = await _bomService.ensureBomAndLoad(
        companyId: _companyId,
        productId: _productId,
        classification: _selectedBomClassification,
        userId: _userId,
      );

      if (!mounted) return;

      setState(() {
        _activeBom = Map<String, dynamic>.from(
          result['bom'] as Map<String, dynamic>? ?? <String, dynamic>{},
        );
        _bomItems = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _isBomLoading = false;
      });

      await _loadBomHistory();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _bomError = AppErrorMapper.toMessage(e);
        _activeBom = null;
        _bomItems = [];
        _bomHistory = [];
        _isBomLoading = false;
      });
    }
  }

  Future<void> _onClassificationChanged(String? value) async {
    if (value == null || value == _selectedBomClassification) return;

    setState(() {
      _selectedBomClassification = value;
    });

    await _loadBom();
  }

  Future<void> _createNewBomVersion() async {
    if (!_canEdit ||
        _companyId.isEmpty ||
        _productId.isEmpty ||
        _userId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nova BOM verzija'),
          content: Text(
            'Kreirati novu verziju sastavnice za klasifikaciju "$_selectedBomClassification"? '
            'Trenutna aktivna verzija će postati neaktivna, a nova verzija će preuzeti postojeće stavke.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Kreiraj verziju'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isCreatingBomVersion = true;
    });

    try {
      await _bomService.createNewBomVersion(
        companyId: _companyId,
        productId: _productId,
        classification: _selectedBomClassification,
        changedBy: _userId,
      );

      if (!mounted) return;

      await _loadBom();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nova BOM verzija je uspješno kreirana.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (!mounted) return;
      setState(() {
        _isCreatingBomVersion = false;
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

  Future<void> _openAddBomItemDialog() async {
    if (!_canEdit) return;

    final bomId = _s(_activeBom?['id']);
    if (bomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktivna sastavnica nije učitana. Pokušaj ponovo.'),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();

    ProductLookupItem? selectedProduct;
    List<ProductLookupItem> searchResults = [];
    bool isSearching = false;
    bool dialogClosed = false;

    final searchController = TextEditingController();
    final qtyController = TextEditingController();
    final unitController = TextEditingController(text: 'KOM');
    final noteController = TextEditingController();
    final qtyFocusNode = FocusNode();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeDialogSetState(VoidCallback fn) {
              if (!dialogClosed && dialogContext.mounted) {
                setDialogState(fn);
              }
            }

            void closeDialog(bool result) {
              if (dialogClosed || !dialogContext.mounted) return;
              dialogClosed = true;
              FocusScope.of(dialogContext).unfocus();
              Navigator.of(dialogContext).pop(result);
            }

            Future<void> searchProducts(String value) async {
              final query = value.trim();

              if (query.isEmpty) {
                safeDialogSetState(() {
                  searchResults = [];
                  isSearching = false;
                });
                return;
              }

              safeDialogSetState(() {
                isSearching = true;
              });

              try {
                final results = await _lookupService.searchProducts(
                  companyId: _companyId,
                  query: query,
                );

                if (!mounted || dialogClosed || !dialogContext.mounted) {
                  return;
                }

                safeDialogSetState(() {
                  searchResults = results
                      .where((item) => item.productId != _productId)
                      .toList();
                  isSearching = false;
                });
              } catch (e) {
                if (!mounted || dialogClosed || !dialogContext.mounted) {
                  return;
                }

                safeDialogSetState(() {
                  searchResults = [];
                  isSearching = false;
                });

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(AppErrorMapper.toMessage(e))),
                );
              }
            }

            Future<void> save() async {
              if (selectedProduct == null) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Izaberi komponentu iz šifrarnika.'),
                  ),
                );
                return;
              }

              if (selectedProduct!.productId == _productId) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Proizvod ne može biti komponenta samom sebi.',
                    ),
                  ),
                );
                return;
              }

              if (!(formKey.currentState?.validate() ?? false)) return;

              safeDialogSetState(() {
                _isSavingBomItem = true;
              });

              try {
                final newBomId = await _createNextBomVersionForChange();

                await _bomService.addBomItem(
                  companyId: _companyId,
                  bomId: newBomId,
                  componentProductId: selectedProduct!.productId,
                  componentCode: selectedProduct!.productCode,
                  componentName: selectedProduct!.productName,
                  qtyPerUnit: _d(qtyController.text),
                  unit: (selectedProduct!.unit ?? '').trim().isNotEmpty
                      ? selectedProduct!.unit!.trim()
                      : unitController.text.trim(),
                  createdBy: _userId,
                  note: noteController.text.trim(),
                );

                if (!mounted || dialogClosed || !dialogContext.mounted) {
                  return;
                }
                closeDialog(true);
              } catch (e) {
                if (!mounted || dialogClosed || !dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(AppErrorMapper.toMessage(e))),
                );
                safeDialogSetState(() {
                  _isSavingBomItem = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Dodaj komponentu'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Komponenta se bira iz šifrarnika proizvoda. Unosi se normativ za 1 komad gotovog proizvoda.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: 'Pretraga komponente',
                            hintText: 'Unesi šifru ili naziv',
                            helperText: '🛈 Primjer: CEP, Etiketa, Ambalaža',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: searchProducts,
                        ),
                        const SizedBox(height: 12),
                        if (isSearching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (!isSearching && searchResults.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final item = searchResults[index];
                                final isSelected =
                                    selectedProduct?.productId ==
                                    item.productId;

                                return ListTile(
                                  selected: isSelected,
                                  title: Text(
                                    '${item.productCode} - ${item.productName}',
                                  ),
                                  subtitle: Text(
                                    (item.unit ?? '').trim().isEmpty
                                        ? 'JM: -'
                                        : 'JM: ${item.unit}',
                                  ),
                                  onTap: () {
                                    safeDialogSetState(() {
                                      selectedProduct = item;
                                      searchController.text =
                                          '${item.productCode} - ${item.productName}';
                                      searchResults = [];
                                      isSearching = false;
                                      qtyController.clear();
                                      noteController.clear();

                                      if ((item.unit ?? '').trim().isNotEmpty) {
                                        unitController.text = item.unit!.trim();
                                      }
                                    });

                                    formKey.currentState?.validate();

                                    if (!dialogClosed &&
                                        dialogContext.mounted) {
                                      FocusScope.of(
                                        dialogContext,
                                      ).requestFocus(qtyFocusNode);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        if (!isSearching &&
                            searchController.text.trim().isNotEmpty &&
                            searchResults.isEmpty &&
                            selectedProduct == null)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Nema rezultata za zadanu pretragu.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (selectedProduct == null)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '🛈 Izaberi komponentu iz liste rezultata.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Odabrano: ${selectedProduct!.productCode} - ${selectedProduct!.productName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: qtyController,
                          focusNode: qtyFocusNode,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Količina za 1 komad',
                            hintText: 'npr. 1 ili 0.05',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final qty = _d(value);
                            if (qty <= 0) {
                              return 'Količina mora biti > 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: unitController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: 'Jedinica mjere',
                            hintText: 'npr. KOM',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Unesi jedinicu mjere.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: 'Napomena',
                            hintText: 'opcionalno',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSavingBomItem ? null : () => closeDialog(false),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: _isSavingBomItem ? null : save,
                  child: const Text('Sačuvaj'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _loadBom();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Komponenta je dodana u sastavnicu.')),
      );
    }
  }

  Future<void> _openEditBomItemDialog(Map<String, dynamic> item) async {
    if (!_canEdit) return;

    final itemId = _s(item['id']);
    if (itemId.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    bool dialogClosed = false;

    final qtyController = TextEditingController(text: _s(item['qtyPerUnit']));
    final unitController = TextEditingController(text: _s(item['unit']));
    final noteController = TextEditingController(text: _s(item['note']));

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void safeDialogSetState(VoidCallback fn) {
              if (!dialogClosed && dialogContext.mounted) {
                setDialogState(fn);
              }
            }

            void closeDialog(bool result) {
              if (dialogClosed || !dialogContext.mounted) return;
              dialogClosed = true;
              FocusScope.of(dialogContext).unfocus();
              Navigator.of(dialogContext).pop(result);
            }

            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              safeDialogSetState(() {
                _isSavingBomItem = true;
              });

              try {
                final newBomId = await _createNextBomVersionForChange();
                final copiedItem = await _findCopiedItemInNewBom(
                  newBomId: newBomId,
                  sourceItem: item,
                );

                await _bomService.updateBomItem(
                  itemId: _s(copiedItem['id']),
                  qtyPerUnit: _d(qtyController.text),
                  unit: unitController.text.trim(),
                  note: noteController.text.trim(),
                  updatedBy: _userId,
                );

                if (!mounted || dialogClosed || !dialogContext.mounted) {
                  return;
                }
                closeDialog(true);
              } catch (e) {
                if (!mounted || dialogClosed || !dialogContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(AppErrorMapper.toMessage(e))),
                );
                safeDialogSetState(() {
                  _isSavingBomItem = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Uredi komponentu'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_s(item['componentCode'])} - ${_s(item['componentName'])}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: qtyController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Količina za 1 komad',
                            hintText: 'npr. 1 ili 0.05',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final qty = _d(value);
                            if (qty <= 0) {
                              return 'Količina mora biti > 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: unitController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: 'Jedinica mjere',
                            hintText: 'npr. KOM',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Unesi jedinicu mjere.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: 'Napomena',
                            hintText: 'opcionalno',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSavingBomItem ? null : () => closeDialog(false),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: _isSavingBomItem ? null : save,
                  child: const Text('Sačuvaj'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _loadBom();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Komponenta je ažurirana.')));
    }
  }

  Future<void> _deleteBomItem(Map<String, dynamic> item) async {
    if (!_canEdit) return;

    final itemId = _s(item['id']);
    if (itemId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Obriši komponentu'),
          content: Text(
            'Da li želiš obrisati komponentu "${_s(item['componentName'])}" iz sastavnice?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Obriši'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final newBomId = await _createNextBomVersionForChange();
      final copiedItem = await _findCopiedItemInNewBom(
        newBomId: newBomId,
        sourceItem: item,
      );

      await _bomService.deleteBomItem(itemId: _s(copiedItem['id']));

      if (!mounted) return;

      await _loadBom();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Komponenta je obrisana.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
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
        const SizedBox(height: 12),
        ProductWarehouseStockSection(
          companyId: _companyId,
          productId: _productId,
          plantKey: _plantKeyHint.isNotEmpty ? _plantKeyHint : null,
          fallbackUnit: _s(product['unit']),
        ),
      ],
    );
  }

  Widget _buildBomItemsCard() {
    if (_isBomLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bomError != null && _bomError!.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bomError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadBom,
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    if (_bomItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nema stavki u sastavnici za izabranu klasifikaciju.'),
          const SizedBox(height: 12),
          if (_canEdit)
            OutlinedButton.icon(
              onPressed: _openAddBomItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj prvu komponentu'),
            ),
        ],
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < _bomItems.length; i++) ...[
            ListTile(
              title: Text(
                _s(_bomItems[i]['componentName']).isEmpty
                    ? '-'
                    : _s(_bomItems[i]['componentName']),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_s(_bomItems[i]['componentCode'])} • '
                    '${_s(_bomItems[i]['qtyPerUnit'])} ${_s(_bomItems[i]['unit'])}',
                  ),
                  if (_s(_bomItems[i]['note']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _s(_bomItems[i]['note']),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                ],
              ),
              trailing: _canEdit
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditBomItemDialog(_bomItems[i]);
                        } else if (value == 'delete') {
                          _deleteBomItem(_bomItems[i]);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Uredi'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Obriši'),
                        ),
                      ],
                    )
                  : null,
            ),
            if (i != _bomItems.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildBomHistoryCard() {
    if (_isBomHistoryLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bomHistory.isEmpty) {
      return const Text('Nema evidentiranih verzija sastavnice.');
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < _bomHistory.length; i++) ...[
            ListTile(
              leading: Icon(
                (_bomHistory[i]['isActive'] ?? false) == true
                    ? Icons.check_circle
                    : Icons.history,
                color: (_bomHistory[i]['isActive'] ?? false) == true
                    ? Colors.green
                    : Colors.blueGrey,
              ),
              title: Text(
                _s(_bomHistory[i]['version']).isEmpty
                    ? 'Verzija -'
                    : 'Verzija ${_s(_bomHistory[i]['version'])}',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promijenio: ${_s(_bomHistory[i]['changedBy']).isEmpty ? '-' : _s(_bomHistory[i]['changedBy'])}',
                  ),
                  Text(
                    'Promjena: ${_formatDateTime(_bomHistory[i]['changedAt'])}',
                  ),
                  Text(
                    'Efektivno od: ${_formatDateTime(_bomHistory[i]['effectiveFrom'])}',
                  ),
                ],
              ),
              trailing: (_bomHistory[i]['isActive'] ?? false) == true
                  ? const Text(
                      'AKTIVNA',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            if (i != _bomHistory.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildBomTab(Map<String, dynamic> product) {
    final packagingQty = _s(product['packagingQty']);
    final activeBomId = _s(_activeBom?['id']);
    final activeBomVersion = _s(_activeBom?['version']);
    final isActiveBom = (_activeBom?['isActive'] ?? false) == true;
    final effectiveFrom = _formatDateTime(_activeBom?['effectiveFrom']);
    final changedAt = _formatDateTime(_activeBom?['changedAt']);
    final changedBy = _s(_activeBom?['changedBy']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Sastavnica',
          subtitle:
              '🛈 Sastavnica prikazuje šta je potrebno za proizvodnju 1 komada gotovog proizvoda. Svaka klasifikacija ima svoju sastavnicu.',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Primjer upisa: Čep 1 KOM, Etiketa 1 KOM, Vrećica 0.05 KOM',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBomClassification,
              items: const [
                DropdownMenuItem(value: 'PRIMARY', child: Text('Primarna')),
                DropdownMenuItem(value: 'SECONDARY', child: Text('Sekundarna')),
                DropdownMenuItem(
                  value: 'TRANSPORT',
                  child: Text('Transportna'),
                ),
              ],
              onChanged: _onClassificationChanged,
              decoration: const InputDecoration(
                labelText: 'Klasifikacija sastavnice',
                helperText: '🛈 Svaka klasifikacija ima svoju sastavnicu.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: packagingQty,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Količina pakovanja',
                hintText: 'npr. 12',
                helperText:
                    '🛈 Broj komada u jednom pakovanju koji će se ispisivati na etiketi.',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) async {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed == null) return;

                try {
                  await _productService.updateProduct(
                    productId: _productId,
                    companyId: _companyId,
                    updatedBy: _userId,
                    packagingQty: parsed,
                  );
                } catch (_) {}
              },
            ),
            const SizedBox(height: 16),
            if (activeBomId.isNotEmpty || activeBomVersion.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeBomId.isNotEmpty)
                      Text(
                        'Aktivna sastavnica: $activeBomId',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (activeBomVersion.isNotEmpty) ...[
                      if (activeBomId.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        'Verzija: $activeBomVersion',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${isActiveBom ? 'Aktivna' : 'Neaktivna'}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Efektivno od: $effectiveFrom',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zadnja promjena: $changedAt',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Promijenio: ${changedBy.isEmpty ? '-' : changedBy}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            if (_canEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    _isBomLoading || _isCreatingBomVersion || _isSavingBomItem
                    ? null
                    : _createNewBomVersion,
                icon: _isCreatingBomVersion
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_all_outlined),
                label: Text(
                  _isCreatingBomVersion
                      ? 'Kreiram novu verziju...'
                      : 'Kreiraj novu verziju',
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Komponente',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildBomItemsCard(),
            if (_canEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSavingBomItem ? null : _openAddBomItemDialog,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj komponentu'),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Historija verzija',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildBomHistoryCard(),
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
