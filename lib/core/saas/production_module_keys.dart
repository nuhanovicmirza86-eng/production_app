/// Kanonski ključevi za SaaS module na dokumentu kompanije u Production aplikaciji.
/// [hasModule] gleda [enabledModules], [addonModules] i [planEnabledModules].
abstract final class ProductionModuleKeys {
  static const String production = 'production';

  /// SaaS modul QMS: kontrolni plan, kontrole, NCR, CAPA (IATF-friendly).
  static const String quality = 'quality';

  /// NPI / Stage-Gate / portfolio (Development & Project Governance).
  static const String development = 'development';

  /// Add-on: AI uvidi unutar modula development (Callable/UI; ne odobrava Gate).
  static const String developmentAi = 'development_ai';

  /// Add-on: prošireni Stage-Gate tok (Callable; odvojeno od core entitlementsa).
  static const String developmentStageGate = 'development_stage_gate';

  /// Legacy puni AI sloj (Enterprise-ekvivalent).
  static const String aiAssistant = 'ai_assistant';

  static const String aiAssistantBasic = 'ai_assistant_basic';
  static const String aiAssistantMaintenance = 'ai_assistant_maintenance';
  static const String aiAssistantProduction = 'ai_assistant_production';

  /// Add-on: Markdown AI izvještaji (uz [aiAssistant] ili [aiAssistantProduction] ili samostalno uz Production).
  static const String aiReports = 'ai_reports';

  /// Personal / obračun radnog vremena (LAN/gateway, tri sloja agregata). U [enabledModules] tenant/SaaS.
  static const String personal = 'personal';

  /// Normalizirane liste modula (isti smisao kao tanki rules: generic modul u entitlementu).
  static Set<String> _moduleKeySet(dynamic raw) {
    if (raw is! List) return {};
    return raw
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  /// `true` ako je modul u [enabledModules], [addonModules] ili [planEnabledModules]
  /// (usklađeno s Firestore `companyDocHasGenericModule` + plan u Callableima gdje postoji).
  ///
  /// Kada su sve tri liste prazne/nepostojeće: legacy ponašanje — smatra se samo [production].
  static bool hasModule(
    Map<String, dynamic> companyData,
    String moduleKey,
  ) {
    final normalized = moduleKey.trim().toLowerCase();
    final enabled = _moduleKeySet(companyData['enabledModules']);
    final addons = _moduleKeySet(companyData['addonModules']);
    final plan = _moduleKeySet(companyData['planEnabledModules']);

    if (enabled.isEmpty && addons.isEmpty && plan.isEmpty) {
      return normalized == ProductionModuleKeys.production;
    }
    return enabled.contains(normalized) ||
        addons.contains(normalized) ||
        plan.contains(normalized);
  }

  /// Osnovni modul [development] + opcijski SaaS add-on u istim entitlement listama.
  static bool hasDevelopmentCapability(
    Map<String, dynamic> companyData,
    String capabilityKey,
  ) {
    if (!hasModule(companyData, development)) return false;
    final k = capabilityKey.trim().toLowerCase();
    if (k == development) return true;
    return hasModule(companyData, k);
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
