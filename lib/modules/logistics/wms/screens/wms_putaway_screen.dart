import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';
import '../wms_scan_helpers.dart';

class WmsPutawayScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  const WmsPutawayScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  @override
  State<WmsPutawayScreen> createState() => _WmsPutawayScreenState();
}

class _WmsPutawayScreenState extends State<WmsPutawayScreen> {
  final _svc = WarehouseWmsService();
  final _lotDocId = TextEditingController();
  final _aisle = TextEditingController();
  final _shelf = TextEditingController();
  final _bin = TextEditingController();
  final _container = TextEditingController();
  bool _toPicking = false;
  bool _busy = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void dispose() {
    _lotDocId.dispose();
    _aisle.dispose();
    _shelf.dispose();
    _bin.dispose();
    _container.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _lotDocId.text.trim();
    if (id.isEmpty) {
      _snack('Unesi lotDocId (Firestore ID dokumenta).');
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.putawayLot(
        companyId: _cid,
        lotDocId: id,
        storageAisle: _aisle.text.trim(),
        storageShelf: _shelf.text.trim(),
        storageBin: _bin.text.trim(),
        containerLabel: _container.text.trim(),
        moveToPickingStaging: _toPicking,
      );
      if (!mounted) return;
      _snack('Putaway spremljen.');
    } catch (e) {
      if (!mounted) return;
      _snack(AppErrorMapper.toMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Putaway',
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Lot mora biti u statusu „available” (nakon odobrenja kvalitete). '
              'Označite prijelaz u zonu pripreme za komisioniranje ako je potrebno.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _lotDocId,
                    decoration: const InputDecoration(
                      labelText: 'lotDocId',
                      hintText: 'ID u inventory_lots ili wmslot:v1;…',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Skeniraj lot',
                  onPressed: _busy
                      ? null
                      : () async {
                          final id = await wmsScanLotDocId(
                            context,
                            companyData: widget.companyData,
                          );
                          if (!mounted || id == null || id.isEmpty) return;
                          setState(() => _lotDocId.text = id);
                        },
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aisle,
              decoration: const InputDecoration(labelText: 'Prolaz (aisle)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shelf,
              decoration: const InputDecoration(labelText: 'Polica / regal'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bin,
              decoration: const InputDecoration(labelText: 'Bin / lokacija'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _container,
              decoration: const InputDecoration(
                labelText: 'Kontejner / kutija (opcionalno)',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _toPicking,
              onChanged: (v) => setState(() => _toPicking = v ?? false),
              title: const Text('Premjesti u PICKING_STAGING'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Spremi putaway'),
            ),
          ],
        ),
      ),
    );
  }
}
