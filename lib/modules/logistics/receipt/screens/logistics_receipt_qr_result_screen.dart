import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../screens/logistics_hub_entry_screen.dart';
import '../../warehouse_hub/services/warehouse_hub_service.dart';

/// Nakon skena `rcpt:v1;…` — sažetak prijema i ulaz u hub (bez prikaza internih ID-eva).
class LogisticsReceiptQrResultScreen extends StatefulWidget {
  const LogisticsReceiptQrResultScreen({
    super.key,
    required this.companyData,
    required this.receiptDocId,
  });

  final Map<String, dynamic> companyData;
  final String receiptDocId;

  @override
  State<LogisticsReceiptQrResultScreen> createState() =>
      _LogisticsReceiptQrResultScreenState();
}

class _LogisticsReceiptQrResultScreenState
    extends State<LogisticsReceiptQrResultScreen> {
  static const int _hubReceiptsTabIndex = 7;

  final _hub = WarehouseHubService();
  Map<String, String> _warehouseLabelById = {};

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _loadWarehouseLabels();
  }

  Future<void> _loadWarehouseLabels() async {
    if (_cid.isEmpty) return;
    try {
      final rows = await _hub.listWarehouses(companyId: _cid);
      if (!mounted) return;
      final m = <String, String>{};
      for (final r in rows) {
        final name = r.name.trim();
        final code = r.code.trim();
        m[r.id] = name.isNotEmpty
            ? name
            : (code.isNotEmpty ? code : 'Magacin');
      }
      setState(() => _warehouseLabelById = m);
    } catch (_) {
      if (mounted) setState(() => _warehouseLabelById = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.receiptDocId.trim();
    final ref = FirebaseFirestore.instance.collection('logistics_receipts').doc(
          id,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Skenirani prijem')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: ref.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  'Greška pri učitavanju.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final doc = snap.data!;
              if (!doc.exists) {
                return const Text('Dokument nije dostupan.');
              }
              final d = doc.data() ?? {};
              final docCid = (d['companyId'] ?? '').toString().trim();
              if (docCid.isNotEmpty && docCid != _cid) {
                return Text(
                  'Dokument pripada drugoj kompaniji.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                );
              }
              final code = (d['receiptCode'] ?? '').toString().trim();
              final whId = (d['destinationWarehouseId'] ?? '').toString().trim();
              final whName = whId.isNotEmpty
                  ? (_warehouseLabelById[whId] ?? 'Magacin')
                  : '';
              final lines = d['totalLines'];
              final linesStr = lines == null
                  ? ''
                  : (lines is num
                        ? lines.toInt().toString()
                        : lines.toString().trim());
              final po = (d['supplierOrderRef'] ?? '').toString().trim();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (code.isNotEmpty)
                    Text(
                      code,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (whName.isNotEmpty) Text('Magacin: $whName'),
                  if (linesStr.isNotEmpty) Text('Broj stavki: $linesStr'),
                  if (po.isNotEmpty) Text('Narudžba: $po'),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => LogisticsHubEntryScreen(
                    companyData: widget.companyData,
                    initialTabIndex: _hubReceiptsTabIndex,
                  ),
                ),
              );
            },
            child: const Text('Otvori evidenciju prijema'),
          ),
        ],
      ),
    );
  }
}
