import 'package:flutter/material.dart';

import '../data/activity_sector_catalog.dart';

/// Pregled svih djelatnosti iz šifarnika (pretraga po nazivu / kodu).
class ActivitySectorsCatalogScreen extends StatefulWidget {
  const ActivitySectorsCatalogScreen({super.key});

  @override
  State<ActivitySectorsCatalogScreen> createState() =>
      _ActivitySectorsCatalogScreenState();
}

class _ActivitySectorsCatalogScreenState
    extends State<ActivitySectorsCatalogScreen> {
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<ActivitySectorDef> get _all => activitySectorCatalogSorted;

  List<ActivitySectorDef> get _filtered {
    final t = _q.text.trim().toLowerCase();
    if (t.isEmpty) return _all;
    return _all
        .where(
          (e) =>
              e.label.toLowerCase().contains(t) ||
              e.code.toLowerCase().contains(t),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Šifarnik djelatnosti')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(
                labelText: 'Pretraga',
                hintText: 'Naziv ili kod (npr. nace_c25)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Na partneru se čuva samo kod; naziv je uvijek isti za sve '
              'korisnike (nema duplih naziva zbog tipfelera).',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = _filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(e.label, maxLines: 3),
                  subtitle: Text(
                    e.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.blueGrey.shade700,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
