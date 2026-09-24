import 'package:flutter/material.dart';

import '../bom_item_traceability.dart';
import 'omp_lot_traceability_help.dart';

/// M1-I11-C — dropdown polja klasifikacije u BOM item dijalogu.
class BomItemTraceabilityFormFields extends StatelessWidget {
  const BomItemTraceabilityFormFields({
    super.key,
    required this.kind,
    required this.mode,
    required this.lotRequired,
    required this.onChanged,
  });

  final String? kind;
  final String? mode;
  final bool? lotRequired;
  final void Function({
    String? nextKind,
    String? nextMode,
    bool? nextLotRequired,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: normalizeBomItemKind(kind),
          decoration: const InputDecoration(
            labelText: 'Vrsta stavke',
          ),
          items: [
            for (final code in kBomItemKindCodes)
              DropdownMenuItem(
                value: code,
                child: Text(kBomItemKindLabelsBs[code]!),
              ),
          ],
          onChanged: (v) => onChanged(nextKind: v),
          validator: (v) =>
              normalizeBomItemKind(v) == null ? 'Odaberite vrstu stavke.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: normalizeBomTraceabilityMode(mode),
          decoration: InputDecoration(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Način sljedivosti',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const OmpLotTraceabilityHelpIcon(),
              ],
            ),
          ),
          items: [
            for (final code in kBomTraceabilityModeCodes)
              DropdownMenuItem(
                value: code,
                child: Text(kBomTraceabilityModeLabelsBs[code]!),
              ),
          ],
          onChanged: (v) {
            if (v == bomTraceabilityNone) {
              onChanged(nextMode: v, nextLotRequired: false);
            } else {
              onChanged(nextMode: v);
            }
          },
          validator: (v) => normalizeBomTraceabilityMode(v) == null
              ? 'Odaberite način sljedivosti.'
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          value: lotRequired,
          decoration: const InputDecoration(
            labelText: 'Lot obavezan',
          ),
          items: const [
            DropdownMenuItem(value: true, child: Text('Da')),
            DropdownMenuItem(value: false, child: Text('Ne')),
          ],
          onChanged: mode == bomTraceabilityNone
              ? null
              : (v) => onChanged(nextLotRequired: v),
          validator: (v) {
            if (v == null) return 'Odaberite da li je lot obavezan.';
            if (mode == bomTraceabilityNone && v == true) {
              return 'Za način „Bez lota” lot ne može biti obavezan.';
            }
            return null;
          },
        ),
      ],
    );
  }
}
