import 'package:flutter/material.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../../quality/screens/capa_tracking_screen.dart';
import '../../../quality/screens/execute_inspection_screen.dart';
import '../../../quality/screens/ncr_list_screen.dart';
import '../../../quality/screens/quality_dashboard_screen.dart';
import '../../ai_analysis/screens/ai_analysis_screen.dart';
import '../../analytics/screens/operonix_analytics_dashboard_screen.dart';
import '../../reports/screens/production_ai_report_screen.dart';
import 'production_operator_tracking_day_report_screen.dart';
import 'quality_trend_by_line_report_screen.dart';
import 'waste_by_product_report_screen.dart';
import 'waste_by_scrap_type_report_screen.dart';

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

  void _openQms(
    BuildContext context,
    Widget screen,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qms = ProductionModuleKeys.hasModule(
      companyData,
      ProductionModuleKeys.quality,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Izvještaji proizvodnje')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (ProductionAccessHelper.canView(
                role: (companyData['role'] ?? '').toString(),
                card: ProductionDashboardCard.operonixAnalytics,
              )) ...[
            _SectionHeader(theme, 'Operonix Analytics'),
            _ReportTile(
              icon: Icons.analytics_outlined,
              title: 'Operonix Analytics Dashboard',
              subtitle:
                  'Centralni KPI (OEE/OOE/TEEP), Pareto zastoja, trend, smjene, automatski OperonixAI sažetak.',
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OperonixAnalyticsDashboardScreen(companyData: companyData),
                  ),
                );
              },
            ),
            const Divider(height: 24),
          ],
          if (ProductionModuleKeys.hasAnyProductionAiHubAccess(companyData) &&
              ((ProductionModuleKeys.hasAiProductionMarkdownReportModule(
                        companyData,
                      ) &&
                      productionAiReportVisibleForRole(companyData['role'])) ||
                  (ProductionModuleKeys.hasAiProductionAnalyticsModule(
                        companyData,
                      ) &&
                      aiStructuredAnalysisVisibleForRole(
                        companyData['role'],
                      )))) ...[
            _SectionHeader(theme, kOperonixAiShortLabel),
            if (ProductionModuleKeys.hasAiProductionMarkdownReportModule(
                  companyData,
                ) &&
                productionAiReportVisibleForRole(companyData['role']))
              _ReportTile(
                icon: Icons.auto_awesome_outlined,
                title: 'AI izvještaj — proizvodnja',
                subtitle:
                    'Sažetak praćenja i naloga za odabrani period (Gemini, backend).',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ProductionAiReportScreen(companyData: companyData),
                    ),
                  );
                },
              ),
            if (ProductionModuleKeys.hasAiProductionAnalyticsModule(
                  companyData,
                ) &&
                aiStructuredAnalysisVisibleForRole(companyData['role']))
              _ReportTile(
                icon: Icons.hub_outlined,
                title: 'AI analiza — strukturirani podaci',
                subtitle:
                    'SCADA / OEE / tok proizvodnje (Callable runAiAnalysis, ne chat).',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AiAnalysisScreen(companyData: companyData),
                    ),
                  );
                },
              ),
            const Divider(height: 24),
          ],
          if (qms) ...[
            _SectionHeader(theme, 'QMS — kvalitet (pretplata)'),
            _ReportTile(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard kvaliteta',
              subtitle: 'KPI: planovi, otvoreni NCR i CAPA.',
              onTap: () => _openQms(
                context,
                QualityDashboardScreen(companyData: companyData),
              ),
            ),
            _ReportTile(
              icon: Icons.qr_code_scanner,
              title: 'Izvrši kontrolu',
              subtitle: 'Sken LOT-a ili naloga, mjerenja, NCR pri NOK.',
              onTap: () => _openQms(
                context,
                ExecuteInspectionScreen(companyData: companyData),
              ),
            ),
            _ReportTile(
              icon: Icons.warning_amber_outlined,
              title: 'NCR — neskladi',
              subtitle: 'Evidencija i statusi (IATF 10.2).',
              onTap: () => _openQms(
                context,
                NcrListScreen(companyData: companyData),
              ),
            ),
            _ReportTile(
              icon: Icons.task_alt_outlined,
              title: 'CAPA — praćenje',
              subtitle: 'Korektivne i preventivne akcije.',
              onTap: () => _openQms(
                context,
                CapaTrackingScreen(companyData: companyData),
              ),
            ),
            const Divider(height: 24),
          ],
          _SectionHeader(theme, 'Otpad i kvalitet'),
          _ReportTile(
            icon: Icons.pie_chart_outline,
            title: 'Otpad po tipu škarta',
            subtitle: 'Agregacija po periodu i pogonskoj jedinici.',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WasteByScrapTypeReportScreen(companyData: companyData),
                ),
              );
            },
          ),
          _ReportTile(
            icon: Icons.stacked_bar_chart,
            title: 'Otpad po proizvodu (dnevna proizvodnja)',
            subtitle: 'Dnevno: dobar komad, škart i postotak — iz operativnog praćenja (tri faze).',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WasteByProductReportScreen(companyData: companyData),
                ),
              );
            },
          ),
          _ReportTile(
            icon: Icons.trending_up,
            title: 'Trend kvaliteta po proizvodnoj liniji',
            subtitle: 'KPI i signalizacija odstupanja.',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      QualityTrendByLineReportScreen(companyData: companyData),
                ),
              );
            },
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
            subtitle: qms
                ? 'Sljedljivost: u QMS modulu unesi LOT i nalog pri kontroli.'
                : 'Traceability sirovina → gotov proizvod.',
            onTap: qms
                ? () => _openQms(
                      context,
                      ExecuteInspectionScreen(companyData: companyData),
                    )
                : () => _soon(context, 'Traceability'),
          ),
          const Divider(height: 24),
          if (!qms) ...[
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
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              qms
                  ? 'QMS modul: operativni podaci (kontrole, NCR, CAPA) dolaze preko Callable-a. '
                      'Izvještaji „Otpad i kvalitet“ čitaju agregate iz operativnog praćenja (sve tri faze) za pogon u sesiji.'
                  : 'Napomena: detaljne kalkulacije i izvoz (PDF/Excel) vezat će se na iste kolekcije kao operativni unos u tabovima praćenja. '
                      'Za QMS aktiviraj pretplatu na modul „quality“.',
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
