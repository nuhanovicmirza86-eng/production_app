import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';
import '../wms_lot_label_helper.dart';
import '../wms_scan_helpers.dart';

class WmsShippingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  final String? initialLotDocId;

  const WmsShippingScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
    this.initialLotDocId,
  });

  @override
  State<WmsShippingScreen> createState() => _WmsShippingScreenState();
}

class _WmsShippingScreenState extends State<WmsShippingScreen> {
  final _svc = WarehouseWmsService();
  final _lotCaption = TextEditingController();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lot nije u ovoj kompaniji.')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skeniraj lot.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.moveLotToShippingZone(companyId: _cid, lotDocId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lot je u otpremnoj zoni.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return wmsTabScaffold(
      embedInHubShell: widget.embedInHubShell,
      title: 'Otpremna zona',
      body: AbsorbPointer(
        absorbing: _busy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Potvrdi prijelaz u otpremu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
