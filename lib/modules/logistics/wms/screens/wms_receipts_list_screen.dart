import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/wms_tab_scaffold.dart';

/// Pregled zadnjih prijema (`logistics_receipts`) — samo čitanje, tenant u pravilima.
class WmsReceiptsListScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  final bool embedInHubShell;

  const WmsReceiptsListScreen({
    super.key,
    required this.companyData,
    this.embedInHubShell = false,
  });

  String get _cid =>
      (companyData['companyId'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    if (cid.isEmpty) {
      return wmsTabScaffold(
        embedInHubShell: embedInHubShell,
        title: 'Prijemi robe (GR)',
        body: const Center(child: Text('Nedostaje companyId.')),
      );
    }

    return wmsTabScaffold(
      embedInHubShell: embedInHubShell,
      title: 'Prijemi robe (GR)',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('logistics_receipts')
            .where('companyId', isEqualTo: cid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Greška: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Nema prijema.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final code = (d['receiptCode'] ?? docs[i].id).toString();
              final wh = (d['destinationWarehouseId'] ?? '').toString();
              final lines = (d['totalLines'] ?? '').toString();
              final po = (d['supplierOrderRef'] ?? '').toString();
              final ts = d['createdAt'];
              String when = '';
              if (ts is Timestamp) {
                when = ts.toDate().toLocal().toString().substring(0, 16);
              }
              return Card(
                child: ListTile(
                  title: Text(code),
                  subtitle: Text(
                    'Magacin: $wh · stavki: $lines'
                    '${po.isNotEmpty ? ' · PO: $po' : ''}'
                    '${when.isNotEmpty ? '\n$when' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
