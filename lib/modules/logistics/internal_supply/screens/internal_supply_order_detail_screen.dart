import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../wms/wms_scan_helpers.dart';
import '../services/internal_supply_service.dart';

/// Detalj interne narudžbe: hub (pick → spremno → otprem) ili odredište (zaprimanje).
class InternalSupplyOrderDetailScreen extends StatefulWidget {
  const InternalSupplyOrderDetailScreen({
    super.key,
    required this.companyData,
    required this.orderId,
    required this.hubMode,
  });

  final Map<String, dynamic> companyData;
  final String orderId;
  /// true = akcije na hubu; false = zaprimanje na odredištu.
  final bool hubMode;

  @override
  State<InternalSupplyOrderDetailScreen> createState() =>
      _InternalSupplyOrderDetailScreenState();
}

class _InternalSupplyOrderDetailScreenState
    extends State<InternalSupplyOrderDetailScreen> {
  final _svc = InternalSupplyService();
  bool _busy = false;

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPickDialog(
    String lineId,
    String itemId,
    String hubWarehouseId,
  ) async {
    late final Map<String, dynamic> guidance;
    try {
      guidance = await _svc.getInternalSupplyLinePickGuidance(
        companyId: _cid,
        orderId: widget.orderId,
        lineId: lineId,
        hubWarehouseId: hubWarehouseId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toMessage(e))),
        );
      }
      return;
    }

    if (!mounted) return;

    final lotDocCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final rec = guidance['recommendedFirst'];
    if (rec is Map) {
      lotDocCtrl.text = (rec['lotDocId'] ?? '').toString();
    }
    final qr = guidance['quantityRequested'];
    if (qr is num) {
      qtyCtrl.text = qr.toString();
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda preuzimanja na hubu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (guidance['message'] != null)
                Text(
                  guidance['message'].toString(),
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              TextField(
                controller: lotDocCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lot (Firestore doc id)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Količina',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Razlog ako nije FIFO (obavezno pri odstupanju)',
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Potvrdi'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      lotDocCtrl.dispose();
      qtyCtrl.dispose();
      reasonCtrl.dispose();
      return;
    }

    final pickedLotDocId = lotDocCtrl.text.trim();
    final pq = double.tryParse(qtyCtrl.text.trim().replaceAll(',', '.'));
    final reason = reasonCtrl.text.trim();
    lotDocCtrl.dispose();
    qtyCtrl.dispose();
    reasonCtrl.dispose();

    if (pickedLotDocId.isEmpty || pq == null || pq <= 0) {
      return;
    }

    await _run(() async {
      await _svc.hubConfirmPickForLine(
        companyId: _cid,
        orderId: widget.orderId,
        lineId: lineId,
        pickedLotDocId: pickedLotDocId,
        pickedQty: pq,
        fifoOverrideReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preuzimanje je zabilježeno.')),
        );
      }
    });
  }

  /// Sken (QR/barkod): očekuje se Firestore id stavke ili zadnji segment u `;`-odvojenom payloadu.
  String? _matchPendingLineIdFromScan(
    String raw,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    bool isPending(String ls) => ls == 'pending_receipt';
    for (final d in docs) {
      final ls = (d.data()['lineStatus'] ?? '').toString();
      if (!isPending(ls)) continue;
      if (d.id == t) return d.id;
    }
    final parts = t.split(';');
    if (parts.isNotEmpty) {
      final last = parts.last.trim();
      if (last.isNotEmpty) {
        for (final d in docs) {
          final ls = (d.data()['lineStatus'] ?? '').toString();
          if (!isPending(ls)) continue;
          if (d.id == last) return d.id;
        }
      }
    }
    return null;
  }

  Future<void> _scanDestReceive(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (!mounted) return;
    final raw = await wmsScanBarcodeRaw(
      context,
      companyData: widget.companyData,
    );
    if (raw == null || !mounted) return;
    final lineId = _matchPendingLineIdFromScan(raw, docs);
    if (lineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sken ne odgovara stavci na čekanju (očekuje se ID stavke iz etikete).',
          ),
        ),
      );
      return;
    }
    await _run(() async {
      await _svc.destReceiveInternalSupplyLine(
        companyId: _cid,
        orderId: widget.orderId,
        lineId: lineId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stavka zaprimljena.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance
        .collection('internal_supply_orders')
        .doc(widget.orderId);

    return Scaffold(
      appBar: AppBar(title: const Text('Interna narudžba')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Narudžba ne postoji.'));
          }
          final o = snap.data!.data() ?? {};
          final status = (o['status'] ?? '').toString();
          final code = (o['requestCode'] ?? widget.orderId).toString();
          final hubId = (o['supplyingWarehouseId'] ?? '').toString();
          final destId = (o['requestingWarehouseId'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                code,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('Status: $status'),
              Text('Hub: $hubId → odredište: $destId'),
              const Divider(height: 24),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('internal_supply_order_lines')
                    .where('parentOrderId', isEqualTo: widget.orderId)
                    .snapshots(),
                builder: (context, lineSnap) {
                  if (!lineSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = lineSnap.data!.docs.toList()
                    ..sort(
                      (a, b) => ((a.data()['lineNo'] ?? 0) as num).compareTo(
                        (b.data()['lineNo'] ?? 0) as num,
                      ),
                    );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...docs.map((d) {
                        final ld = d.data();
                        final lineId = d.id;
                        final ls = (ld['lineStatus'] ?? '').toString();
                        final name = (ld['itemName'] ?? ld['itemId']).toString();
                        final qty = ld['quantity'];
                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(
                              'Stavka $ls · količina $qty · ${ld['unit'] ?? 'pcs'}',
                            ),
                            trailing: widget.hubMode &&
                                    ls == 'open' &&
                                    [
                                      'submitted',
                                      'hub_picking',
                                      'hub_ready_to_ship',
                                    ].contains(status)
                                ? IconButton(
                                    icon: const Icon(Icons.inventory_2_outlined),
                                    onPressed: _busy
                                        ? null
                                        : () => _openPickDialog(
                                            lineId,
                                            (ld['itemId'] ?? '').toString(),
                                            hubId,
                                          ),
                                  )
                                : null,
                          ),
                        );
                      }),
                      if (widget.hubMode) ...[
                        const SizedBox(height: 16),
                        if ([
                          'submitted',
                          'hub_picking',
                        ].contains(status))
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await _svc.hubMarkOrderReadyToShip(
                                      companyId: _cid,
                                      orderId: widget.orderId,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Označeno spremno za otpremu.',
                                          ),
                                        ),
                                      );
                                    }
                                  }),
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: const Text('Spremno za otpremu'),
                          ),
                        if ([
                          'submitted',
                          'hub_picking',
                          'hub_ready_to_ship',
                        ].contains(status))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await _svc.hubShipInternalSupplyOrder(
                                        companyId: _cid,
                                        orderId: widget.orderId,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Otprem knjižen.'),
                                          ),
                                        );
                                      }
                                    }),
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Pošalji na odredište (otprem)'),
                            ),
                          ),
                      ],
                      if (!widget.hubMode &&
                          [
                            'awaiting_receipt',
                            'in_transit',
                          ].contains(status)) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _scanDestReceive(docs),
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            label: const Text('Skeniraj zaprimanje'),
                          ),
                        ),
                      ],
                      if (!widget.hubMode &&
                          [
                            'awaiting_receipt',
                            'in_transit',
                          ].contains(status))
                        ...docs.expand((d) {
                          final ld = d.data();
                          final ls = (ld['lineStatus'] ?? '').toString();
                          if (ls != 'pending_receipt') {
                            return <Widget>[];
                          }
                          final lineId = d.id;
                          return [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        await _svc.destReceiveInternalSupplyLine(
                                          companyId: _cid,
                                          orderId: widget.orderId,
                                          lineId: lineId,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Stavka zaprimljena.',
                                              ),
                                            ),
                                          );
                                        }
                                      }),
                                child: Text('Zaprimi: ${ld['itemName']}'),
                              ),
                            ),
                          ];
                        }),
                      if (!widget.hubMode &&
                          [
                            'awaiting_receipt',
                            'in_transit',
                          ].contains(status))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    final noteCtrl = TextEditingController();
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Zatvori narudžbu'),
                                        content: TextField(
                                          controller: noteCtrl,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Napomena (ako nema zaprimanja)',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Odustani'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Zatvori'),
                                          ),
                                        ],
                                      ),
                                    );
                                    final note = noteCtrl.text.trim();
                                    noteCtrl.dispose();
                                    if (ok != true || !context.mounted) {
                                      return;
                                    }
                                    await _run(() async {
                                      await _svc.destCompleteInternalSupplyOrder(
                                        companyId: _cid,
                                        orderId: widget.orderId,
                                        completionNote: note,
                                      );
                                    });
                                  },
                            child: const Text('Zatvori narudžbu (completed)'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
