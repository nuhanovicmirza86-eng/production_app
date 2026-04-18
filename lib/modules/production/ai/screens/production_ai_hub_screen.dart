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
              'Nijedan AI modul nije uključen u pretplatu ove kompanije. '
              'Potreban je barem jedan od: ai_assistant_basic, ai_assistant_production, '
              'ai_assistant (legacy) ili add-on ai_reports (uz proizvodni modul).',
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
            'Različiti AI paketi uključuju različite mogućnosti: opći chat, '
            'operativni asistent nad podacima, strukturirana analiza (JSON) i Markdown izvještaji.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (chatOn) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Chatbot'),
                subtitle: const Text(
                  'Slobodan razgovor u MES/OEE kontekstu (Callable aiChat).',
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
                  'Pitanja uz kontekst praćenja proizvodnje iz baze.',
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
              'Operativni asistent i dubinska analiza zahtijevaju paket '
              '„AI Assistant Production” ili legacy „ai_assistant”.',
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
                  subtitle: const Text('SCADA / OEE / tok — JSON payload.'),
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
                  subtitle: const Text('Period, praćenje i nalozi (Markdown).'),
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
