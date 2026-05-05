import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan red iz `finance_sync_jobs` (read-only UI).
class FinanceSyncJobModel {
  const FinanceSyncJobModel({
    required this.id,
    required this.companyId,
    required this.status,
    required this.syncType,
    this.provider = '',
    this.connectionId = '',
    this.direction = '',
    this.sourceModule = '',
    this.lastErrorMessage,
    this.lastErrorCode,
    this.attemptCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String status;
  final String syncType;
  final String provider;
  final String connectionId;
  final String direction;
  final String sourceModule;
  final String? lastErrorMessage;
  final String? lastErrorCode;
  final int attemptCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FinanceSyncJobModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceSyncJobModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      status: (data['status'] ?? '').toString().trim(),
      syncType: (data['syncType'] ?? '').toString().trim(),
      provider: (data['provider'] ?? '').toString().trim(),
      connectionId: (data['connectionId'] ?? '').toString().trim(),
      direction: (data['direction'] ?? '').toString().trim(),
      sourceModule: (data['sourceModule'] ?? '').toString().trim(),
      lastErrorMessage: _opt(data['lastErrorMessage']),
      lastErrorCode: _opt(data['lastErrorCode']),
      attemptCount: _i(data['attemptCount']),
      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
