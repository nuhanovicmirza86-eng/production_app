import 'package:flutter/material.dart';

import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../ai_analysis/screens/ai_analysis_screen.dart'
    show AiAnalysisScreen, aiStructuredAnalysisVisibleForRole;
import '../../reports/screens/production_ai_report_screen.dart'
    show ProductionAiReportScreen, productionAiReportVisibleForRole;
import 'production_ai_chat_screen.dart';
import 'production_tracking_assistant_screen.dart';

/// Ulaz u AI modul: chatbot i operativni asistent odvojeni od strukturirane analize.
///
/// SaaS: [ProductionModuleKeys.hasAnyProductionAiHubAccess] (Basic / Production / legacy
/// ili add-on [ProductionModuleKeys.aiReports] za izvještaje).
class ProductionAiHubScreen extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const ProductionAiHubScreen({super.key, required this.companyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hubOn =
        ProductionModuleKeys.hasAnyProductionAiHubAccess(companyData);
    final chatOn =
        ProductionModuleKeys.hasAiAssistantModule(companyData);
    final analyticsOn =
        ProductionModuleKeys.hasAiProductionAnalyticsModule(companyData);
    final reportOn =
        ProductionModuleKeys.hasAiProductionMarkdownReportModule(companyData);

    if (!hubOn) {
      return Scaffold(
        appBar: AppBar(title: const Text(kOperonixAiAssistantTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'U pretplati ove tvrtke nema uključenog OperonixAI. '
              'Obratite se administratoru pretplate kako bi se uključio odgovarajući paket.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    void open(Widget screen) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }

    final role = companyData['role'];
    final showAnalyticsSection =
        analyticsOn && aiStructuredAnalysisVisibleForRole(role);
    final showReportTile =
        reportOn && productionAiReportVisibleForRole(role);

    return Scaffold(
      appBar: AppBar(title: const Text(kOperonixAiAssistantTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ovisno o pretplati dostupni su: slobodan razgovor, operativni asistent '
            'uz podatke o praćenju, dublja analitika u strukturiranom obliku i '
            'dugi tekstualni izvještaj za sastanke.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (chatOn) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Razgovor s asistentom'),
                subtitle: const Text(
                  'Opća pitanja o proizvodnji, učinku i srodnim temama, u skladu s ulogom.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    open(ProductionAiChatScreen(companyData: companyData)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (analyticsOn) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text(kOperonixAiOperationalAssistantTitle),
                subtitle: const Text(
                  'Kratka pitanja s uporabom povezanih podataka o nalozima, serijama i statusima.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(
                  ProductionTrackingAssistantScreen(companyData: companyData),
                ),
              ),
            ),
          ] else if (chatOn) ...[
            const SizedBox(height: 4),
            Text(
              'Operativni asistent i dublja analitika u punoj snazi zahtijevaju prošireni OperonixAI paket. Pitajte administratora pretplate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (showAnalyticsSection || showReportTile) ...[
            const SizedBox(height: 20),
            Text(
              'Analitika',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (showAnalyticsSection)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.hub_outlined),
                  title: const Text('Strukturirana analiza'),
                  subtitle: const Text(
                    'Učinak, signali s linija i tijek proizvodnje (strukturirani ispis).',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      open(AiAnalysisScreen(companyData: companyData)),
                ),
              ),
            if (showReportTile) ...[
              if (showAnalyticsSection) const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('AI izvještaj — proizvodnja'),
                  subtitle: const Text(
                    'Dugi formatirani tekst s odabirom perioda: nalozi, praćenje, sažetak.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    ProductionAiReportScreen(companyData: companyData),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
