import 'dart:async';

import 'package:flutter/material.dart';

import '../../../modules/production/bom/widgets/omp_lot_traceability_help.dart';
import '../../../modules/production/qr/production_qr_resolver.dart';
import '../../profile_driven_structured_runtime/widgets/evidence_payload_scan_screen.dart';
import '../services/omp_wms_lot_lookup_service.dart';

/// M1-I11-B — sken / izbor WMS lota + soft fallback ručni unos.
class OmpWmsLotSection extends StatefulWidget {
  const OmpWmsLotSection({
    super.key,
    required this.companyId,
    required this.materialId,
    required this.materialLotController,
    required this.enabled,
    required this.onWmsLotApplied,
    required this.onManualLotApplied,
    required this.onCleared,
    this.initialSource,
  });

  final String companyId;
  final String materialId;
  final TextEditingController materialLotController;
  final bool enabled;
  final String? initialSource;
  final void Function(OmpWmsLotRow lot) onWmsLotApplied;
  final void Function(String lotText) onManualLotApplied;
  final VoidCallback onCleared;

  @override
  State<OmpWmsLotSection> createState() => _OmpWmsLotSectionState();
}

class _OmpWmsLotSectionState extends State<OmpWmsLotSection> {
  final _lookup = OmpWmsLotLookupService();
  bool _loading = false;
  String? _banner;
  bool _softFallback = false;
  List<OmpWmsLotRow> _selectable = const [];
  String _source = '';

  @override
  void initState() {
    super.initState();
    _source = (widget.initialSource ?? '').trim();
    if (widget.materialId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshLots());
      });
    }
  }

  @override
  void didUpdateWidget(covariant OmpWmsLotSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.materialId != widget.materialId) {
      _source = '';
      _selectable = const [];
      _banner = null;
      _softFallback = false;
      if (widget.materialId.trim().isNotEmpty) {
        unawaited(_refreshLots());
      }
    }
  }

  Future<void> _refreshLots() async {
    final mid = widget.materialId.trim();
    if (mid.isEmpty || !widget.enabled) return;
    setState(() {
      _loading = true;
      _banner = null;
    });
    try {
      final res = await _lookup.lookup(
        companyId: widget.companyId,
        materialId: mid,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _selectable = res.selectableLots;
        _softFallback = res.softFallbackAllowed;
        _banner = res.softFallbackReason ?? res.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _softFallback = true;
        _selectable = const [];
        _banner =
            'WMS lotovi trenutno nisu dostupni — unesite lot ručno.';
      });
    }
  }

  Future<void> _scanLot() async {
    if (!widget.enabled) return;
    if (!EvidenceOrderScanUx.useDeviceCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(EvidenceOrderScanUx.scannerUnavailableMessage),
        ),
      );
      return;
    }
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const EvidencePayloadScanScreen(),
      ),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    await _applyScanPayload(raw.trim());
  }

  Future<void> _applyScanPayload(String payload) async {
    final parsed = resolveProductionQrScan(payload);
    final lotDocId = parsed.intent == ProductionQrIntent.wmsLotDocV1
        ? (parsed.wmsLotDocId ?? '').trim()
        : '';
    if (lotDocId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Skenirajte WMS lot (wmslot:v1). Ovaj kod nije inventurni lot.',
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _lookup.lookup(
        companyId: widget.companyId,
        materialId: widget.materialId,
        lotDocId: lotDocId,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      final lot = res.resolvedLot;
      if (lot != null && lot.selectable) {
        _applyWms(lot);
        return;
      }
      setState(() {
        _softFallback = true;
        _banner = res.softFallbackReason ??
            res.message ??
            'WMS lot nije dostupan za izbor.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_banner!)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _softFallback = true;
        _banner = 'Greška pri skenu lota — unesite ručno ako je potrebno.';
      });
    }
  }

  void _applyWms(OmpWmsLotRow lot) {
    widget.materialLotController.text = lot.lotId;
    _source = 'wms';
    widget.onWmsLotApplied(lot);
    setState(() {
      _banner = null;
      _softFallback = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WMS lot: ${lot.lotDisplay}')),
    );
  }

  Future<void> _openPicker() async {
    if (_selectable.isEmpty) {
      setState(() {
        _softFallback = true;
        _banner = _banner ??
            'Nema dostupnog WMS lota — unesite lot ručno.';
      });
      return;
    }
    final chosen = await showModalBottomSheet<OmpWmsLotRow>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Odabir WMS lota',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _selectable.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final row = _selectable[i];
                      return ListTile(
                        title: Text(row.lotDisplay),
                        subtitle: Text(
                          '${row.qtyDisplay} · ${row.warehouseDisplay} · ${row.statusLabel}',
                        ),
                        onTap: () => Navigator.pop(ctx, row),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) _applyWms(chosen);
  }

  void _enableManual() {
    setState(() {
      _softFallback = true;
      _source = 'manual';
      _banner =
          'Ručni unos — lot nije potvrđen kroz WMS.';
    });
    widget.onManualLotApplied(widget.materialLotController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mid = widget.materialId.trim();
    if (mid.isEmpty) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Prvo odaberite materijal, zatim lot / šaržu.'),
        ),
      );
    }

    final isManual = _source == 'manual' ||
        (_softFallback && _source != 'wms');
    final isWms = _source == 'wms';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OmpLotTraceabilityLabeledTitle(label: 'Lot / šarža'),
        const SizedBox(height: 8),
        if (_banner != null) ...[
          Material(
            color: isManual
                ? scheme.tertiaryContainer.withValues(alpha: 0.65)
                : scheme.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_banner!, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (isWms)
          Material(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'WMS lot potvrđen · ${widget.materialLotController.text.trim()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const OmpLotTraceabilityHelpIcon(),
                ],
              ),
            ),
          ),
        if (isManual)
          Material(
            color: scheme.tertiaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ručni unos — lot nije potvrđen kroz WMS.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const OmpLotTraceabilityHelpIcon(),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'WMS lot',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const OmpLotTraceabilityHelpIcon(),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: widget.enabled && !_loading ? _scanLot : null,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Skeniraj WMS lot'),
            ),
            OutlinedButton.icon(
              onPressed: widget.enabled && !_loading ? _openPicker : null,
              icon: const Icon(Icons.list_alt),
              label: Text(
                _selectable.isEmpty
                    ? 'Nema dostupnih lotova'
                    : 'Odaberi WMS lot (${_selectable.length})',
              ),
            ),
            IconButton(
              tooltip: 'Osvježi WMS lotove',
              onPressed: widget.enabled && !_loading ? _refreshLots : null,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_softFallback || _selectable.isEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Ručni unos lota',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const OmpLotTraceabilityHelpIcon(),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.enabled ? _enableManual : null,
              child: const Text('Ručni unos'),
            ),
          ),
        ],
        if (isManual || _softFallback) ...[
          const SizedBox(height: 8),
          TextField(
            controller: widget.materialLotController,
            enabled: widget.enabled,
            decoration: InputDecoration(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lot / šarža (ručno)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const OmpLotTraceabilityHelpIcon(),
                ],
              ),
              helperText:
                  'Koristite samo ako WMS lot nije pronađen ili nije dostupan.',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              _source = 'manual';
              widget.onManualLotApplied(v.trim());
            },
          ),
        ],
      ],
    );
  }
}
