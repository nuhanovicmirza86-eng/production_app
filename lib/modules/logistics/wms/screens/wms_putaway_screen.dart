import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';
import '../wms_lot_label_helper.dart';
import '../wms_scan_helpers.dart';

class WmsPutawayScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  final String? initialLotDocId;

  const WmsPutawayScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
    this.initialLotDocId,
  });

  @override
  State<WmsPutawayScreen> createState() => _WmsPutawayScreenState();
}

class _WmsPutawayScreenState extends State<WmsPutawayScreen> {
  final _svc = WarehouseWmsService();
  final _lotCaption = TextEditingController();
  final _aisle = TextEditingController();
  final _shelf = TextEditingController();
  final _bin = TextEditingController();
  final _container = TextEditingController();
  bool _toPicking = false;
  bool _busy = false;

  String _lotDocInternal = '';

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    final init = widget.initialLotDocId?.trim();
    if (init != null && init.isNotEmpty) {
      _bindLotDoc(init);
    }
  }

  @override
  void dispose() {
    _lotCaption.dispose();
    _aisle.dispose();
    _shelf.dispose();
    _bin.dispose();
    _container.dispose();
    super.dispose();
  }

  Future<void> _bindLotDoc(String docId) async {
    final id = docId.trim();
    if (id.isEmpty) return;
    _lotDocInternal = id;
    if (!mounted) return;
    setState(() => _lotCaption.text = '…');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('inventory_lots')
          .doc(id)
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        setState(() => _lotCaption.text = 'Lot');
        return;
      }
      final d = snap.data() ?? {};
      final docCid = (d['companyId'] ?? '').toString().trim();
      if (docCid.isNotEmpty && docCid != _cid) {
        setState(() {
          _lotDocInternal = '';
          _lotCaption.text = '';
        });
        _snack('Lot nije u ovoj kompaniji.');
        return;
      }
      setState(() => _lotCaption.text = wmsLotCaptionFromDocData(d));
    } catch (_) {
      if (mounted) setState(() => _lotCaption.text = 'Lot');
    }
  }

  Future<void> _submit() async {
    final id = _lotDocInternal.trim();
    if (id.isEmpty) {
      _snack('Skeniraj lot.');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _lotCaption,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Lot',
                      hintText: 'Skeniraj',
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
                          await _bindLotDoc(id);
                        },
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aisle,
              decoration: const InputDecoration(labelText: 'Prolaz'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shelf,
              decoration: const InputDecoration(labelText: 'Polica / regal'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bin,
              decoration: const InputDecoration(labelText: 'Lokacija / bin'),
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
              title: const Text('Premjesti u zonu pripreme'),
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
