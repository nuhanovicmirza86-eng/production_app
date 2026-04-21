import 'package:flutter/material.dart';

/// Jednostavni Pareto iz liste { reasonKey, seconds }.
///
/// Ako je [reasonLabels] (šifra razloga → naziv iz kataloga) zadan, koristi se
/// za prikaz umjesto golih ključeva.
class OoeLossParetoCard extends StatelessWidget {
  final List<Map<String, dynamic>> losses;
  final String title;
  final Widget? titleTrailing;

  /// [OoeLossReason.code] → ime za prikaz (iz `watchAllReasonsForPlant`).
  final Map<String, String>? reasonLabels;

  const OoeLossParetoCard({
    super.key,
    required this.losses,
    this.title = 'Gubici po razlogu (sekunde)',
    this.titleTrailing,
    this.reasonLabels,
  });

  static String _rowLabel(String reasonKey, Map<String, String>? labels) {
    final k = reasonKey.trim();
    if (k.isEmpty) return '—';
    final name = labels?[k];
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return k;
  }

  @override
  Widget build(BuildContext context) {
    if (losses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ?titleTrailing,
            ],
          ),
        ),
      );
    }
    final maxSec = losses
        .map((e) => (e['seconds'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ?titleTrailing,
              ],
            ),
            const SizedBox(height: 12),
            ...losses.map((row) {
              final key = (row['reasonKey'] ?? '-').toString();
              final sec = (row['seconds'] as num?)?.toInt() ?? 0;
              final w = maxSec <= 0 ? 0.0 : sec / maxSec;
              final line = _rowLabel(key, reasonLabels);
              final showCode =
                  reasonLabels != null &&
                  line != key.trim() &&
                  key.trim().isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line),
                              if (showCode)
                                Text(
                                  key,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        Text('$sec s'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: w.toDouble().clamp(0.0, 1.0),
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
