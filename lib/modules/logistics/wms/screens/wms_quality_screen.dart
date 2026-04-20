import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../warehouse_hub/services/warehouse_hub_service.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';

class WmsQualityScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  const WmsQualityScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  @override
  State<WmsQualityScreen> createState() => _WmsQualityScreenState();
}

class _WmsQualityScreenState extends State<WmsQualityScreen> {
  final _hub = WarehouseHubService();
  final _svc = WarehouseWmsService();
  final _note = TextEditingController();

  String? _warehouseId;
  List<({String id, String label})> _warehouses = const [];
  bool _loadingWh = true;
  bool _busy = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWh = true);
    try {
      final rows = await _hub.listWarehouses(companyId: _cid);
      setState(() {
        _warehouses = rows.map((r) => (id: r.id, label: r.name)).toList();
        if (_warehouseId == null && _warehouses.isNotEmpty) {
          _warehouseId = _warehouses.first.id;
        }
      });
    } catch (_) {
      setState(() => _warehouses = const []);
    } finally {
      if (mounted) setState(() => _loadingWh = false);
    }
  }

  Future<void> _decide(String lotDocId, String decision) async {
    setState(() => _busy = true);
    try {
      await _svc.resolveLotQuality(
        companyId: _cid,
        lotDocId: lotDocId,
        decision: decision,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Spremljeno: $decision')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wid = _warehouseId;
    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Kvaliteta (karantin)',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadingWh)
                  const LinearProgressIndicator()
                else if (_warehouses.isEmpty)
                  const Text('Nema magacina.')
                else
                  DropdownButtonFormField<String>(
                    value: wid,
                    decoration: const InputDecoration(labelText: 'Magacin'),
                    items: _warehouses
                        .map(
                          (w) => DropdownMenuItem<String>(
                            value: w.id,
                            child: Text(
                              w.label.isNotEmpty
                                  ? '${w.label} (${w.id})'
                                  : w.id,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Napomena uz odluku (opcionalno)',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: wid == null || wid.isEmpty
                ? const Center(child: Text('Odaberi magacin.'))
                : AbsorbPointer(
                    absorbing: _busy,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('inventory_lots')
                          .where('companyId', isEqualTo: _cid)
                          .where('warehouseId', isEqualTo: wid)
                          .where('status', isEqualTo: 'quarantine')
                          .limit(100)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text('Greška: ${snap.error}'),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('Nema lotova u karantinu.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final d = docs[i].data();
                            final id = docs[i].id;
                            final lot = (d['lotId'] ?? id).toString();
                            final qty = (d['availableQty'] ?? d['quantity'] ?? 0)
                                .toString();
                            final item = (d['itemId'] ?? '').toString();
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text('Lot $lot · $qty'),
                                subtitle: Text(
                                  'Artikl: $item\nDoc: $id',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          _decide(id, 'approved'),
                                      child: const Text('Odobri'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _decide(id, 'hold'),
                                      child: const Text('Hold'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _decide(id, 'blocked'),
                                      child: const Text('Blokiraj'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
