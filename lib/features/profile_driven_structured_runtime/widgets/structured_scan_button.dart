import 'package:flutter/material.dart';

import '../models/structured_entity_search_result.dart';
import '../services/production_evidence_entity_search_service.dart';
import 'evidence_payload_scan_screen.dart';
import 'evidence_production_order_search_dialog.dart';

/// M1-I5-C7 / C7A — skener (kamera) + pretraga naloga (autocomplete).
class StructuredScanButton extends StatelessWidget {
  const StructuredScanButton({
    super.key,
    required this.companyId,
    this.plantKey,
    required this.searchService,
    required this.onResolved,
    this.enabled = true,
  });

  final String companyId;
  final String? plantKey;
  final ProductionEvidenceEntitySearchCallableService searchService;
  final ValueChanged<StructuredScanResolveResult> onResolved;
  final bool enabled;

  Future<void> _resolvePayload(
    BuildContext context,
    String payload, {
    required bool treatAsOrderLookup,
  }) async {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );

    try {
      final result = await searchService.resolveProductionEvidenceScan(
        companyId: companyId,
        scanPayload: trimmed,
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!result.isKnown) {
        final msg = treatAsOrderLookup ||
                (result.message ?? '').toLowerCase().contains('nalog')
            ? EvidenceOrderScanUx.orderNotFoundMessage
            : (result.message?.trim().isNotEmpty == true
                ? result.message!.trim()
                : EvidenceOrderScanUx.orderNotFoundMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      if (treatAsOrderLookup && result.type != 'production_order') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(EvidenceOrderScanUx.orderNotFoundMessage),
          ),
        );
        return;
      }

      onResolved(result);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(productionEvidenceEntitySearchErrorMessage(e)),
        ),
      );
    }
  }

  Future<void> _openCameraScan(BuildContext context) async {
    if (!EvidenceOrderScanUx.useDeviceCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(EvidenceOrderScanUx.scannerUnavailableMessage),
        ),
      );
      await _openOrderSearch(context);
      return;
    }

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const EvidencePayloadScanScreen(),
      ),
    );
    if (!context.mounted || raw == null || raw.trim().isEmpty) return;
    await _resolvePayload(context, raw, treatAsOrderLookup: false);
  }

  Future<void> _openOrderSearch(BuildContext context) async {
    final result = await showEvidenceProductionOrderSearchDialog(
      context: context,
      companyId: companyId,
      plantKey: plantKey,
      searchService: searchService,
    );
    if (!context.mounted || result == null) return;
    onResolved(result);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: enabled ? () => _openCameraScan(context) : null,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text(EvidenceOrderScanUx.scanButtonLabel),
        ),
        OutlinedButton.icon(
          onPressed: enabled ? () => _openOrderSearch(context) : null,
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text(EvidenceOrderScanUx.manualOrderButtonLabel),
        ),
      ],
    );
  }
}
