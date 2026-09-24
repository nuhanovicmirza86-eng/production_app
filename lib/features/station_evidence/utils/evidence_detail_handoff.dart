import '../models/profile_driven_evidence_session.dart';

/// M1-I15-D-HOTFIX-22 — poslovna predaja na Detalj evidencije.
/// Ista sekcija za sve kontrolne evidencije. Bez e-maila, UID-a, EN naziva.
class EvidenceDetailHandoff {
  const EvidenceDetailHandoff._();

  static const sectionTitle = 'Predaja i verifikacija';

  static const performedByLabel = 'Izvršio';
  static const performedAtLabel = 'Vrijeme spremanja';
  static const verifiedByLabel = 'Verifikovao';
  static const verifiedAtLabel = 'Vrijeme verifikacije';
  static const statusLabel = 'Status';

  static const _saveActions = {'evidence_session_updated'};
  static const _verifyActions = {
    'evidence_session_verified',
    'evidence_session_finished',
  };

  static const _performedBySnapshotKeys = [
    'performedByNameSnapshot',
    'packagingOperatorNameSnapshot',
    'productionOperatorNameSnapshot',
  ];

  static const _verifiedBySnapshotKeys = [
    'verifiedByNameSnapshot',
    'controllerNameSnapshot',
    'inspectorNameSnapshot',
  ];

  static ProductionEvidenceAuditItem? firstAuditWithAction(
    Iterable<ProductionEvidenceAuditItem> items,
    Set<String> actions,
  ) {
    for (final item in items) {
      if (actions.contains(item.action)) return item;
    }
    return null;
  }

  static String _firstSnapshot(
    Map<String, dynamic> fieldValues,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = (fieldValues[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String performedByName({
    required Map<String, dynamic> fieldValues,
    required List<ProductionEvidenceAuditItem> auditItems,
  }) {
    final fromAudit =
        (firstAuditWithAction(auditItems, _saveActions)?.performedByName ?? '')
            .trim();
    if (fromAudit.isNotEmpty) return fromAudit;
    return _firstSnapshot(fieldValues, _performedBySnapshotKeys);
  }

  static String verifiedByName({
    required Map<String, dynamic> fieldValues,
    required List<ProductionEvidenceAuditItem> auditItems,
  }) {
    final fromAudit =
        (firstAuditWithAction(auditItems, _verifyActions)?.performedByName ?? '')
            .trim();
    if (fromAudit.isNotEmpty) return fromAudit;
    return _firstSnapshot(fieldValues, _verifiedBySnapshotKeys);
  }

  static DateTime? performedAt({
    required List<ProductionEvidenceAuditItem> auditItems,
  }) {
    return firstAuditWithAction(auditItems, _saveActions)?.performedAt;
  }

  static DateTime? verifiedAt({
    required ProfileDrivenEvidenceSessionDetail session,
    required List<ProductionEvidenceAuditItem> auditItems,
  }) {
    return firstAuditWithAction(auditItems, _verifyActions)?.performedAt ??
        session.endedAt;
  }

  static String statusLabelFor(ProfileDrivenEvidenceSessionDetail session) {
    return session.status.trim().toLowerCase() == 'closed'
        ? 'Završeno'
        : 'U toku';
  }

  static bool looksLikeInternalEvidenceText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    const banned = [
      'Operator audit',
      'operatorEmail',
      'createdByEmail',
      'createdByUid',
      'plantKey',
      'companyId',
      'prijavljenog korisnika',
    ];
    for (final item in banned) {
      if (t.contains(item)) return true;
    }
    if (RegExp(r'@').hasMatch(t) && t.contains('.')) return true;
    return false;
  }
}
