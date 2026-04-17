import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';
import '../../../logistics/inventory/services/product_warehouse_stock_service.dart';
import '../../tracking/models/production_operator_tracking_entry.dart';
import '../models/production_station_page.dart';
import '../services/production_station_page_service.dart';

/// Admin / menadžer: CRUD definicija stanica 1–3 za trenutni pogon.
class ProductionStationPagesAdminScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionStationPagesAdminScreen({super.key, required this.companyData});

  @override
  State<ProductionStationPagesAdminScreen> createState() =>
      _ProductionStationPagesAdminScreenState();
}

class _ProductionStationPagesAdminScreenState
    extends State<ProductionStationPagesAdminScreen> {
  final _service = ProductionStationPageService();

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  static String _warehouseHint(ProductionStationPage p) {
    final u =
        p.inboundWarehouseId != null && p.inboundWarehouseId!.isNotEmpty;
    final o =
        p.outboundWarehouseId != null && p.outboundWarehouseId!.isNotEmpty;
    if (!u && !o) return '';
    if (u && o) return ' · mag.: ulaz + izlaz';
    if (u) return ' · mag.: ulaz';
    return ' · mag.: izlaz';
  }

  static String _phaseLabel(String phase) {
    switch (phase) {
      case ProductionOperatorTrackingEntry.phasePreparation:
        return 'Pripremna';
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola';
      default:
        return phase;
    }
  }

  Future<void> _openEditor({ProductionStationPage? existing, int? stationSlot}) async {
    var selectedSlot = existing?.stationSlot ?? stationSlot ?? 1;
    final phaseCtrl = TextEditingController(
      text: existing?.phase ??
          ProductionStationPage.defaultPhaseForSlot(selectedSlot),
    );
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var active = existing?.active ?? true;

    final phases = <String>[
      ProductionOperatorTrackingEntry.phasePreparation,
      ProductionOperatorTrackingEntry.phaseFirstControl,
      ProductionOperatorTrackingEntry.phaseFinalControl,
    ];

    if (!phases.contains(phaseCtrl.text)) {
      phaseCtrl.text = phases.first;
    }

    List<WarehouseRef> warehouses = const [];
    try {
      warehouses = await ProductWarehouseStockService().listActiveWarehouses(
        companyId: _companyId,
        plantKey: _plantKey,
      );
    } catch (_) {}

    String? inboundWhId = existing?.inboundWarehouseId;
    String? outboundWhId = existing?.outboundWarehouseId;
    if (inboundWhId != null &&
        inboundWhId.isNotEmpty &&
        !warehouses.any((w) => w.id == inboundWhId)) {
      inboundWhId = null;
    }
    if (outboundWhId != null &&
        outboundWhId.isNotEmpty &&
        !warehouses.any((w) => w.id == outboundWhId)) {
      outboundWhId = null;
    }

    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nova stranica stanice'
                    : 'Uredi stranicu stanice',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (existing == null)
                      DropdownButtonFormField<int>(
                        key: ValueKey<int>(selectedSlot),
                        initialValue: selectedSlot,
                        decoration: const InputDecoration(
                          labelText: 'Stanica (slot)',
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1')),
                          DropdownMenuItem(value: 2, child: Text('2')),
                          DropdownMenuItem(value: 3, child: Text('3')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() {
                            selectedSlot = v;
                            phaseCtrl.text =
                                ProductionStationPage.defaultPhaseForSlot(v);
                          });
                        },
                      )
                    else
                      Text('Stanica: ${existing.stationSlot}'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(phaseCtrl.text),
                      initialValue: phaseCtrl.text,
                      decoration: const InputDecoration(
                        labelText: 'Faza',
                      ),
                      items: phases
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(_phaseLabel(p)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => phaseCtrl.text = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prikazni naziv (opcionalno)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktivno'),
                      value: active,
                      onChanged: (v) => setLocal(() => active = v),
                    ),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Napomena (opcionalno)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey<String?>('in_$inboundWhId'),
                      initialValue: inboundWhId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ulazni magacin',
                        helperText:
                            'Odakle roba dolazi na ovu stanicu (brži i točniji prijem na podu).',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— nije postavljeno —'),
                        ),
                        ...warehouses.map(
                          (w) => DropdownMenuItem<String?>(
                            value: w.id,
                            child: Text('${w.name} (${w.code})'),
                          ),
                        ),
                      ],
                      onChanged: warehouses.isEmpty
                          ? null
                          : (v) => setLocal(() => inboundWhId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey<String?>('out_$outboundWhId'),
                      initialValue: outboundWhId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Izlazni magacin',
                        helperText:
                            'Kamo roba odlazi nakon ove stanice (npr. prijem kutije u logistici).',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— nije postavljeno —'),
                        ),
                        ...warehouses.map(
                          (w) => DropdownMenuItem<String?>(
                            value: w.id,
                            child: Text('${w.name} (${w.code})'),
                          ),
                        ),
                      ],
                      onChanged: warehouses.isEmpty
                          ? null
                          : (v) => setLocal(() => outboundWhId = v),
                    ),
                    if (warehouses.isEmpty)
                      Text(
                        'Nema aktivnih magacina za ovaj pogon — dodajte magacin u master podacima.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.error,
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
                  child: const Text('Spremi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Niste prijavljeni.')),
      );
      return;
    }

    if (_companyId.isEmpty || _plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje companyId ili plantKey u profilu.'),
        ),
      );
      return;
    }

    final effectiveSlot = existing?.stationSlot ?? selectedSlot;
    final pageId = ProductionStationPage.buildPageId(
      companyId: _companyId,
      plantKey: _plantKey,
      stationSlot: effectiveSlot,
    );

    final page = ProductionStationPage(
      id: pageId,
      companyId: _companyId,
      plantKey: _plantKey,
      stationSlot: effectiveSlot,
      phase: phaseCtrl.text.trim(),
      displayName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      active: active,
      provisionedByUid: existing?.provisionedByUid ?? user.uid,
      provisionedByEmail: existing?.provisionedByEmail,
      provisionedAt: existing?.provisionedAt ?? DateTime.now(),
      updatedAt: existing?.updatedAt ?? DateTime.now(),
      updatedByUid: user.uid,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      inboundWarehouseId: () {
        final w = inboundWhId?.trim();
        if (w == null || w.isEmpty) return null;
        return w;
      }(),
      outboundWarehouseId: () {
        final w = outboundWhId?.trim();
        if (w == null || w.isEmpty) return null;
        return w;
      }(),
    );

    try {
      if (existing == null) {
        await _service.createPage(
          page: page,
          currentUid: user.uid,
          currentEmail: user.email,
        );
      } else {
        await _service.updatePage(page: page, currentUid: user.uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spremljeno.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stranice stanica'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: _companyId.isEmpty || _plantKey.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'U profilu nedostaje companyId ili plantKey — stranice stanica nisu dostupne.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<List<ProductionStationPage>>(
              stream: _service.watchPages(
                companyId: _companyId,
                plantKey: _plantKey,
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Greška učitavanja: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pages = snap.data!;
                if (pages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Još nema definiranih stanica za ovaj pogon.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _openEditor(),
                            icon: const Icon(Icons.add),
                            label: const Text('Dodaj prvu stanicu'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: pages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = pages[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kOperonixProductionBrandGreen
                              .withValues(alpha: 0.15),
                          child: Text(
                            '${p.stationSlot}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kOperonixProductionBrandGreen,
                            ),
                          ),
                        ),
                        title: Text(
                          p.displayName?.isNotEmpty == true
                              ? p.displayName!
                              : 'Stanica ${p.stationSlot}',
                        ),
                        subtitle: Text(
                          '${_phaseLabel(p.phase)} · '
                          '${p.active ? "aktivno" : "neaktivno"}'
                          '${_warehouseHint(p)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openEditor(existing: p),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
