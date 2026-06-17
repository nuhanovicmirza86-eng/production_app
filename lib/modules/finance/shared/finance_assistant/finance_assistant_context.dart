/// Siguran kontekst za Finance asistenta — bez punih financijskih dokumenata.
class FinanceAssistantContext {
  const FinanceAssistantContext({
    required this.screenKey,
    this.moduleLabelKey = 'finance_assistant_module',
    this.tabLabelKey,
    this.role,
    this.entityStatus,
    this.availableActions = const [],
    this.extraFacts = const {},
    this.prefilledQuestionKey,
  });

  final String screenKey;
  final String moduleLabelKey;
  final String? tabLabelKey;
  final String? role;
  final String? entityStatus;
  final List<String> availableActions;
  final Map<String, String> extraFacts;
  final String? prefilledQuestionKey;

  FinanceAssistantContext copyWith({
    String? screenKey,
    String? moduleLabelKey,
    String? tabLabelKey,
    String? role,
    String? entityStatus,
    List<String>? availableActions,
    Map<String, String>? extraFacts,
    String? prefilledQuestionKey,
  }) {
    return FinanceAssistantContext(
      screenKey: screenKey ?? this.screenKey,
      moduleLabelKey: moduleLabelKey ?? this.moduleLabelKey,
      tabLabelKey: tabLabelKey ?? this.tabLabelKey,
      role: role ?? this.role,
      entityStatus: entityStatus ?? this.entityStatus,
      availableActions: availableActions ?? this.availableActions,
      extraFacts: extraFacts ?? this.extraFacts,
      prefilledQuestionKey: prefilledQuestionKey ?? this.prefilledQuestionKey,
    );
  }
}

/// Kanonski ključevi ekrana (P4 bank reconciliation + proširenje kasnije).
abstract final class FinanceAssistantScreens {
  static const bankStatementsList = 'bank_statements_list';
  static const bankStatementDetail = 'bank_statement_detail';
  static const bankMatchConfirm = 'bank_match_confirm';
  static const bankMatchConfirmationDetail = 'bank_match_confirmation_detail';
}
