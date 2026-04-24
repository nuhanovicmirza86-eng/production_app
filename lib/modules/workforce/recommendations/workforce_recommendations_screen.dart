import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/workforce_callable_service.dart';

/// F5 — server-side preporuke (smjene, kvalifikacije, obuke, odsustva).
class WorkforceRecommendationsScreen extends StatefulWidget {
  const WorkforceRecommendationsScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkforceRecommendationsScreen> createState() =>
      _WorkforceRecommendationsScreenState();
}

class _WorkforceRecommendationsScreenState
    extends State<WorkforceRecommendationsScreen> {
  final _svc = WorkforceCallableService();
  int _horizon = 14;
  Future<Map<String, dynamic>>? _future;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();
  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      return await _svc.getPlanningRecommendations(
        companyId: _companyId,
        plantKey: _plantKey,
        horizonDays: _horizon,
      );
    } on FirebaseFunctionsException catch (e) {
      return {'_error': e.message ?? 'Greška'};
    }
  }

  static List<Map<String, dynamic>> _parseItems(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preporuke i rizik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Sažetak iz matrice kvalifikacija, rasporeda, obuka i operativnih odsustava. '
              'Nije pravni savjet — provjeri prije odluke.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [7, 14, 30].map((d) {
                return ChoiceChip(
                  label: Text('$d d'),
                  selected: _horizon == d,
                  onSelected: (_) {
                    setState(() => _horizon = d);
                    _reload();
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data ?? {};
                final err = data['_error']?.toString();
                if (err != null && err.isNotEmpty) {
                  return Center(child: Text(err));
                }
                final list = _parseItems(data);
                final gen = data['generatedAt']?.toString() ?? '';
                final cnt = data['itemCount'];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        cnt == 0
                            ? 'Nema upozorenja u horizontu — dobar znak.'
                            : 'Nema stavki u odgovoru.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (gen.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Generisano: $gen · ${list.length} stavki',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final it = list[i];
                          final sev =
                              (it['severity'] ?? 'low').toString();
                          final cat =
                              (it['category'] ?? '').toString();
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: Icon(
                                _iconFor(sev),
                                color: _colorFor(context, sev),
                              ),
                              title: Text(
                                (it['title'] ?? '').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (cat.isNotEmpty) '[$cat]',
                                  (it['detail'] ?? '').toString(),
                                ].join(' '),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String s) {
    switch (s) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.flag_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Color _colorFor(BuildContext context, String s) {
    switch (s) {
      case 'high':
        return Theme.of(context).colorScheme.error;
      case 'medium':
        return Theme.of(context).colorScheme.tertiary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
