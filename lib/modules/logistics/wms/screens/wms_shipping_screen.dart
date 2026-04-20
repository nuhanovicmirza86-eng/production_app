import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../widgets/wms_tab_scaffold.dart';
import '../services/warehouse_wms_service.dart';
import '../wms_scan_helpers.dart';

class WmsShippingScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  const WmsShippingScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  @override
  State<WmsShippingScreen> createState() => _WmsShippingScreenState();
}

class _WmsShippingScreenState extends State<WmsShippingScreen> {
  final _svc = WarehouseWmsService();
  final _lotDocId = TextEditingController();
  bool _busy = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void dispose() {
    _lotDocId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _lotDocId.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesi lotDocId.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.moveLotToShippingZone(companyId: _cid, lotDocId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lot je u otpremnoj zoni (SHIPPING).')),
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
              const Text(
                'Označava fizički prijelaz lota u zonu otpreme prije knjiženja izlaza '
                '(sljedeći korak u praksi: outbound / otpremnica prema postojećim Callable tokovima).',
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
                        hintText: 'wmslot:v1;…',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Skeniraj',
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
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Premjesti u SHIPPING'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
