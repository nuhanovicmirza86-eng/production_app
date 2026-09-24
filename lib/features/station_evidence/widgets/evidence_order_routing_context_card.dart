import 'package:flutter/material.dart';

import '../../../modules/production/station_work/models/production_station_work_session.dart';
import '../utils/evidence_order_context_display.dart';

/// M1-I14-B — read-only poslovni kontekst naloga (routing snapshot) na detalju evidencije.
class EvidenceOrderRoutingContextCard extends StatelessWidget {
  const EvidenceOrderRoutingContextCard({
    super.key,
    required this.snapshot,
  });

  final ProductionStationWorkOrderSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final orderCode = snapshot.productionOrderCode.trim();
    final routing = EvidenceOrderContextDisplay.operationLabelFromSnapshot(snapshot);
    final workCenter =
        EvidenceOrderContextDisplay.workCenterLabelFromSnapshot(snapshot);
    final bom = EvidenceOrderContextDisplay.bomVersionLabelFromSnapshot(snapshot);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kontekst proizvodnog naloga',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (orderCode.isNotEmpty)
              _row(context, 'Proizvodni nalog', orderCode),
            _row(
              context,
              'Proizvod',
              EvidenceOrderContextDisplay.productLabelFromSnapshot(snapshot),
            ),
            _row(context, 'Operacija', routing),
            if (workCenter != null)
              _row(context, 'Radni centar', workCenter),
            if (bom != null) _row(context, 'Normativ (BOM)', bom),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
