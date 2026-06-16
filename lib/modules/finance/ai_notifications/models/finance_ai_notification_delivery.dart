import '../../shared/finance_callable_utils.dart';

/// In-app notification delivery — Callable `finance_ai_notification_deliveries`.
class FinanceAiNotificationDelivery {
  const FinanceAiNotificationDelivery({
    required this.deliveryId,
    required this.companyId,
    required this.alertId,
    required this.deliveryStatus,
    required this.severity,
    required this.headline,
    this.plantKey = '',
    this.ruleId = '',
    this.alertDedupeKey = '',
    this.deliveryChannel = 'in_app',
    this.deliveryGeneration = 1,
    this.deliveryDedupeKey = '',
    this.isBadgeEligible = false,
    this.alertRevision = '',
    this.alertStatus = '',
    this.analysisRunId = '',
    this.triggerType = '',
    this.closedReason = '',
    this.firstDeliveredAt,
    this.lastDeliveredAt,
    this.lastReadAt,
    this.acknowledgedAt,
    this.closedAt,
  });

  final String deliveryId;
  final String companyId;
  final String alertId;
  final String plantKey;
  final String ruleId;
  final String alertDedupeKey;
  final String deliveryStatus;
  final String deliveryChannel;
  final int deliveryGeneration;
  final String deliveryDedupeKey;
  final bool isBadgeEligible;
  final String severity;
  final String headline;
  final String alertRevision;
  final String alertStatus;
  final String analysisRunId;
  final String triggerType;
  final String closedReason;
  final DateTime? firstDeliveredAt;
  final DateTime? lastDeliveredAt;
  final DateTime? lastReadAt;
  final DateTime? acknowledgedAt;
  final DateTime? closedAt;

  bool get isUnread => deliveryStatus.toLowerCase() == 'unread';
  bool get isRead => deliveryStatus.toLowerCase() == 'read';
  bool get isAcknowledged => deliveryStatus.toLowerCase() == 'acknowledged';
  bool get isSuperseded => deliveryStatus.toLowerCase() == 'superseded';
  bool get isClosed => deliveryStatus.toLowerCase() == 'closed';
  bool get isActiveDelivery =>
      isUnread || isRead || isAcknowledged;

  factory FinanceAiNotificationDelivery.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    final m = Map<String, dynamic>.from(raw);
    FinanceCallableUtils.normalizeTimestampFields(m, [
      'firstDeliveredAt',
      'lastDeliveredAt',
      'lastReadAt',
      'acknowledgedAt',
      'closedAt',
      'createdAt',
      'updatedAt',
      'badgeCountedAt',
    ]);
    return FinanceAiNotificationDelivery(
      deliveryId: (m['deliveryId'] ?? '').toString(),
      companyId: (m['companyId'] ?? '').toString(),
      alertId: (m['alertId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      ruleId: (m['ruleId'] ?? '').toString(),
      alertDedupeKey: (m['alertDedupeKey'] ?? '').toString(),
      deliveryStatus: (m['deliveryStatus'] ?? '').toString(),
      deliveryChannel: (m['deliveryChannel'] ?? 'in_app').toString(),
      deliveryGeneration: (m['deliveryGeneration'] is num)
          ? (m['deliveryGeneration'] as num).toInt()
          : int.tryParse('${m['deliveryGeneration']}') ?? 1,
      deliveryDedupeKey: (m['deliveryDedupeKey'] ?? '').toString(),
      isBadgeEligible: m['isBadgeEligible'] == true,
      severity: (m['severity'] ?? '').toString(),
      headline: (m['headline'] ?? '').toString(),
      alertRevision: (m['alertRevision'] ?? '').toString(),
      alertStatus: (m['alertStatus'] ?? '').toString(),
      analysisRunId: (m['analysisRunId'] ?? '').toString(),
      triggerType: (m['triggerType'] ?? '').toString(),
      closedReason: (m['closedReason'] ?? '').toString(),
      firstDeliveredAt: m['firstDeliveredAt'] as DateTime?,
      lastDeliveredAt: m['lastDeliveredAt'] as DateTime?,
      lastReadAt: m['lastReadAt'] as DateTime?,
      acknowledgedAt: m['acknowledgedAt'] as DateTime?,
      closedAt: m['closedAt'] as DateTime?,
    );
  }
}
