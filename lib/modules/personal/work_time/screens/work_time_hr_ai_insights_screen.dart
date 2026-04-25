import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/widgets/work_time_demo_banner.dart';
import 'package:production_app/modules/production/ai/screens/production_ai_chat_screen.dart';

/// Ulaz u AI s predloženim pitanjima o ponašanju (kašnjenja, bolovanja, prekovremene).
class WorkTimeHrAiInsightsScreen extends StatelessWidget {
  const WorkTimeHrAiInsightsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  static const List<({String title, String prompt})> _suggestions = [
    (
      title: 'Tko redovito kasni?',
      prompt:
          'Pregledaj podatke o radnom vremenu i navedi koje zaposlenike učestalo kašnje '
          'i koliko to može povećati trošak. Predloži smjernice za upravljanje.',
    ),
    (
      title: 'Bolovanja i odsustva',
      prompt:
          'Koji zaposlenici imaju učestala bolovanja ili duga odsustva? Kratko '
          'sažetak učinka na proizvodnju i mogući HR koraci (bez zdravstvenih dijagnoza).',
    ),
    (
      title: 'Prekovremene sate',
      prompt:
          'Tko rade najviše prekovremenih sati? Je li to uzorak u određenim smjenama '
          'ili odjelima? Predloži kako smanjiti neplanirane prekovremene sate.',
    ),
    (
      title: 'Trošak u odnosu na norme',
      prompt:
          'Poveži kašnjenja, odsustva i prekovremene s povećanjem operativnih troškova. '
          'Daj 3–5 mjerenja koja menadžment može pratiti svaki mjesec (trošak, učestalost, trend).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomoćnik: rad, odsustva, anomalije'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkTimeDemoBanner(),
          const SizedBox(height: 8),
          Text(
            'Odabirom pitanja otvara se asistent s unaprijed upisanom temom. '
            'Koji se podaci mogu uključiti ovisi o vašim ovlastima. '
            'Puni odgovori temelje se na stvarnoj evidenciji odsustava i radnom vremenu.',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ..._suggestions.map(
            (s) => Card(
              child: ListTile(
                title: Text(s.title),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductionAiChatScreen(
                        companyData: companyData,
                        initialInputText: s.prompt,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
