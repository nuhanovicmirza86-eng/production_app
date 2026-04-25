import 'package:cloud_functions/cloud_functions.dart';

import '../models/internal_audit_models.dart';

/// Interni audit (IATF) — Callable-only.
class InternalAuditCallableService {
  InternalAuditCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<InternalAuditListRow>> listInternalAudits({
    required String companyId,
    int limit = 80,
    /// `open`, `closed` ili prazno (svi).
    String? statusFilter,
  }) async {
    final callable = _functions.httpsCallable('listInternalAudits');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'limit': limit,
    };
    final sf = statusFilter?.trim();
    if (sf != null && sf.isNotEmpty) {
      payload['statusFilter'] = sf;
    }
    final res = await callable.call(payload);
    final data = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    final raw = data['items'];
    if (raw is! List) return const [];
    return raw
        .map(
          (e) => InternalAuditListRow.fromMap(
            Map<String, dynamic>.from((e as Map?) ?? const {}),
          ),
        )
        .toList();
  }

  Future<InternalAuditBundle> getInternalAuditBundle({
    required String companyId,
    required String auditId,
  }) async {
    final callable = _functions.httpsCallable('getInternalAuditBundle');
    final res = await callable.call({
      'companyId': companyId,
      'auditId': auditId,
    });
    final data = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    final auditMap = Map<String, dynamic>.from(
      (data['audit'] as Map?) ?? const <String, dynamic>{},
    );
    final fa = data['findings'];
    final findings = <InternalAuditFinding>[];
    if (fa is List) {
      for (final x in fa) {
        findings.add(
          InternalAuditFinding.fromMap(
            Map<String, dynamic>.from((x as Map?) ?? const {}),
          ),
        );
      }
    }
    return InternalAuditBundle(
      audit: InternalAuditHeader.fromMap(auditMap),
      findings: findings,
    );
  }

  Future<({String auditId, String auditCode})> createInternalAudit({
    required String companyId,
    String? plantKey,
    required String auditType,
    required String title,
    required String auditorName,
    required String auditDate,
    required String department,
    String notes = '',
  }) async {
    final callable = _functions.httpsCallable('createInternalAudit');
    final res = await callable.call({
      'companyId': companyId,
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      'auditType': auditType,
      'title': title,
      'auditorName': auditorName,
      'auditDate': auditDate,
      'department': department,
      'notes': notes,
    });
    final data = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    return (
      auditId: (data['auditId'] ?? '').toString(),
      auditCode: (data['auditCode'] ?? '').toString(),
    );
  }

  Future<({String findingId, String findingCode})> addInternalAuditFinding({
    required String companyId,
    required String auditId,
    required String findingType,
    required String description,
    String? linkedCapaId,
  }) async {
    final callable = _functions.httpsCallable('addInternalAuditFinding');
    final res = await callable.call({
      'companyId': companyId,
      'auditId': auditId,
      'findingType': findingType,
      'description': description,
      if (linkedCapaId != null && linkedCapaId.trim().isNotEmpty)
        'linkedCapaId': linkedCapaId.trim(),
    });
    final data = Map<String, dynamic>.from(
      (res.data as Map?) ?? const <String, dynamic>{},
    );
    return (
      findingId: (data['findingId'] ?? '').toString(),
      findingCode: (data['findingCode'] ?? '').toString(),
    );
  }

  /// `open` — ponovno otvori; `closed` — zatvori.
  Future<void> updateInternalAuditStatus({
    required String companyId,
    required String auditId,
    required String status,
  }) async {
    final callable = _functions.httpsCallable('updateInternalAuditStatus');
    await callable.call({
      'companyId': companyId,
      'auditId': auditId,
      'status': status,
    });
  }
}
