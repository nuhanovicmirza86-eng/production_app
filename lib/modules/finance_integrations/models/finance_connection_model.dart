import 'package:cloud_firestore/cloud_firestore.dart';

/// Veza na ERP (`finance_connections/{connectionId}`) — tanak read model za UI.
class FinanceConnectionModel {
  final String id;
  final String companyId;
  final String connectionName;
  final String provider;
  final String status;
  final String? connectionType;
  final String? environment;
  final String? baseUrl;
  final String? syncDirection;
  final String? plantKey;
  final List<String> enabledSyncTypes;
  final Map<String, String>? masterDataPolicy;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastConnectionTestAt;
  final bool? lastConnectionTestOk;
  final int? lastConnectionTestHttpStatus;
  final String? lastConnectionTestDetail;
  final DateTime? updatedAt;

  const FinanceConnectionModel({
    required this.id,
    required this.companyId,
    required this.connectionName,
    required this.provider,
    required this.status,
    this.connectionType,
    this.environment,
    this.baseUrl,
    this.syncDirection,
    this.plantKey,
    this.enabledSyncTypes = const [],
    this.masterDataPolicy,
    this.lastSuccessfulSyncAt,
    this.lastConnectionTestAt,
    this.lastConnectionTestOk,
    this.lastConnectionTestHttpStatus,
    this.lastConnectionTestDetail,
    this.updatedAt,
  });

  factory FinanceConnectionModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceConnectionModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      connectionName: (data['connectionName'] ?? '').toString().trim(),
      provider: (data['provider'] ?? '').toString().trim(),
      status: (data['status'] ?? '').toString().trim(),
      connectionType: _optString(data['connectionType']),
      environment: _optString(data['environment']),
      baseUrl: _optString(data['baseUrl']),
      syncDirection: _optString(data['syncDirection']),
      plantKey: _optString(data['plantKey']),
      enabledSyncTypes: _stringList(data['enabledSyncTypes']),
      masterDataPolicy: _policyMap(data['masterDataPolicy']),
      lastSuccessfulSyncAt: _ts(data['lastSuccessfulSyncAt']),
      lastConnectionTestAt: _ts(data['lastConnectionTestAt']),
      lastConnectionTestOk: data['lastConnectionTestOk'] is bool
          ? data['lastConnectionTestOk'] as bool
          : null,
      lastConnectionTestHttpStatus: _iOpt(data['lastConnectionTestHttpStatus']),
      lastConnectionTestDetail: _optString(data['lastConnectionTestDetail']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  static int? _iOpt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e.toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Map<String, String>? _policyMap(dynamic v) {
    if (v is! Map) return null;
    final out = <String, String>{};
    for (final e in v.entries) {
      final k = e.key.toString().trim();
      final raw = (e.value ?? '').toString().trim().toLowerCase();
      if (k.isEmpty) continue;
      if (raw == 'erp' || raw == 'operonix') {
        out[k] = raw;
      }
    }
    return out.isEmpty ? null : out;
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String? _optString(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
