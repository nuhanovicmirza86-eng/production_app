import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../issues/screens/production_fault_asset_qr_scan_screen.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import '../../tracking/services/production_tracking_assets_service.dart';

/// Odabir stroja iz pogona — lista s pretragom; QR samo Android/iOS.
class OoePlantMachinePickerField extends StatelessWidget {
  const OoePlantMachinePickerField({
    super.key,
    required this.companyId,
    required this.plantKey,
    required this.machines,
    required this.selectedMachineId,
    required this.onSelected,
    this.helperText = 'Odaberi stroj iz odabranog pogona.',
    this.selectedTitleOverride,
  });

  final String companyId;
  final String plantKey;
  final List<ProductionMachineOverview> machines;
  final String? selectedMachineId;
  final void Function(String? machineId, String? displayTitle) onSelected;
  final String helperText;
  final String? selectedTitleOverride;

  bool get _canScanQr {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String? _titleForId(String? id) {
    final mid = (id ?? '').trim();
    if (mid.isEmpty) return null;
    for (final m in machines) {
      if (m.id == mid) return m.title;
    }
    return selectedTitleOverride;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PlantMachinePickerSheet(machines: machines),
    );
    if (picked != null && picked.trim().isNotEmpty) {
      final id = picked.trim();
      String? title;
      for (final m in machines) {
        if (m.id == id) {
          title = m.title;
          break;
        }
      }
      onSelected(id, title);
    }
  }

  Future<void> _scanQr(BuildContext context) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => ProductionFaultAssetQrScanScreen(
          companyId: cid,
          allowedPlantKeys: [pk],
          allowedPlantIds: const [],
        ),
      ),
    );
    if (result == null) return;

    final id = (result['__assetDocId'] ?? '').toString().trim();
    if (id.isEmpty) return;

    onSelected(id, ooeMachineTitleFromQrPayload(result));
  }

  @override
  Widget build(BuildContext context) {
    final mid = (selectedMachineId ?? '').trim();
    final display = _titleForId(mid);
    final hasSelection = mid.isNotEmpty && (display ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Stroj',
                helperText: helperText,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_canScanQr)
                      IconButton(
                        tooltip: 'Skeniraj QR / barkod stroja',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () => _scanQr(context),
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              child: Text(
                hasSelection ? display! : 'Odaberi stroj…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: hasSelection
                    ? null
                    : TextStyle(
                        color: Theme.of(context).hintColor,
                      ),
              ),
            ),
          ),
        ),
        if (mid.isNotEmpty && display == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Stroj je odabran, ali nije u učitanoj listi pogona.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}

class _PlantMachinePickerSheet extends StatefulWidget {
  const _PlantMachinePickerSheet({required this.machines});

  final List<ProductionMachineOverview> machines;

  @override
  State<_PlantMachinePickerSheet> createState() =>
      _PlantMachinePickerSheetState();
}

class _PlantMachinePickerSheetState extends State<_PlantMachinePickerSheet> {
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<ProductionMachineOverview> get _filtered {
    final q = _queryCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.machines;
    return widget.machines
        .where((m) => m.searchHaystack.contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final maxH = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Strojevi pogona',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pretraga',
                hintText: 'Naziv ili šifra stroja',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.machines.isEmpty
                            ? 'Nema evidentiranih strojeva za ovaj pogon.'
                            : 'Nema strojeva koji odgovaraju pretrazi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final m = filtered[i];
                        final subtitle = m.codeLine.isNotEmpty
                            ? m.codeLine
                            : (m.detail.isNotEmpty ? m.detail : null);
                        return ListTile(
                          title: Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle == null
                              ? null
                              : Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.pop(context, m.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Naslov stroja iz QR odgovora kad nije u listi.
String ooeMachineTitleFromQrPayload(Map<String, dynamic> payload) {
  return ProductionAssetDisplayLookup.labelFromAssetData(payload);
}
