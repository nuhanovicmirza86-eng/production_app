import 'package:flutter/material.dart';

import '../../../production/packing/packing_box_display_label.dart';
import '../../../production/packing/services/packing_box_service.dart';
import '../../../production/qr/production_qr_resolver.dart';
import '../../../production/qr/screens/production_qr_scan_screen.dart';
import 'packing_box_receipt_screen.dart';

/// Logistika: kutije zatvorene na Stanici 1 koje čekaju prijem; skeniranje QR-a ili odabir s liste.
class Station1PackedBoxesLogisticsScreen extends StatefulWidget {
  const Station1PackedBoxesLogisticsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<Station1PackedBoxesLogisticsScreen> createState() =>
      _Station1PackedBoxesLogisticsScreenState();
}

class _Station1PackedBoxesLogisticsScreenState
    extends State<Station1PackedBoxesLogisticsScreen> {
  static const String _helpText =
      'Kutije u ovoj listi imaju status „zatvoreno“. Ostaju vidljive dok ne '
      'potvrdiš prijem (QR u gornjem desnom uglu ili odabir reda). Zatim se '
      'uklanjaju s liste, a roba ide u izlazni magacin stanice (postavlja Admin '
      'u „Stanice proizvodnje“).';

  final _svc = PackingBoxService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upakovane kutije — Stanica 1'),
        content: const SingleChildScrollView(child: Text(_helpText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBox() async {
    final res = await Navigator.push<ProductionQrScanResolution>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProductionQrScanScreen(companyData: widget.companyData),
      ),
    );
    if (!mounted || res == null) return;
    if (res.intent != ProductionQrIntent.packedStation1BoxV1 ||
        (res.packingBoxId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR nije kutija Stanica 1.')),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PackingBoxReceiptScreen(
          companyData: widget.companyData,
          boxId: res.packingBoxId!,
        ),
      ),
    );
  }

  Future<void> _notifyUnpacked() async {
    final now = DateTime.now();
    final key =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    try {
      await _svc.writeAlertsForUnpackedEntries(
        companyId: _companyId,
        plantKey: _plantKey,
        workDate: key,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Poslana su upozorenja operaterima za stavke bez kutije (za današnji datum).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Upakovane kutije',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Stanica 1',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Upute',
            icon: const Icon(Icons.info_outline),
            onPressed: _showHelp,
          ),
          IconButton(
            tooltip: 'Upozorenja za neupakovane stavke',
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: _notifyUnpacked,
          ),
          IconButton(
            tooltip: 'Skeniraj kutiju',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBox,
          ),
        ],
      ),
      body: StreamBuilder<List<PackingBoxRecord>>(
        stream: _svc.watchClosedPendingReceipt(
          companyId: _companyId,
          plantKey: _plantKey,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nema kutija u redu čekanja.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final b = list[i];
              return Card(
                child: ListTile(
                  isThreeLine: true,
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(PackingBoxDisplayLabel.title(b)),
                  subtitle: Text(
                    [
                      if (PackingBoxDisplayLabel.productSummary(b) != null)
                        PackingBoxDisplayLabel.productSummary(b)!,
                      PackingBoxDisplayLabel.subtitle(b),
                    ].join('\n'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PackingBoxReceiptScreen(
                          companyData: widget.companyData,
                          boxId: b.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
