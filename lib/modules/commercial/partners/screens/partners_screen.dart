import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/standard_list_components.dart';
import '../models/partner_models.dart';
import '../services/customers_service.dart';
import '../services/suppliers_service.dart';
import 'partner_customer_edit_screen.dart';
import 'partner_supplier_edit_screen.dart';
import 'supplier_evaluations_screen.dart';

class PartnersScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const PartnersScreen({super.key, required this.companyData});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen>
    with SingleTickerProviderStateMixin {
  final CustomersService _customersService = CustomersService();
  final SuppliersService _suppliersService = SuppliersService();

  late final TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;

  List<CustomerModel> _customers = const [];
  List<SupplierModel> _suppliers = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canManageCustomers =>
      _role == 'admin' || _role == 'production_manager' || _role == 'sales';

  bool get _canManageSuppliers =>
      _role == 'admin' || _role == 'production_manager' || _role == 'purchasing';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje companyId';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = _searchController.text.trim();
      final customers = await _customersService.listCustomers(
        companyId: _companyId,
        query: q,
      );
      final suppliers = await _suppliersService.listSuppliers(
        companyId: _companyId,
        query: q,
      );

      if (!mounted) return;
      setState(() {
        _customers = customers;
        _suppliers = suppliers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _openCreateCustomer() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerCustomerEditScreen(companyData: widget.companyData),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openCreateSupplier() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerSupplierEditScreen(companyData: widget.companyData),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openEditCustomer(CustomerModel c) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerCustomerEditScreen(
          companyData: widget.companyData,
          customerId: c.id,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openEditSupplier(SupplierModel s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerSupplierEditScreen(
          companyData: widget.companyData,
          supplierId: s.id,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openSupplierEvaluations(SupplierModel s) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SupplierEvaluationsScreen(companyData: widget.companyData, supplier: s),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Widget _empty(String label) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(label, style: const TextStyle(color: Colors.black54)),
    );
  }

  Widget _buildKpis() {
    final customersActive = _customers.where((e) => e.status == 'active').length;
    final suppliersActive = _suppliers.where((e) => e.status == 'active').length;
    final strategic = _suppliers.where((e) => e.isStrategic).length;
    return StandardKpiGrid(
      metrics: [
        KpiMetric(
          label: 'Kupci',
          value: _customers.length,
          color: Colors.blue,
          icon: Icons.people_outline,
        ),
        KpiMetric(
          label: 'Dobavljači',
          value: _suppliers.length,
          color: Colors.orange,
          icon: Icons.local_shipping_outlined,
        ),
        KpiMetric(
          label: 'Aktivni',
          value: customersActive + suppliersActive,
          color: Colors.green,
          icon: Icons.task_alt_rounded,
        ),
        KpiMetric(
          label: 'Strateški',
          value: strategic,
          color: Colors.deepPurple,
          icon: Icons.workspace_premium_outlined,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _tabController.index == 0
        ? _canManageCustomers
        : _canManageSuppliers;
    final createLabel = _tabController.index == 0 ? 'Novi kupac' : 'Novi dobavljač';
    final createAction = _tabController.index == 0 ? _openCreateCustomer : _openCreateSupplier;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Kupci i dobavljači'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Kupci i dobavljači'),
                  content: const Text(
                    'Master podaci partnera za komercijalni i IATF tok.\n\n'
                    '• Evidencija kupaca i dobavljača\n'
                    '• Supplier risk/approval podaci\n'
                    '• Ulaz u evaluacije dobavljača\n'
                    '• Podloga za narudžbe i traceability',
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
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Kupci'),
            Tab(text: 'Dobavljači'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (canCreate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: createAction,
                  icon: const Icon(Icons.add),
                  label: Text(createLabel),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildKpis(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: StandardSearchField(
              controller: _searchController,
              hintText: 'Pretraga (šifra / naziv)...',
              onChanged: (_) => _onSearchChanged(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                if (_customers.isEmpty && !_loading && _error == null)
                  _empty('Nema kupaca.')
                else
                  ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _customers.length,
                    itemBuilder: (context, i) {
                      final c = _customers[i];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${c.code} — ${c.name}',
                            maxLines: 3,
                          ),
                          subtitle: Text(
                            'Pravni naziv: ${c.legalName}\n'
                            'Status: ${c.status} • Tip: ${c.customerType}',
                            maxLines: 4,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _canManageCustomers ? () => _openEditCustomer(c) : null,
                        ),
                      );
                    },
                  ),
                if (_suppliers.isEmpty && !_loading && _error == null)
                  _empty('Nema dobavljača.')
                else
                  ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _suppliers.length,
                    itemBuilder: (context, i) {
                      final s = _suppliers[i];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${s.code} — ${s.name}',
                            maxLines: 3,
                          ),
                          subtitle: Text(
                            'Pravni naziv: ${s.legalName}\n'
                            'Status: ${s.status} • Tip: ${s.supplierType}\n'
                            'Risk: ${s.riskLevel} • Score: ${s.overallScore.toStringAsFixed(1)}',
                            maxLines: 5,
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit' && _canManageSuppliers) {
                                _openEditSupplier(s);
                              }
                              if (v == 'eval') {
                                _openSupplierEvaluations(s);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                enabled: _canManageSuppliers,
                                child: const Text('Uredi'),
                              ),
                              const PopupMenuItem(
                                value: 'eval',
                                child: Text('Evaluacije'),
                              ),
                            ],
                          ),
                          onTap: _canManageSuppliers ? () => _openEditSupplier(s) : null,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

