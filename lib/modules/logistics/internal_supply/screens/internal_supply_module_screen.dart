import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../warehouse_hub/services/warehouse_hub_service.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/internal_supply_service.dart';
import 'internal_supply_order_detail_screen.dart';

/// Interne narudžbe hub → pogon: red huba, zaprimanje, nova narudžba.
class InternalSupplyModuleScreen extends StatefulWidget {
  const InternalSupplyModuleScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  final Map<String, dynamic> companyData;
  final bool embedInHubShell;

  @override
  State<InternalSupplyModuleScreen> createState() =>
      _InternalSupplyModuleScreenState();
}

class _InternalSupplyModuleScreenState extends State<InternalSupplyModuleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _wh = WarehouseHubService();
  List<({String id, String label, bool isHub})> _warehouses = const [];
  bool _loadingWh = true;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  bool get _hasLogistics {
    final raw = widget.companyData['enabledModules'];
    if (raw is! List || raw.isEmpty) return false;
    return raw.map((e) => e.toString().trim().toLowerCase()).contains(
      'logistics',
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWarehouses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    if (_cid.isEmpty) return;
    try {
      final rows = await _wh.listWarehouses(companyId: _cid);
      final list = rows
          .map(
            (w) => (
              id: w.id,
              label: '${w.name} (${w.code})',
              isHub: w.isHub,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _warehouses = list;
        _loadingWh = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWh = false);
    }
  }

  void _openDetail(String orderId, {required bool hubMode}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => InternalSupplyOrderDetailScreen(
          companyData: widget.companyData,
          orderId: orderId,
          hubMode: hubMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLogistics || _cid.isEmpty) {
      return wmsTabScaffold(
        embedInHubShell: widget.embedInHubShell,
        title: 'Interne narudžbe',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _cid.isEmpty
                  ? 'Nedostaje companyId.'
                  : 'Modul logistike nije uključen.',
            ),
          ),
        ),
      );
    }

    if (_loadingWh) {
      return wmsTabScaffold(
        embedInHubShell: widget.embedInHubShell,
        title: 'Interne narudžbe',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hubs = _warehouses.where((w) => w.isHub).toList();
    final dests = _warehouses.where((w) => !w.isHub).toList();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Red huba'),
            Tab(text: 'Odredište'),
            Tab(text: 'Nova'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _HubQueueTab(
                companyId: _cid,
                hubs: hubs,
                onOpen: (id) => _openDetail(id, hubMode: true),
              ),
              _DestInboxTab(
                companyId: _cid,
                dests: dests,
                onOpen: (id) => _openDetail(id, hubMode: false),
              ),
              _CreateOrderTab(
                companyId: _cid,
                hubs: hubs,
                dests: dests,
                onSubmitted: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      ],
    );

    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Interne narudžbe',
      body: body,
    );
  }
}

class _HubQueueTab extends StatefulWidget {
  const _HubQueueTab({
    required this.companyId,
    required this.hubs,
    required this.onOpen,
  });

  final String companyId;
  final List<({String id, String label, bool isHub})> hubs;
  final void Function(String orderId) onOpen;

  @override
  State<_HubQueueTab> createState() => _HubQueueTabState();
}

class _HubQueueTabState extends State<_HubQueueTab> {
  String? _hubId;

  static const _hubStatuses = {
    'submitted',
    'hub_picking',
    'hub_ready_to_ship',
  };

  @override
  void initState() {
    super.initState();
    if (widget.hubs.isNotEmpty) {
      _hubId = widget.hubs.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hubs.isEmpty) {
      return const Center(
        child: Text('Nema magacina označenih kao hub (isHub).'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DropdownButtonFormField<String>(
            initialValue: _hubId,
            decoration: const InputDecoration(
              labelText: 'Hub magacin',
              border: OutlineInputBorder(),
            ),
            items: widget.hubs
                .map(
                  (h) => DropdownMenuItem(value: h.id, child: Text(h.label)),
                )
                .toList(),
            onChanged: (v) => setState(() => _hubId = v),
          ),
        ),
        Expanded(
          child: _hubId == null
              ? const SizedBox.shrink()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('internal_supply_orders')
                      .where('companyId', isEqualTo: widget.companyId)
                      .where('supplyingWarehouseId', isEqualTo: _hubId)
                      .orderBy('createdAt', descending: true)
                      .limit(80)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(AppErrorMapper.toMessage(snap.error!)),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs.where((d) {
                      final s = (d.data()['status'] ?? '').toString();
                      return _hubStatuses.contains(s);
                    }).toList();
                    if (docs.isEmpty) {
                      return const Center(child: Text('Nema narudžbi u redu.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        final code =
                            (d['requestCode'] ?? docs[i].id).toString();
                        final st = (d['status'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            title: Text(code),
                            subtitle: Text(st),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onOpen(docs[i].id),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DestInboxTab extends StatefulWidget {
  const _DestInboxTab({
    required this.companyId,
    required this.dests,
    required this.onOpen,
  });

  final String companyId;
  final List<({String id, String label, bool isHub})> dests;
  final void Function(String orderId) onOpen;

  @override
  State<_DestInboxTab> createState() => _DestInboxTabState();
}

class _DestInboxTabState extends State<_DestInboxTab> {
  String? _destId;

  static const _destStatuses = {'awaiting_receipt', 'in_transit'};

  @override
  void initState() {
    super.initState();
    if (widget.dests.isNotEmpty) {
      _destId = widget.dests.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dests.isEmpty) {
      return const Center(
        child: Text('Nema magacina pogona (nije hub). Dodaj u masteru.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DropdownButtonFormField<String>(
            initialValue: _destId,
            decoration: const InputDecoration(
              labelText: 'Odredišni magacin',
              border: OutlineInputBorder(),
            ),
            items: widget.dests
                .map(
                  (h) => DropdownMenuItem(value: h.id, child: Text(h.label)),
                )
                .toList(),
            onChanged: (v) => setState(() => _destId = v),
          ),
        ),
        Expanded(
          child: _destId == null
              ? const SizedBox.shrink()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('internal_supply_orders')
                      .where('companyId', isEqualTo: widget.companyId)
                      .where('requestingWarehouseId', isEqualTo: _destId)
                      .orderBy('createdAt', descending: true)
                      .limit(80)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(AppErrorMapper.toMessage(snap.error!)),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs.where((d) {
                      final s = (d.data()['status'] ?? '').toString();
                      return _destStatuses.contains(s);
                    }).toList();
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Nema narudžbi za zaprimanje.'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        final code =
                            (d['requestCode'] ?? docs[i].id).toString();
                        final st = (d['status'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            title: Text(code),
                            subtitle: Text(st),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onOpen(docs[i].id),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LineRow {
  _LineRow() : itemId = TextEditingController(), qty = TextEditingController();
  final TextEditingController itemId;
  final TextEditingController qty;
  void dispose() {
    itemId.dispose();
    qty.dispose();
  }
}

class _CreateOrderTab extends StatefulWidget {
  const _CreateOrderTab({
    required this.companyId,
    required this.hubs,
    required this.dests,
    required this.onSubmitted,
  });

  final String companyId;
  final List<({String id, String label, bool isHub})> hubs;
  final List<({String id, String label, bool isHub})> dests;
  final VoidCallback onSubmitted;

  @override
  State<_CreateOrderTab> createState() => _CreateOrderTabState();
}

class _CreateOrderTabState extends State<_CreateOrderTab> {
  final _svc = InternalSupplyService();
  final _notes = TextEditingController();
  final _lines = <_LineRow>[_LineRow()];
  String? _hubId;
  String? _destId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.hubs.isNotEmpty) {
      _hubId = widget.hubs.first.id;
    }
    if (widget.dests.isNotEmpty) {
      _destId = widget.dests.first.id;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_hubId == null || _destId == null) return;
    setState(() => _saving = true);
    try {
      final lines = <Map<String, dynamic>>[];
      for (final l in _lines) {
        final id = l.itemId.text.trim();
        final q = double.tryParse(l.qty.text.trim().replaceAll(',', '.'));
        if (id.isEmpty || q == null || q <= 0) continue;
        lines.add({'itemId': id, 'quantity': q});
      }
      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dodaj barem jednu valjanu stavku.')),
          );
        }
        return;
      }
      await _svc.submitInternalSupplyOrder(
        companyId: widget.companyId,
        supplyingWarehouseId: _hubId!,
        requestingWarehouseId: _destId!,
        notes: _notes.text,
        lines: lines,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Narudžba je poslana hubu.')),
        );
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hubs.isEmpty || widget.dests.isEmpty) {
      return const Center(
        child: Text('Potreban je barem jedan hub i jedan magacin pogona.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _hubId,
          decoration: const InputDecoration(
            labelText: 'Hub (izvoz)',
            border: OutlineInputBorder(),
          ),
          items: widget.hubs
              .map(
                (h) => DropdownMenuItem(value: h.id, child: Text(h.label)),
              )
              .toList(),
          onChanged: (v) => setState(() => _hubId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _destId,
          decoration: const InputDecoration(
            labelText: 'Magacin pogona (odredište)',
            border: OutlineInputBorder(),
          ),
          items: widget.dests
              .map(
                (h) => DropdownMenuItem(value: h.id, child: Text(h.label)),
              )
              .toList(),
          onChanged: (v) => setState(() => _destId = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Napomena',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Stavke (ID proizvoda iz kataloga)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ..._lines.asMap().entries.map((e) {
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: row.itemId,
                    decoration: const InputDecoration(
                      labelText: 'productId',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Kol.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _lines.add(_LineRow())),
          icon: const Icon(Icons.add),
          label: const Text('Stavka'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Šaljem…' : 'Pošalji hubu'),
        ),
      ],
    );
  }
}
