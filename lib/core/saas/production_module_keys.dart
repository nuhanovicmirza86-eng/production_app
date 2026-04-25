/// Kanonski ključevi za [companyData.enabledModules] u Production aplikaciji.
abstract final class ProductionModuleKeys {
  static const String production = 'production';

  /// SaaS modul QMS: kontrolni plan, kontrole, NCR, CAPA (IATF-friendly).
  static const String quality = 'quality';

  /// Legacy puni AI sloj (Enterprise-ekvivalent).
  static const String aiAssistant = 'ai_assistant';

  static const String aiAssistantBasic = 'ai_assistant_basic';
  static const String aiAssistantMaintenance = 'ai_assistant_maintenance';
  static const String aiAssistantProduction = 'ai_assistant_production';

  /// Add-on: Markdown AI izvještaji (uz [aiAssistant] ili [aiAssistantProduction] ili samostalno uz Production).
  static const String aiReports = 'ai_reports';

  /// Personal / obračun radnog vremena (LAN/gateway, tri sloja agregata). U [enabledModules] tenant/SaaS.
  static const String personal = 'personal';

  /// `true` ako je modul eksplicitno u listi (prazna lista = samo legacy [production] u UI logici).
  static bool hasModule(
    Map<String, dynamic> companyData,
    String moduleKey,
  ) {
    final raw = companyData['enabledModules'];
    if (raw is! List) return false;
    final normalized = moduleKey.trim().toLowerCase();
    final list = raw.map((e) => e.toString().trim().toLowerCase()).toList();
    if (list.isEmpty) {
      return normalized == ProductionModuleKeys.production;
    }
    return list.contains(normalized);
  }

  /// Production app: chat / hub ako je barem jedan od AI modula za Production kontekst.
  static bool hasAiAssistantModule(Map<String, dynamic> companyData) {
    return hasModule(companyData, ProductionModuleKeys.aiAssistant) ||
        hasModule(companyData, ProductionModuleKeys.aiAssistantBasic) ||
        hasModule(companyData, ProductionModuleKeys.aiAssistantProduction);
  }

  /// Kartica „OperonixAI Asistent“ na dashboardu: chat paketi ili add-on [aiReports] (samo izvještaj).
  static bool hasAnyProductionAiHubAccess(Map<String, dynamic> companyData) {
    return hasAiAssistantModule(companyData) ||
        hasModule(companyData, ProductionModuleKeys.aiReports);
  }

  /// Strukturirana analiza + operativni asistent (Callable: runAiAnalysis, productionTrackingAssistant).
  static bool hasAiProductionAnalyticsModule(Map<String, dynamic> companyData) {
    return hasModule(companyData, ProductionModuleKeys.aiAssistant) ||
        hasModule(companyData, ProductionModuleKeys.aiAssistantProduction);
  }

  /// AI izvještaj (Markdown) — legacy, Production paket ili add-on [aiReports].
  static bool hasAiProductionMarkdownReportModule(
    Map<String, dynamic> companyData,
  ) {
    return hasModule(companyData, ProductionModuleKeys.aiAssistant) ||
        hasModule(companyData, ProductionModuleKeys.aiAssistantProduction) ||
        hasModule(companyData, ProductionModuleKeys.aiReports);
  }
}
