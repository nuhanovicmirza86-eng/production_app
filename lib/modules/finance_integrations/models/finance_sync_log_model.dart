import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan red iz `finance_sync_logs` (bez punog payloada).
class FinanceSyncLogModel {
  const FinanceSyncLogModel({
    required this.id,
    required this.companyId,
    this.syncJobId = '',
    this.connectionId = '',
    this.message = '',
    this.responseCode,
    this.requestPayloadHash,
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String syncJobId;
  final String connectionId;
  final String message;
  final String? responseCode;
  final String? requestPayloadHash;
  final String createdBy;
  final DateTime? createdAt;

  factory FinanceSyncLogModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceSyncLogModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      syncJobId: (data['syncJobId'] ?? '').toString().trim(),
      connectionId: (data['connectionId'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim(),
      responseCode: _opt(data['responseCode']),
      requestPayloadHash: _opt(data['requestPayloadHash']),
      createdBy: (data['createdBy'] ?? '').toString().trim(),
      createdAt: _ts(data['createdAt']),
    );
  }

  static String? _opt(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
