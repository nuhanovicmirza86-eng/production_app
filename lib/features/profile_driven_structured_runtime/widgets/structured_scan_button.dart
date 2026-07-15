import 'package:flutter/material.dart';

import '../models/structured_entity_search_result.dart';
import '../services/production_evidence_entity_search_service.dart';

/// Ručni scan fallback — validacija kroz `resolveProductionEvidenceScan`.
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

  Future<void> _openScanDialog(BuildContext context) async {
    final controller = TextEditingController();
    var busy = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              final payload = controller.text.trim();
              if (payload.isEmpty) {
                setLocalState(() => errorText = 'Unesite skenirani kod.');
                return;
              }
              setLocalState(() {
                busy = true;
                errorText = null;
              });
              try {
                final result = await searchService.resolveProductionEvidenceScan(
                  companyId: companyId,
                  scanPayload: payload,
                );
                if (!context.mounted) return;
                if (!result.isKnown) {
                  setLocalState(() {
                    busy = false;
                    errorText = result.message ??
                        'Skenirani kod nije pronađen u bazi.';
                  });
                  return;
                }
                Navigator.pop(context);
                onResolved(result);
              } catch (e) {
                if (!context.mounted) return;
                setLocalState(() {
                  busy = false;
                  errorText = productionEvidenceEntitySearchErrorMessage(e);
                });
              }
            }

            return AlertDialog(
              title: const Text('Skeniraj'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Unesite ili skenirajte barkod / QR kod. Vrijednost se validira na serveru.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Skenirani kod',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: busy ? null : (_) => submit(),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Validiraj'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => _openScanDialog(context) : null,
      icon: const Icon(Icons.qr_code_scanner),
      label: const Text('Skeniraj'),
    );
  }
}
