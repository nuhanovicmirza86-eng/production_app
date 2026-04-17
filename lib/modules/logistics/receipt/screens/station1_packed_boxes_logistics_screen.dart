import 'package:flutter/material.dart';

import '../../../production/packing/services/packing_box_service.dart';
import '../../../production/qr/screens/production_qr_scan_screen.dart';
import '../../../production/qr/production_qr_resolver.dart';
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
  final _svc = PackingBoxService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upakovane kutije — Stanica 1'),
        actions: [
          IconButton(
            tooltip: 'Upozorenja za neupakovane stavke',
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: _notifyUnpacked,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'Kutije u ovoj listi imaju status „zatvoreno“. Ostaju vidljive dok ne '
                'potvrdiš prijem (QR ili odabir reda). Zatim se uklanjaju s liste, a roba '
                'ide u odabrani magacin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PackingBoxRecord>>(
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
                  'Nema kutija u redu.\n\n'
                  'Kad operater na Stanici 1 zatvori kutiju i ispiše etiketu, kutija se pojavljuje ovdje. '
                  'Skeniraj QR na etiketi ili odaberi redak, odaberi magacin i potvrdi prijem — '
                  'stavka tada nestaje s liste, a roba se knjiži u magacin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          final theme = Theme.of(context);
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final b = list[i];
              final short = b.id.length > 8 ? b.id.substring(b.id.length - 8) : b.id;
              final t = b.createdAt;
              final timeStr = t != null
                  ? '${t.day.toString().padLeft(2, '0')}.'
                      '${t.month.toString().padLeft(2, '0')}. '
                      '${t.year} · '
                      '${t.hour.toString().padLeft(2, '0')}:'
                      '${t.minute.toString().padLeft(2, '0')}'
                  : '—';
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text('Kutija …$short'),
                  subtitle: Text(
                    '${b.lines.length} stavki · $timeStr · ${b.classification}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: const Text('Čeka prijem'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.secondaryContainer
                            .withValues(alpha: 0.7),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanBox,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Skeniraj kutiju'),
      ),
    );
  }
}
