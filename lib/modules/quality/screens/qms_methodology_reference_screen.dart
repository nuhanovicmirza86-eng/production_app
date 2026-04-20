import 'package:flutter/material.dart';

import '../widgets/qms_iatf_help.dart';

/// Pregled veze između reakcijskog plana, akcijskog (CAPA) plana, PFMEA-e i ocjena rizika.
class QmsMethodologyReferenceScreen extends StatelessWidget {
  const QmsMethodologyReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metodologija · IATF'),
        actions: [
          QmsIatfInfoIcon(
            title: 'Zašto ovaj pregled',
            message: QmsIatfStrings.methodologyWhy,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Reakcijski plan, akcijski plan, PFMEA i ocjene rizika nadopunjuju se u QMS-u — '
            'nisu isti dokument, ali tvore logičan lanac od planiranja do rješavanja nesklada.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.speed_outlined,
            title: 'Pregled lanca',
            body: QmsIatfStrings.methodologyOverview,
            accent: cs.primary,
          ),
          _SectionCard(
            icon: Icons.bolt_outlined,
            title: 'Reakcijski plan',
            body: QmsIatfStrings.termReactionPlan,
            accent: cs.tertiary,
          ),
          _SectionCard(
            icon: Icons.task_alt_outlined,
            title: 'Akcijski plan (CAPA)',
            body: QmsIatfStrings.termActionPlan,
            accent: cs.secondary,
          ),
          _SectionCard(
            icon: Icons.account_tree_outlined,
            title: 'PFMEA',
            body: QmsIatfStrings.termPfmea,
            accent: cs.primary,
          ),
          _SectionCard(
            icon: Icons.analytics_outlined,
            title: 'Ocjene rizika',
            body: QmsIatfStrings.termRiskRatings,
            accent: cs.secondary,
          ),
          _SectionCard(
            icon: Icons.app_shortcut_outlined,
            title: 'Samo Production (bez Maintenance modula)',
            body: QmsIatfStrings.methodologyProductionOnlyPfmea,
            accent: cs.tertiary,
          ),
          const SizedBox(height: 8),
          Text(
            'U aplikaciji: NCR nosi reakcijski plan i containment; CAPA je akcijski plan s 8D/Ishikawom. '
            'PFMEA na stroju — Maintenance; puni PFMEA za QMS bez Maintenance modula — kroz budući QMS PFMEA u Productionu (Callable).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
