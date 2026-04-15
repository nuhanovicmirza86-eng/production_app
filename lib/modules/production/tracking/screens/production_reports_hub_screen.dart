import 'package:flutter/material.dart';

import 'production_operator_tracking_day_report_screen.dart';

/// Centralno mjesto za izvještaje iz praćenja proizvodnje (otpadi, dnevni sastav, IATF).
class ProductionReportsHubScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ProductionReportsHubScreen({super.key, required this.companyData});

  void _soon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title — izvještaj u pripremi (Firestore + agregacije).',
        ),
      ),
    );
  }

  void _openDailyTrackingReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductionOperatorTrackingDayReportScreen(companyData: companyData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Izvještaji proizvodnje')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(theme, 'Otpad i kvalitet'),
          _ReportTile(
            icon: Icons.pie_chart_outline,
            title: 'Otpad po tipu škarta',
            subtitle: 'Agregacija po periodu i pogonskoj jedinici.',
            onTap: () => _soon(context, 'Otpad po tipu'),
          ),
          _ReportTile(
            icon: Icons.stacked_bar_chart,
            title: 'Otpad po proizvodu (dnevna proizvodnja)',
            subtitle: 'Usporedba dobrog komada i škarta po smjeni / danu.',
            onTap: () => _soon(context, 'Otpad po proizvodu'),
          ),
          _ReportTile(
            icon: Icons.trending_up,
            title: 'Trend kvaliteta po proizvodnoj liniji',
            subtitle: 'KPI i signalizacija odstupanja.',
            onTap: () => _soon(context, 'Trend kvaliteta'),
          ),
          const Divider(height: 24),
          _SectionHeader(theme, 'Dnevna i operativna evidencija'),
          _ReportTile(
            icon: Icons.today_outlined,
            title: 'Dnevni list pripreme / kontrola',
            subtitle: 'PDF po datumu i fazi (podaci iz operativnog praćenja).',
            onTap: () => _openDailyTrackingReport(context),
          ),
          _ReportTile(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Evidencija naloga i veza na narudžbe',
            subtitle: 'Traceability sirovina → gotov proizvod.',
            onTap: () => _soon(context, 'Traceability'),
          ),
          const Divider(height: 24),
          _SectionHeader(theme, 'IATF i akcije'),
          _ReportTile(
            icon: Icons.warning_amber_rounded,
            title: 'Proizvodi s povećanim udjelom škarta',
            subtitle: 'Pragovi po kompaniji; prikaz kandidata za CAPA.',
            onTap: () => _soon(context, 'Povećani škart'),
          ),
          _ReportTile(
            icon: Icons.task_alt_outlined,
            title: 'Akcioni planovi',
            subtitle: 'IATF 10.2 — planirane i otvorene akcije.',
            onTap: () => _soon(context, 'Akcioni plan'),
          ),
          _ReportTile(
            icon: Icons.bolt_outlined,
            title: 'Reakcioni planovi',
            subtitle: 'Brzi odgovori na odstupanja (containment).',
            onTap: () => _soon(context, 'Reakcioni plan'),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Napomena: detaljne kalkulacije i izvoz (PDF/Excel) vezat će se na iste kolekcije kao operativni unos u tabovima praćenja.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final ThemeData theme;
  final String text;

  const _SectionHeader(this.theme, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
