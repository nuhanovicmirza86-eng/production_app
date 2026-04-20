import 'package:flutter/material.dart';

import '../../commercial/partners/models/partner_models.dart';
import '../../commercial/partners/services/customers_service.dart';
import '../../commercial/partners/services/suppliers_service.dart';
import '../../production/products/services/product_service.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';

/// Modalni odabir `products` dokumenta (Firestore ID).
Future<String?> showQmsProductPicker({
  required BuildContext context,
  required String companyId,
}) async {
  final cid = companyId.trim();
  if (cid.isEmpty) return null;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return _QmsProductPickerBody(companyId: cid);
    },
  );
}

class _QmsProductPickerBody extends StatefulWidget {
  const _QmsProductPickerBody({required this.companyId});

  final String companyId;

  @override
  State<_QmsProductPickerBody> createState() => _QmsProductPickerBodyState();
}

class _QmsProductPickerBodyState extends State<_QmsProductPickerBody> {
  final _productService = ProductService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _productService.getProducts(
        companyId: widget.companyId,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _items);
      return;
    }
    setState(() {
      _filtered = _items.where((m) {
        final id = _s(m['productId']).toLowerCase();
        final code = _s(m['productCode']).toLowerCase();
        final name = _s(m['productName']).toLowerCase();
        return id.contains(q) || code.contains(q) || name.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Odaberi proizvod',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Pretraži šifru, naziv ili ID…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final m = _filtered[i];
                  final id = _s(m['productId']);
                  final code = _s(m['productCode']);
                  final name = _s(m['productName']);
                  final title = code.isNotEmpty
                      ? code
                      : (name.isNotEmpty ? name : id);
                  final sub = [
                    if (name.isNotEmpty && name != title) name,
                    if (id.isNotEmpty) 'ID: $id',
                  ].join(' · ');
                  return ListTile(
                    title: Text(title),
                    subtitle: sub.isEmpty ? null : Text(sub),
                    onTap: () => Navigator.pop(context, id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Modalni odabir kontrolnog plana (Callable lista).
Future<String?> showQmsControlPlanPicker({
  required BuildContext context,
  required String companyId,
  String? productIdFilter,
}) async {
  final cid = companyId.trim();
  if (cid.isEmpty) return null;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return _QmsControlPlanPickerBody(
        companyId: cid,
        productIdFilter: productIdFilter?.trim(),
      );
    },
  );
}

class _QmsControlPlanPickerBody extends StatefulWidget {
  const _QmsControlPlanPickerBody({
    required this.companyId,
    this.productIdFilter,
  });

  final String companyId;
  final String? productIdFilter;

  @override
  State<_QmsControlPlanPickerBody> createState() =>
      _QmsControlPlanPickerBodyState();
}

class _QmsControlPlanPickerBodyState extends State<_QmsControlPlanPickerBody> {
  final _svc = QualityCallableService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<QmsControlPlanRow> _rows = const [];
  List<QmsControlPlanRow> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var rows = await _svc.listControlPlans(companyId: widget.companyId);
      final pf = widget.productIdFilter;
      if (pf != null && pf.isNotEmpty) {
        rows = rows.where((r) => r.productId == pf).toList();
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _filtered = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _rows);
      return;
    }
    setState(() {
      _filtered = _rows.where((r) {
        final code = (r.controlPlanCode ?? '').toLowerCase();
        final title = r.title.toLowerCase();
        final pid = r.productId.toLowerCase();
        final id = r.id.toLowerCase();
        return code.contains(q) ||
            title.contains(q) ||
            pid.contains(q) ||
            id.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Odaberi kontrolni plan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Pretraži naslov, šifru, proizvod…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.productIdFilter != null &&
                          widget.productIdFilter!.isNotEmpty
                      ? 'Nema kontrolnog plana za odabrani proizvod.'
                      : 'Nema kontrolnih planova.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final r = _filtered[i];
                  final code = r.controlPlanCode ?? r.id;
                  return ListTile(
                    title: Text(r.title.isNotEmpty ? r.title : code),
                    subtitle: Text(
                      '$code · proizvod: ${r.productId} · ${r.status}',
                    ),
                    onTap: () => Navigator.pop(context, r.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// --- Kupci / dobavljači (reklamacije) ---

/// Vraća Firestore ID dokumenta `customers/`.
Future<String?> showQmsCustomerPicker({
  required BuildContext context,
  required String companyId,
}) async {
  final cid = companyId.trim();
  if (cid.isEmpty) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _QmsCustomerPickerBody(companyId: cid),
  );
}

class _QmsCustomerPickerBody extends StatefulWidget {
  const _QmsCustomerPickerBody({required this.companyId});

  final String companyId;

  @override
  State<_QmsCustomerPickerBody> createState() => _QmsCustomerPickerBodyState();
}

class _QmsCustomerPickerBodyState extends State<_QmsCustomerPickerBody> {
  final _svc = CustomersService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<CustomerModel> _items = const [];
  List<CustomerModel> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listCustomers(companyId: widget.companyId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _items);
      return;
    }
    setState(() {
      _filtered = _items.where((m) {
        final hay =
            '${m.code.toLowerCase()} ${m.name.toLowerCase()} ${m.legalName.toLowerCase()}';
        return hay.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Odaberi kupca',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Pretraži šifru ili naziv…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final m = _filtered[i];
                  return ListTile(
                    title: Text(m.name.isNotEmpty ? m.name : m.code),
                    subtitle: Text('${m.code} · ${m.id}'),
                    onTap: () => Navigator.pop(context, m.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Vraća Firestore ID dokumenta `suppliers/`.
Future<String?> showQmsSupplierPicker({
  required BuildContext context,
  required String companyId,
}) async {
  final cid = companyId.trim();
  if (cid.isEmpty) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _QmsSupplierPickerBody(companyId: cid),
  );
}

class _QmsSupplierPickerBody extends StatefulWidget {
  const _QmsSupplierPickerBody({required this.companyId});

  final String companyId;

  @override
  State<_QmsSupplierPickerBody> createState() => _QmsSupplierPickerBodyState();
}

class _QmsSupplierPickerBodyState extends State<_QmsSupplierPickerBody> {
  final _svc = SuppliersService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<SupplierModel> _items = const [];
  List<SupplierModel> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listSuppliers(companyId: widget.companyId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _items);
      return;
    }
    setState(() {
      _filtered = _items.where((m) {
        final hay =
            '${m.code.toLowerCase()} ${m.name.toLowerCase()} ${m.legalName.toLowerCase()}';
        return hay.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Odaberi dobavljača',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Pretraži šifru ili naziv…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final m = _filtered[i];
                  return ListTile(
                    title: Text(m.name.isNotEmpty ? m.name : m.code),
                    subtitle: Text('${m.code} · ${m.id}'),
                    onTap: () => Navigator.pop(context, m.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
