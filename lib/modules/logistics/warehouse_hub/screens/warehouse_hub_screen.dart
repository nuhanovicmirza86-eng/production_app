import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/theme/operonix_production_brand.dart';
import '../../wms/screens/warehouse_wms_dashboard_screen.dart';
import '../models/warehouse_hub_row.dart';
import '../services/warehouse_hub_service.dart';

/// Master katalog magacina: stabilni **MAG_***, hub vs satelit, opseg po pogonu,
/// operativni WMS tok odvojen (poveznica na [WarehouseWmsDashboardScreen]).
class WarehouseHubScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// Kada je true (tab u [LogisticsHubEntryScreen]), bez vlastitog AppBar-a i bez kartice „Otvori WMS”.
  final bool embedInHubShell;

  const WarehouseHubScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  @override
  State<WarehouseHubScreen> createState() => _WarehouseHubScreenState();
}

class _WarehouseHubScreenState extends State<WarehouseHubScreen> {
  final _service = WarehouseHubService();

  bool _loading = true;
  String? _error;
  List<WarehouseHubRow> _rows = const [];
  List<({String plantKey, String label})> _plants = const [];

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  bool get _hasLogistics {
    final raw = widget.companyData['enabledModules'];
    if (raw is! List || raw.isEmpty) return false;
    return raw.map((e) => e.toString().trim().toLowerCase()).contains(
      'logistics',
    );
  }

  bool get _canManageHub {
    final r = _role;
    return r == ProductionAccessHelper.roleSuperAdmin ||
        ProductionAccessHelper.isAdminRole(r) ||
        r == ProductionAccessHelper.roleLogisticsManager;
  }

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(initial: true));
  }

  Future<void> _load({bool initial = false}) async {
    if (_companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje companyId.';
      });
      return;
    }

    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rows = await _service.listWarehouses(companyId: _companyId);
      final plants = await _service.listPlantOptions(companyId: _companyId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _plants = plants;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.toMessage(e);
      });
    }
  }

  void _openWms() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            WarehouseWmsDashboardScreen(companyData: widget.companyData),
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final nameCtrl = TextEditingController();
    String type = 'finished_goods_store';
    String plantKey = '';
    var isHub = false;
    var canReceive = true;
    var canShip = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Novi magacin'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Naziv za prikaz',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tip',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: type,
                    items: _typeDropdownItems(),
                    onChanged: (v) =>
                        setLocal(() => type = v ?? 'finished_goods_store'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pogon',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: plantKey.isEmpty ? '' : plantKey,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Dijeljeno (svi pogon)'),
                      ),
                      ..._plants.map(
                        (p) => DropdownMenuItem<String>(
                          value: p.plantKey,
                          child: Text('${p.label} (${p.plantKey})'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => plantKey = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isHub,
                    onChanged: (v) =>
                        setLocal(() => isHub = v ?? false),
                    title: const Text('Centralni hub za ovaj opseg'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: canReceive,
                    onChanged: (v) =>
                        setLocal(() => canReceive = v ?? true),
                    title: const Text('Može primiti (ulaz)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: canShip,
                    onChanged: (v) => setLocal(() => canShip = v ?? true),
                    title: const Text('Može izdati (izlaz)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Sačuvaj'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    try {
      await _service.createWarehouse(
        companyId: _companyId,
        displayName: name,
        type: type,
        plantKey: plantKey,
        isHub: isHub,
        canReceive: canReceive,
        canShip: canShip,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magacin je kreiran.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditDialog(WarehouseHubRow row) async {
    final nameCtrl = TextEditingController(text: row.name);
    final orderCtrl = TextEditingController(
      text: '${row.displayOrder > 0 ? row.displayOrder : 10}',
    );
    String type = row.type;
    String plantKey = row.plantKey ?? '';
    var isHub = row.isHub;
    var canReceive = row.canReceive;
    var canShip = row.canShip;
    var isActive = row.isActive;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Uredi magacin'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sistemski kod ${row.code} ostaje nepromijenjen (stabilan MAG_*).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Naziv za prikaz',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tip',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: type,
                    items: _typeDropdownItems(),
                    onChanged: (v) =>
                        setLocal(() => type = v ?? 'finished_goods_store'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pogon',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: plantKey.isEmpty ? '' : plantKey,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Dijeljeno (svi pogon)'),
                      ),
                      ..._plants.map(
                        (p) => DropdownMenuItem<String>(
                          value: p.plantKey,
                          child: Text('${p.label} (${p.plantKey})'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => plantKey = v ?? ''),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isHub,
                    onChanged: (v) =>
                        setLocal(() => isHub = v ?? false),
                    title: const Text('Centralni hub za ovaj opseg'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: canReceive,
                    onChanged: (v) =>
                        setLocal(() => canReceive = v ?? true),
                    title: const Text('Može primiti (ulaz)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: canShip,
                    onChanged: (v) =>
                        setLocal(() => canShip = v ?? true),
                    title: const Text('Može izdati (izlaz)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: isActive,
                    onChanged: (v) =>
                        setLocal(() => isActive = v ?? true),
                    title: const Text('Aktivan u katalogu'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Redoslijed (displayOrder)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Sačuvaj'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      orderCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final parsedOrder = int.tryParse(orderCtrl.text.trim());
    nameCtrl.dispose();
    orderCtrl.dispose();
    if (name.isEmpty) return;

    final displayOrder = (parsedOrder != null && parsedOrder > 0)
        ? parsedOrder
        : (row.displayOrder > 0 ? row.displayOrder : 10);

    setState(() => _saving = true);

    try {
      await _service.updateWarehouse(
        companyId: _companyId,
        warehouseId: row.id,
        displayName: name,
        type: type,
        plantKey: plantKey,
        isHub: isHub,
        canReceive: canReceive,
        canShip: canShip,
        isActive: isActive,
        displayOrder: displayOrder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magacin je ažuriran.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static List<DropdownMenuItem<String>> _typeDropdownItems() {
    return const [
      DropdownMenuItem(
        value: 'raw_material_store',
        child: Text('Sirovine'),
      ),
      DropdownMenuItem(
        value: 'semi_finished_store',
        child: Text('Poluproizvodi'),
      ),
      DropdownMenuItem(
        value: 'finished_goods_store',
        child: Text('Gotovi proizvodi'),
      ),
      DropdownMenuItem(
        value: 'maintenance_store',
        child: Text('Održavanje'),
      ),
      DropdownMenuItem(
        value: 'rework_store',
        child: Text('Prerada'),
      ),
      DropdownMenuItem(
        value: 'scrap_store',
        child: Text('Otpad'),
      ),
      DropdownMenuItem(
        value: 'quarantine_store',
        child: Text('Karantin'),
      ),
      DropdownMenuItem(
        value: 'other',
        child: Text('Ostalo'),
      ),
    ];
  }

  static String _typeLabel(String type) {
    const m = {
      'raw_material_store': 'Sirovine',
      'semi_finished_store': 'Poluproizvodi',
      'finished_goods_store': 'Gotovi proizvodi',
      'maintenance_store': 'Održavanje',
      'rework_store': 'Prerada',
      'scrap_store': 'Otpad',
      'quarantine_store': 'Karantin',
      'other': 'Ostalo',
    };
    return m[type] ?? type;
  }

  /// Grupiranje: prvo „dijeljeno” (prazan plantKey), zatim ostali pogoni abecedno.
  Map<String, List<WarehouseHubRow>> _groupByPlant(List<WarehouseHubRow> rows) {
    final m = <String, List<WarehouseHubRow>>{};
    for (final r in rows) {
      final k = (r.plantKey ?? '').trim();
      m.putIfAbsent(k, () => []).add(r);
    }
    for (final list in m.values) {
      list.sort((a, b) {
        if (a.isHub != b.isHub) return a.isHub ? -1 : 1;
        final o = a.displayOrder.compareTo(b.displayOrder);
        if (o != 0) return o;
        return a.code.toLowerCase().compareTo(b.code.toLowerCase());
      });
    }
    return m;
  }

  List<String> _sortedPlantKeys(Map<String, List<WarehouseHubRow>> m) {
    final keys = m.keys.toList();
    keys.sort((a, b) {
      if (a.isEmpty) return -1;
      if (b.isEmpty) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return keys;
  }

  String _sectionLabel(String plantKey) {
    if (plantKey.isEmpty) {
      return 'Dijeljeno za cijelu kompaniju';
    }
    for (final p in _plants) {
      if (p.plantKey == plantKey) {
        return '${p.label} · $plantKey';
      }
    }
    return plantKey;
  }

  int _groupedChildCount(
    List<String> plantKeys,
    Map<String, List<WarehouseHubRow>> grouped,
  ) {
    var c = 0;
    for (final pk in plantKeys) {
      c += 1 + (grouped[pk]?.length ?? 0);
    }
    return c;
  }

  Widget _buildGroupedItem({
    required int index,
    required List<String> plantKeys,
    required Map<String, List<WarehouseHubRow>> grouped,
    required ThemeData theme,
  }) {
    var i = index;
    for (final pk in plantKeys) {
      final list = grouped[pk]!;
      if (i == 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              Icon(
                pk.isEmpty ? Icons.apartment_outlined : Icons.factory_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sectionLabel(pk),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${list.length} mag.',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      }
      i--;
      if (i < list.length) {
        final r = list[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _WarehouseCard(
            r: r,
            theme: theme,
            typeLabel: _typeLabel(r.type),
            canEdit: _canManageHub,
            onTapEdit: () => _openEditDialog(r),
          ),
        );
      }
      i -= list.length;
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_hasLogistics) {
      final body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Modul logistike nije uključen za ovu kompaniju.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
      if (widget.embedInHubShell) {
        return Scaffold(primary: false, body: body);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Magacin / Hub — master podaci')),
        body: body,
      );
    }

    final hubs = _rows.where((r) => r.isHub).length;
    final active = _rows.where((r) => r.isActive).length;
    final grouped = _groupByPlant(_rows);
    final plantKeys = _sortedPlantKeys(grouped);

    final stackBody = Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _ConceptCard(theme: theme),
                  ),
                ),
                if (!widget.embedInHubShell)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _WmsBridgeCard(
                        theme: theme,
                        onOpenWms: _openWms,
                      ),
                    ),
                  ),
                if (!_loading && _error == null && _rows.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                            label: Text('Ukupno: ${_rows.length}'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.hub_outlined, size: 18),
                            label: Text('Hubova: $hubs'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text('Aktivnih: $active'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_loading && _rows.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && _rows.isEmpty)
                  SliverFillRemaining(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          _error!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_rows.isEmpty)
                  SliverFillRemaining(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Još nema magacina.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Korak 1: u master podacima definiši pogone (company_plants) ako '
                          'želiš opseg po pogonu. Korak 2: dodaj centralni hub za taj opseg '
                          '(ili jedan dijeljeni hub). Korak 3: dodaj ostale magacine '
                          '(satelite). Korak 4: za prijem i kretanje zalihe otvori WMS.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      widget.embedInHubShell ? 24 : 88,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildGroupedItem(
                            index: index,
                            plantKeys: plantKeys,
                            grouped: grouped,
                            theme: theme,
                          );
                        },
                        childCount: _groupedChildCount(plantKeys, grouped),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_loading && _rows.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      );

    if (widget.embedInHubShell) {
      return Scaffold(
        primary: false,
        floatingActionButton: _canManageHub
            ? FloatingActionButton.extended(
                onPressed: (_loading || _saving) ? null : _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Novi magacin'),
              )
            : null,
        body: stackBody,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Magacin / Hub — master podaci'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: (_loading || _saving) ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Kreiranje i izmjene idu kroz Callable (atomski MAG_*); zapis u '
            'company_audit_logs — IATF-friendly. Brisanje dokumenata nije predviđeno.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ),
      floatingActionButton: _canManageHub
          ? FloatingActionButton.extended(
              onPressed: (_loading || _saving) ? null : _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Novi magacin'),
            )
          : null,
      body: stackBody,
    );
  }
}

/// Šta je model (iz LOGISTICS_SCHEMA — master vs operativa).
class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: operonixProductionCardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Model: stabilan kod + prikazni naziv + uloga u toku',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '• Svaki magacin dobija trajni sistemski identifikator MAG_* (nikad se ne '
              'mijenja niti reciklira).\n'
              '• Polje „naziv“ je slobodan prikaz po kompaniji.\n'
              '• Označite točno jedan centralni hub po logičkom opsegu: dijeljeno za cijelu '
              'kompaniju ili za jedan pogon. Ostali zapisi su satelitski magacini.\n'
              '• Ulaz/izlaz (primiti / izdati) definiraju u kojim smjerovima smije učestvovati '
              'u WMS i knjiženjima.\n'
              '• Ovaj ekran je korak 1 (master šifarnik). Prijem, karantin, putaway i FIFO '
              'su korak 2 — WMS na ulazu „Centralni magacin / Hub“.',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WmsBridgeCard extends StatelessWidget {
  const _WmsBridgeCard({
    required this.theme,
    required this.onOpenWms,
  });

  final ThemeData theme;
  final VoidCallback onOpenWms;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Operativni rad sa zalihama',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'To je korak 2 u istom toku (WMS). Prijem u karantin, kvaliteta, putaway, '
              'FIFO i otpremna zona — otvaraju se ovdje ili s ulaznog ekrana „Centralni magacin / Hub“.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onOpenWms,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Otvori WMS — centralni magacin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({
    required this.r,
    required this.theme,
    required this.typeLabel,
    required this.canEdit,
    required this.onTapEdit,
  });

  final WarehouseHubRow r;
  final ThemeData theme;
  final String typeLabel;
  final bool canEdit;
  final VoidCallback onTapEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: operonixProductionCardShape(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit ? onTapEdit : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r.isHub ? Icons.hub_outlined : Icons.warehouse_outlined,
                    color: kOperonixProductionBrandGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (r.isHub)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Chip(
                        label: const Text('HUB'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _tinyChip(theme, Icons.tag, r.code),
                  _tinyChip(
                    theme,
                    r.canReceive ? Icons.south_west : Icons.do_not_disturb_on_outlined,
                    r.canReceive ? 'Ulaz' : 'Bez ulaza',
                  ),
                  _tinyChip(
                    theme,
                    r.canShip ? Icons.north_east : Icons.do_not_disturb_on_outlined,
                    r.canShip ? 'Izlaz' : 'Bez izlaza',
                  ),
                  _tinyChip(
                    theme,
                    Icons.sort,
                    'Red. ${r.displayOrder}',
                  ),
                  _tinyChip(
                    theme,
                    r.isActive ? Icons.check_circle_outline : Icons.pause_circle_outlined,
                    r.isActive ? 'Aktivan' : 'Neaktivan',
                  ),
                ],
              ),
              if (canEdit)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onTapEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Uredi'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyChip(ThemeData theme, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
