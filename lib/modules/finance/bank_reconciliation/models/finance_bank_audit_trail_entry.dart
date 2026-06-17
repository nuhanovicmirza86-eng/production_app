import '../../shared/finance_callable_utils.dart';

class FinanceBankAuditTrailEntry {
  const FinanceBankAuditTrailEntry({
    required this.auditLogId,
    required this.companyId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actionType,
    this.plantKey,
    this.performedByUid,
    this.performedByEmail,
    this.performedByRole,
    this.performedAt,
    this.source,
    this.reason,
    this.requestId,
    this.correlationId,
    this.bankStatementTransactionId,
    this.relatedEntityIds = const [],
    this.relatedEntityDisplays = const [],
    this.entityDisplayLabel,
    this.before,
    this.after,
    this.beforeDisplay,
    this.afterDisplay,
  });

  final String auditLogId;
  final String companyId;
  final String entityType;
  final String entityId;
  final String action;
  final String actionType;
  final String? plantKey;
  final String? performedByUid;
  final String? performedByEmail;
  final String? performedByRole;
  final DateTime? performedAt;
  final String? source;
  final String? reason;
  final String? requestId;
  final String? correlationId;
  final String? bankStatementTransactionId;
  final List<String> relatedEntityIds;
  final List<String> relatedEntityDisplays;
  final String? entityDisplayLabel;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final Map<String, dynamic>? beforeDisplay;
  final Map<String, dynamic>? afterDisplay;

  factory FinanceBankAuditTrailEntry.fromCallableMap(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    FinanceCallableUtils.normalizeTimestampFields(map, ['performedAt']);
    final related = map['relatedEntityIds'];
    final relatedIds = <String>[];
    if (related is List) {
      for (final item in related) {
        final s = (item ?? '').toString().trim();
        if (s.isNotEmpty) relatedIds.add(s);
      }
    }
    final relatedDisplays = map['relatedEntityDisplays'];
    final relatedLabels = <String>[];
    if (relatedDisplays is List) {
      for (final item in relatedDisplays) {
        final s = (item ?? '').toString().trim();
        if (s.isNotEmpty) relatedLabels.add(s);
      }
    }
    Map<String, dynamic>? beforeMap;
    Map<String, dynamic>? afterMap;
    Map<String, dynamic>? beforeDisplayMap;
    Map<String, dynamic>? afterDisplayMap;
    if (map['before'] is Map) {
      beforeMap = Map<String, dynamic>.from(map['before'] as Map);
    }
    if (map['after'] is Map) {
      afterMap = Map<String, dynamic>.from(map['after'] as Map);
    }
    if (map['beforeDisplay'] is Map) {
      beforeDisplayMap = Map<String, dynamic>.from(map['beforeDisplay'] as Map);
    }
    if (map['afterDisplay'] is Map) {
      afterDisplayMap = Map<String, dynamic>.from(map['afterDisplay'] as Map);
    }
    return FinanceBankAuditTrailEntry(
      auditLogId: (map['auditLogId'] ?? '').toString(),
      companyId: (map['companyId'] ?? '').toString(),
      entityType: (map['entityType'] ?? '').toString(),
      entityId: (map['entityId'] ?? '').toString(),
      action: (map['action'] ?? '').toString(),
      actionType: (map['actionType'] ?? map['action'] ?? '').toString(),
      plantKey: _opt(map['plantKey']),
      performedByUid: _opt(map['performedByUid'] ?? map['performedBy']),
      performedByEmail: _opt(map['performedByEmail']),
      performedByRole: _opt(map['performedByRole']),
      performedAt: FinanceCallableUtils.parseTimestamp(map['performedAt']),
      source: _opt(map['source']),
      reason: _opt(map['reason']),
      requestId: _opt(map['requestId']),
      correlationId: _opt(map['correlationId']),
      bankStatementTransactionId: _opt(map['bankStatementTransactionId']),
      relatedEntityIds: relatedIds,
      relatedEntityDisplays: relatedLabels,
      entityDisplayLabel: _opt(map['entityDisplayLabel']),
      before: beforeMap,
      after: afterMap,
      beforeDisplay: beforeDisplayMap,
      afterDisplay: afterDisplayMap,
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
