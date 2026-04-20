import 'package:flutter/material.dart';

import '../../production/qr/production_qr_scan_flow.dart';

/// Sken-first tok: LOT ili nalog → učitavanje plana → mjerenje → OK/NOK.
class ExecuteInspectionScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ExecuteInspectionScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izvrši inspekciju')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Skeniraj LOT ili nalog'),
            onPressed: () async {
              await runProductionQrScanFlow(
                context: context,
                companyData: companyData,
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Nakon skena, aplikacija će učitati odgovarajući inspection_plan i prikazati karakteristike iz kontrolnog plana (bez ručnog biranja mjerenja). '
            'Implementacija: povezivanje s ProductionQrResolver i Callable za snimanje inspection_results.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
