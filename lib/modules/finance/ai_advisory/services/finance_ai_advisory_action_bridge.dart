import '../services/finance_ai_outcome_service.dart';

/// Aktivna advisory navigacija — omogućava `action_completed` samo kad
/// ciljni workflow vrati valjan `actionAuditId`.
class FinanceAiAdvisoryActionBridge {
  FinanceAiAdvisoryActionBridge._();

  static FinanceAiAdvisoryNavigationSession? _active;

  static FinanceAiAdvisoryNavigationSession? get active => _active;

  static void beginNavigation(FinanceAiAdvisoryNavigationSession session) {
    _active = session;
  }

  static void clear() {
    _active = null;
  }

  /// Poziva se iz uspješnog P1–P3 Callabla (npr. alokacija plaćanja).
  static Future<void> tryCompleteFromWorkflow({
    required FinanceAiOutcomeService outcomeService,
    required String targetEntityType,
    required String targetEntityId,
    required String actionAuditId,
  }) async {
    final session = _active;
    final auditId = actionAuditId.trim();
    if (session == null || auditId.isEmpty) return;

    await outcomeService.recordInteraction(
      companyId: session.companyId,
      recommendationId: session.recommendationId,
      interactionType: 'action_completed',
      requestId: FinanceAiInteractionRequestIds.actionCompleted(
        session.alertId,
        session.recommendationId,
      ),
      clientSurface: 'alert_detail',
      targetEntityType: targetEntityType,
      targetEntityId: targetEntityId,
      actionAuditId: auditId,
    );
    clear();
  }
}

class FinanceAiAdvisoryNavigationSession {
  const FinanceAiAdvisoryNavigationSession({
    required this.companyId,
    required this.alertId,
    required this.recommendationId,
    required this.actionType,
  });

  final String companyId;
  final String alertId;
  final String recommendationId;
  final String actionType;
}
