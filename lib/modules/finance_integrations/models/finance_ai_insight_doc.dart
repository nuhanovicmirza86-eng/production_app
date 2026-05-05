import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan AI zapis (`finance_ai_insights`).
class FinanceAiInsightDoc {
  const FinanceAiInsightDoc({
    required this.id,
    required this.companyId,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    this.plantKey = '',
    required this.analysisMarkdown,
    this.analysisFocus,
    this.insightKind = 'analysis',
    this.sourceTrigger = 'callable',
    this.createdAt,
    this.sourceKpiSnapshotId = '',
    this.modelId = '',
  });

  final String id;
  final String companyId;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;
  final String analysisMarkdown;
  final String? analysisFocus;
  /// `analysis` ili `watchlist` (backend Callable).
  final String insightKind;
  /// npr. `callable` ili `scheduled_nightly`
  final String sourceTrigger;
  final DateTime? createdAt;
  final String sourceKpiSnapshotId;
  final String modelId;

  static FinanceAiInsightDoc fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? created;
    final ca = data['createdAt'];
    if (ca is Timestamp) created = ca.toDate();

    return FinanceAiInsightDoc(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _asInt(data['periodYear']),
      periodMonth: _asInt(data['periodMonth']),
      plantKey: (data['plantKey'] ?? '').toString(),
      analysisMarkdown: (data['analysisMarkdown'] ?? '').toString(),
      analysisFocus: _optionalString(data['analysisFocus']),
      insightKind: _insightKind(data['insightKind']),
      sourceTrigger: _sourceTrigger(data['sourceTrigger']),
      createdAt: created,
      sourceKpiSnapshotId: (data['sourceKpiSnapshotId'] ?? '').toString(),
      modelId: (data['modelId'] ?? '').toString(),
    );
  }

  static String _sourceTrigger(dynamic v) {
    final s = (v ?? 'callable').toString().trim();
    return s.isEmpty ? 'callable' : s;
  }

  static String _insightKind(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'watchlist' ? 'watchlist' : 'analysis';
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static String? _optionalString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
