import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/standard_list_components.dart';
import '../data/activity_sector_catalog.dart';
import '../data/activity_sector_visibility.dart';
import '../models/partner_models.dart';
import '../services/customers_service.dart';
import '../services/suppliers_service.dart';
import 'activity_sector_settings_screen.dart';
import 'activity_sectors_catalog_screen.dart';
import 'partner_customer_edit_screen.dart';
import '../../assessment/screens/unified_assessment_run_screen.dart';
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

  /// `all` | `A` | `B` | `C` | `unrated`
  String _customerAbcFilter = 'all';
  String? _customerActivityFilter;

  String _supplierAbcFilter = 'all';
  String? _supplierActivityFilter;

  /// `enabledActivitySectorCodes` iz `companies/{id}` (osvježeno u `_load`).
  dynamic _companyDocActivityCodes;

  Map<String, dynamic> get _companyDataForPartners => {
    ...widget.companyData,
    'enabledActivitySectorCodes':
        _companyDocActivityCodes ??
        widget.companyData['enabledActivitySectorCodes'],
  };

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim().toLowerCase();

  bool get _canManageCustomers =>
      _role == 'admin' ||
      _role == 'production_manager' ||
      _role == 'sales' ||
      _role == 'logistics_manager';

  bool get _canManageSuppliers =>
      _role == 'admin' ||
      _role == 'production_manager' ||
      _role == 'purchasing' ||
      _role == 'logistics_manager';

  /// Usklađeno s `assertCallableActor` u `refreshSupplierOperationalSignals`.
  bool get _canRefreshSupplierOperational =>
      _role == 'admin' ||
      _role == 'purchasing' ||
      _role == 'production_manager' ||
      _role == 'supervisor' ||
      _role == 'logistics_manager';

  bool get _canManageActivitySectors =>
      _role == 'admin' ||
      _role == 'logistics_manager' ||
      _role == 'production_manager' ||
      _role == 'super_admin';

  bool _opRefreshing = false;

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
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
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

      final compSnap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .get();
      final enabledRaw = compSnap.data()?['enabledActivitySectorCodes'];

      if (!mounted) return;
      setState(() {
        _customers = customers;
        _suppliers = suppliers;
        _companyDocActivityCodes = enabledRaw;
        _loading = false;
        _pruneActivityFiltersIfStale();
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
        builder: (_) =>
            PartnerCustomerEditScreen(companyData: _companyDataForPartners),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openCreateSupplier() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartnerSupplierEditScreen(companyData: _companyDataForPartners),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openEditCustomer(CustomerModel c) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerCustomerEditScreen(
          companyData: _companyDataForPartners,
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
          companyData: _companyDataForPartners,
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
        builder: (_) => SupplierEvaluationsScreen(
          companyData: widget.companyData,
          supplier: s,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _openSupplierUnifiedAssessment(SupplierModel s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedAssessmentRunScreen(
          companyId: _companyId,
          plantKey: (widget.companyData['plantKey'] ?? '').toString().trim(),
          entityType: 'supplier',
          entityId: s.id,
          entityLabel: '${s.code} — ${s.name}',
          userRole: _role,
        ),
      ),
    );
  }

  Future<void> _refreshSupplierOperational(SupplierModel s) async {
    setState(() {
      _opRefreshing = true;
      _error = null;
    });
    try {
      await _suppliersService.refreshOperationalSignals(
        companyId: _companyId,
        supplierId: s.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ažuriran automatski skor: ${s.code}')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _opRefreshing = false);
    }
  }

  void _showSupplierOperationalDetails(SupplierModel s) {
    final oa = s.operationalAuto;
    if (oa == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Automatski skor: ${s.code}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ukupan skor: ${oa.score.toStringAsFixed(0)} / 100'),
              const SizedBox(height: 8),
              Text('Algoritam: v${oa.algorithmVersion}'),
              const Divider(height: 24),
              Text(
                'Isporuka (kasne stavke): '
                '${oa.deliveryScore?.toStringAsFixed(1) ?? '—'}',
              ),
              Text(
                'Tačnost količine (skor): '
                '${oa.qtyScore?.toStringAsFixed(1) ?? '—'}',
              ),
              Text('Kvalitet (agregat): ${oa.qualityScore.toStringAsFixed(1)}'),
              Text(
                'Udio kasnih stavki: '
                '${(oa.lateLineRate * 100).toStringAsFixed(1)} %',
              ),
              if (oa.avgQtyFillRatio != null)
                Text(
                  'Prosjek primljeno / naručeno: '
                  '${oa.avgQtyFillRatio!.toStringAsFixed(3)}',
                ),
              Text('Stavki dobavljačkih narudžbi: ${oa.linesAnalyzed}'),
              const Divider(height: 24),
              Text('NC (na kartici dobavljača): ${oa.nonconformanceCount}'),
              Text('Reklamacije (broj na kartici): ${oa.claimCount}'),
              Text(
                'Povezani zapisi quality_nonconformities: '
                '${oa.linkedNonconformityCount}',
              ),
              Text(
                'Odstupanje količine (zatvorene stavke): '
                '${oa.qtyMismatchLines}',
              ),
              Text('Odbijene / vraćene stavke: ${oa.rejectedLines}'),
              const SizedBox(height: 12),
              Text(
                'Brojeve NC i reklamacija na kartici unosiš ručno. Zatvorene '
                'stavke narudžbe i evidencija neusklađenosti (ako postoji) '
                'automatski utiču na agregat kvaliteta.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRefreshAllSuppliersOperational() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Osvježi automatski skor (svi dobavljači)'),
        content: const Text(
          'Ponovo računa skor iz narudžbi za najviše 40 dobavljača '
          '(redoslijed u bazi). Nastaviti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pokreni'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _opRefreshing = true;
      _error = null;
    });
    try {
      await _suppliersService.refreshOperationalSignals(
        companyId: _companyId,
        allSuppliers: true,
        limit: 40,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grupno ažuriranje automatskog skora završeno.'),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _opRefreshing = false);
    }
  }

  Future<void> _openCustomerUnifiedAssessment(CustomerModel c) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedAssessmentRunScreen(
          companyId: _companyId,
          plantKey: (widget.companyData['plantKey'] ?? '').toString().trim(),
          entityType: 'customer',
          entityId: c.id,
          entityLabel: '${c.code} — ${c.name}',
          userRole: _role,
        ),
      ),
    );
  }

  Widget _empty(String label) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(label, style: const TextStyle(color: Colors.black54)),
    );
  }

  Color _partnerAccent(String partnerRatingClass, bool isStrategic) {
    switch (partnerRatingClass) {
      case 'A':
        return Colors.green.shade600;
      case 'B':
        return Colors.orange.shade700;
      case 'C':
        return isStrategic ? Colors.deepOrange.shade800 : Colors.red.shade700;
      default:
        return Colors.blueGrey.shade300;
    }
  }

  String _abcSubtitle(String cls) {
    switch (cls) {
      case 'A':
        return 'A (dobar)';
      case 'B':
        return 'B (upozorenje)';
      case 'C':
        return 'C (nepouzdan)';
      default:
        return '— (nije procijenjeno)';
    }
  }

  List<CustomerModel> get _visibleCustomers {
    var list = _customers;
    if (_customerAbcFilter != 'all') {
      list = list
          .where((c) => c.partnerRatingClass == _customerAbcFilter)
          .toList();
    }
    if (_customerActivityFilter != null &&
        _customerActivityFilter!.trim().isNotEmpty) {
      final f = _customerActivityFilter!.trim();
      list = list
          .where((c) => (c.activitySector ?? '').trim() == f)
          .toList();
    }
    return list;
  }

  List<SupplierModel> get _visibleSuppliers {
    var list = _suppliers;
    if (_supplierAbcFilter != 'all') {
      list = list
          .where((s) => s.partnerRatingClass == _supplierAbcFilter)
          .toList();
    }
    if (_supplierActivityFilter != null &&
        _supplierActivityFilter!.trim().isNotEmpty) {
      final f = _supplierActivityFilter!.trim();
      list = list
          .where((s) => (s.activitySector ?? '').trim() == f)
          .toList();
    }
    return list;
  }

  void _pruneActivityFiltersIfStale() {
    final visible = resolveVisibleActivitySectors(
      _companyDataForPartners['enabledActivitySectorCodes'],
    ).map((e) => e.code).toSet();
    if (_customerActivityFilter != null &&
        !visible.contains(_customerActivityFilter)) {
      _customerActivityFilter = null;
    }
    if (_supplierActivityFilter != null &&
        !visible.contains(_supplierActivityFilter)) {
      _supplierActivityFilter = null;
    }
  }

  Future<void> _openActivitySectorSettings() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ActivitySectorSettingsScreen(
          companyData: _companyDataForPartners,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Widget _customerFilterBar() {
    if (_customers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter: kategorija (ABC)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Sve'),
                selected: _customerAbcFilter == 'all',
                onSelected: (_) => setState(() {
                  _customerAbcFilter = 'all';
                }),
              ),
              FilterChip(
                label: const Text('A'),
                selectedColor: Colors.green.shade100,
                labelStyle: TextStyle(
                  color: _customerAbcFilter == 'A'
                      ? Colors.green.shade900
                      : null,
                  fontWeight: FontWeight.w600,
                ),
                selected: _customerAbcFilter == 'A',
                onSelected: (_) => setState(() => _customerAbcFilter = 'A'),
              ),
              FilterChip(
                label: const Text('B'),
                selectedColor: Colors.orange.shade100,
                selected: _customerAbcFilter == 'B',
                onSelected: (_) => setState(() => _customerAbcFilter = 'B'),
              ),
              FilterChip(
                label: const Text('C'),
                selectedColor: Colors.red.shade100,
                selected: _customerAbcFilter == 'C',
                onSelected: (_) => setState(() => _customerAbcFilter = 'C'),
              ),
              FilterChip(
                label: const Text('Bez procjene'),
                selected: _customerAbcFilter == 'unrated',
                onSelected: (_) =>
                    setState(() => _customerAbcFilter = 'unrated'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _customerActivityFilter,
            decoration: const InputDecoration(
              labelText: 'Djelatnost',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sve djelatnosti'),
              ),
              ...resolveVisibleActivitySectors(
                _companyDataForPartners['enabledActivitySectorCodes'],
              ).map(
                (e) => DropdownMenuItem<String?>(
                  value: e.code,
                  child: Text(
                    e.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _customerActivityFilter = v),
          ),
        ],
      ),
    );
  }

  Widget _supplierFilterBar() {
    if (_suppliers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter: kategorija (ABC)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Sve'),
                selected: _supplierAbcFilter == 'all',
                onSelected: (_) => setState(() {
                  _supplierAbcFilter = 'all';
                }),
              ),
              FilterChip(
                label: const Text('A'),
                selectedColor: Colors.green.shade100,
                selected: _supplierAbcFilter == 'A',
                onSelected: (_) => setState(() => _supplierAbcFilter = 'A'),
              ),
              FilterChip(
                label: const Text('B'),
                selectedColor: Colors.orange.shade100,
                selected: _supplierAbcFilter == 'B',
                onSelected: (_) => setState(() => _supplierAbcFilter = 'B'),
              ),
              FilterChip(
                label: const Text('C'),
                selectedColor: Colors.red.shade100,
                selected: _supplierAbcFilter == 'C',
                onSelected: (_) => setState(() => _supplierAbcFilter = 'C'),
              ),
              FilterChip(
                label: const Text('Bez procjene'),
                selected: _supplierAbcFilter == 'unrated',
                onSelected: (_) =>
                    setState(() => _supplierAbcFilter = 'unrated'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _supplierActivityFilter,
            decoration: const InputDecoration(
              labelText: 'Djelatnost',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sve djelatnosti'),
              ),
              ...resolveVisibleActivitySectors(
                _companyDataForPartners['enabledActivitySectorCodes'],
              ).map(
                (e) => DropdownMenuItem<String?>(
                  value: e.code,
                  child: Text(
                    e.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _supplierActivityFilter = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    if (_customers.isEmpty && !_loading && _error == null) {
      return _empty('Nema kupaca.');
    }
    final visible = _visibleCustomers;
    if (_customers.isNotEmpty &&
        visible.isEmpty &&
        !_loading &&
        _error == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _customerFilterBar(),
          Expanded(child: _empty('Nema rezultata za odabrane filtere.')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _customerFilterBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final c = visible[i];
              final accent = _partnerAccent(c.partnerRatingClass, c.isStrategic);
              final sectorRaw = (c.activitySector ?? '').trim();
              final sectorLine = sectorRaw.isEmpty
                  ? ''
                  : 'Djelatnost: ${activitySectorLabel(c.activitySector)}\n';
              final stratLine =
                  c.partnerRatingClass == 'C' && c.isStrategic
                      ? ' • Strateški (nema alternative)'
                      : '';
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: accent, width: 5),
                    ),
                  ),
                  child: ListTile(
                    title: Text('${c.code} — ${c.name}', maxLines: 3),
                    subtitle: Text(
                      'Pravni naziv: ${c.legalName}\n'
                      'Kategorija: ${_abcSubtitle(c.partnerRatingClass)}$stratLine\n'
                      '$sectorLine'
                      'Status: ${c.status} • Tip: ${c.customerType}',
                      maxLines: 6,
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit' && _canManageCustomers) {
                          _openEditCustomer(c);
                        }
                        if (v == 'unified') {
                          _openCustomerUnifiedAssessment(c);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: _canManageCustomers,
                          child: const Text('Uredi'),
                        ),
                        const PopupMenuItem(
                          value: 'unified',
                          child: Text('Procjena (šablon)'),
                        ),
                      ],
                    ),
                    onTap: _canManageCustomers
                        ? () => _openEditCustomer(c)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab() {
    if (_suppliers.isEmpty && !_loading && _error == null) {
      return _empty('Nema dobavljača.');
    }
    final visible = _visibleSuppliers;
    if (_suppliers.isNotEmpty &&
        visible.isEmpty &&
        !_loading &&
        _error == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _supplierFilterBar(),
          Expanded(child: _empty('Nema rezultata za odabrane filtere.')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _supplierFilterBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final s = visible[i];
              final oa = s.operationalAuto;
              final autoLine = oa == null
                  ? 'Automatski skor (narudžbe): —'
                  : 'Automatski skor (narudžbe): ${oa.score.toStringAsFixed(0)} '
                        '(${oa.linesAnalyzed} stavki, v${oa.algorithmVersion})';
              final accent = _partnerAccent(
                s.partnerRatingClass,
                s.isStrategic,
              );
              final sectorRaw = (s.activitySector ?? '').trim();
              final sectorLine = sectorRaw.isEmpty
                  ? ''
                  : 'Djelatnost: ${activitySectorLabel(s.activitySector)}\n';
              final stratLine =
                  s.partnerRatingClass == 'C' && s.isStrategic
                      ? ' • Strateški (nema alternative)'
                      : '';
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: accent, width: 5),
                    ),
                  ),
                  child: ListTile(
                    title: Text('${s.code} — ${s.name}', maxLines: 3),
                    subtitle: Text(
                      'Pravni naziv: ${s.legalName}\n'
                      'Kategorija: ${_abcSubtitle(s.partnerRatingClass)}$stratLine\n'
                      '$sectorLine'
                      'Status: ${s.status} • Tip: ${s.supplierType}\n'
                      'Rizik: ${s.riskLevel} • Ocjena procjene: '
                      '${s.overallScore.toStringAsFixed(1)}\n'
                      '$autoLine',
                      maxLines: 8,
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
                        if (v == 'unified') {
                          _openSupplierUnifiedAssessment(s);
                        }
                        if (v == 'operational_detail') {
                          _showSupplierOperationalDetails(s);
                        }
                        if (v == 'operational' &&
                            _canRefreshSupplierOperational) {
                          _refreshSupplierOperational(s);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: _canManageSuppliers,
                          child: const Text('Izmijeni'),
                        ),
                        const PopupMenuItem(
                          value: 'eval',
                          child: Text('Procjene'),
                        ),
                        const PopupMenuItem(
                          value: 'unified',
                          child: Text('Procjena (šablon)'),
                        ),
                        if (oa != null)
                          const PopupMenuItem(
                            value: 'operational_detail',
                            child: Text('Detalji automatskog skora'),
                          ),
                        if (_canRefreshSupplierOperational)
                          PopupMenuItem(
                            value: 'operational',
                            enabled: !_opRefreshing,
                            child: const Text(
                              'Osvježi automatski skor (narudžbe)',
                            ),
                          ),
                      ],
                    ),
                    onTap: _canManageSuppliers
                        ? () => _openEditSupplier(s)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKpis() {
    final customersActive = _customers
        .where((e) => e.status == 'active')
        .length;
    final suppliersActive = _suppliers
        .where((e) => e.status == 'active')
        .length;
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
    final createLabel = _tabController.index == 0
        ? 'Novi kupac'
        : 'Novi dobavljač';
    final createAction = _tabController.index == 0
        ? _openCreateCustomer
        : _openCreateSupplier;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Kupci i dobavljači'),
        actions: [
          if (_canManageActivitySectors)
            IconButton(
              tooltip: 'Koje djelatnosti prikazivati (filter i partner)',
              onPressed: _openActivitySectorSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
          IconButton(
            tooltip: 'Šifarnik djelatnosti (NACE / grane)',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ActivitySectorsCatalogScreen(),
                ),
              );
            },
            icon: const Icon(Icons.menu_book_outlined),
          ),
          if (_tabController.index == 1 && _canRefreshSupplierOperational)
            IconButton(
              tooltip: 'Osvježi automatski skor (svi, max 40)',
              onPressed: (_loading || _opRefreshing)
                  ? null
                  : _confirmRefreshAllSuppliersOperational,
              icon: const Icon(Icons.auto_graph_outlined),
            ),
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
            onPressed: (_loading || _opRefreshing) ? null : _load,
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
          if (_loading || _opRefreshing)
            const LinearProgressIndicator(minHeight: 2),
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
                _buildCustomersTab(),
                _buildSuppliersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
