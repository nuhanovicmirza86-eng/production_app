class FinanceAiNotificationBadgeSummary {
  const FinanceAiNotificationBadgeSummary({
    required this.unreadCount,
    required this.companyId,
    this.plantKey,
  });

  final int unreadCount;
  final String companyId;
  final String? plantKey;

  factory FinanceAiNotificationBadgeSummary.fromMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    final pk = m['plantKey'];
    return FinanceAiNotificationBadgeSummary(
      unreadCount: (m['unreadCount'] is num)
          ? (m['unreadCount'] as num).toInt()
          : int.tryParse('${m['unreadCount']}') ?? 0,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: pk == null ? null : pk.toString().trim(),
    );
  }
}
