import 'package:flutter/material.dart';

import '../widgets/qms_iatf_help.dart';

/// Centralno mjesto za radne upute, upute za pakovanje, obrasce itd.
/// Kasnije: veza na proizvode i pregled iz detalja proizvoda.
class QualityDocumentationScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const QualityDocumentationScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumentacija'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Dokumentacija',
            message: QmsIatfStrings.documentationHub,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Jedan pregled dokumenata koje tvrtka koristi u kvalitetu i proizvodnji.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Ovdje ćeš kasnije moći držati radne upute, upute za pakovanje, '
            'obrasce i druge dokumente — s mogućnošću veze na proizvode. '
            'Iz detalja proizvoda planiramo brzi uvid u upute, pakovanje i '
            'povezane reklamacije za taj proizvod.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Šta slijedi u razvoju',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Tipovi dokumenata (radni uput, uput za pakovanje, obrazac, …)\n'
                    '• Pohrana datoteka i metapodaci (revizija, važenje)\n'
                    '• Veza na jedan ili više proizvoda iz šifrarnika\n'
                    '• Kartica „Dokumentacija“ u detaljima proizvoda',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
