import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../wms_lot_label_helper.dart';
import 'wms_putaway_screen.dart';
import 'wms_shipping_screen.dart';

/// Nakon skena `wmslot:v1;…` — sažetak lota i sljedeći korak (bez internog ID-a u UI-ju).
class WmsLotScanResultScreen extends StatelessWidget {
  const WmsLotScanResultScreen({
    super.key,
    required this.companyData,
    required this.lotDocId,
  });

  final Map<String, dynamic> companyData;
  final String lotDocId;

  String get _cid =>
      (companyData['companyId'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final id = lotDocId.trim();
    final ref = FirebaseFirestore.instance.collection('inventory_lots').doc(id);

    return Scaffold(
      appBar: AppBar(title: const Text('Skenirani lot')),
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
                return const Text('Lot nije dostupan.');
              }
              final d = doc.data() ?? {};
              final docCid = (d['companyId'] ?? '').toString().trim();
              if (docCid.isNotEmpty && docCid != _cid) {
                return Text(
                  'Lot pripada drugoj kompaniji.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                );
              }
              final cap = wmsLotCaptionFromDocData(d);
              final st = (d['status'] ?? '').toString().trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cap, style: Theme.of(context).textTheme.titleMedium),
                  if (st.isNotEmpty) Text('Status: $st'),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Sljedeći korak', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WmsPutawayScreen(
                    companyData: companyData,
                    initialLotDocId: id,
                  ),
                ),
              );
            },
            child: const Text('Putaway (smještaj)'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WmsShippingScreen(
                    companyData: companyData,
                    initialLotDocId: id,
                  ),
                ),
              );
            },
            child: const Text('Otpremna zona'),
          ),
        ],
      ),
    );
  }
}
