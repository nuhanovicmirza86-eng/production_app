import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/carbon_models.dart';
import 'carbon_defaults.dart';

class CarbonFirestoreService {
  CarbonFirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static String periodDocId(String companyId, int reportingYear) =>
      '${companyId}_$reportingYear';

  static String factorDocId(String companyId, String factorKey) =>
      '${companyId}__$factorKey';

  DocumentReference<Map<String, dynamic>> _settingsRef(
    String companyId,
    int year,
  ) => _db.collection('carbon_settings').doc(periodDocId(companyId, year));

  DocumentReference<Map<String, dynamic>> _quotasRef(
    String companyId,
    int year,
  ) => _db.collection('carbon_quotas').doc(periodDocId(companyId, year));

  CollectionReference<Map<String, dynamic>> _activitiesCol() =>
      _db.collection('carbon_activities');

  CollectionReference<Map<String, dynamic>> _auditCol() =>
      _db.collection('carbon_audit_log');

  bool _canWriteAuditEntry(String userId) {
    final u = userId.trim();
    if (u.isEmpty) return false;
    final me = FirebaseAuth.instance.currentUser?.uid ?? '';
    return me.isNotEmpty && me == u;
  }

  String _truncateDetail(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  void _addAuditToBatch(
    WriteBatch batch, {
    required String companyId,
    required int reportingYear,
    required String userId,
    required String action,
    String detail = '',
  }) {
    if (!_canWriteAuditEntry(userId)) return;
    batch.set(_auditCol().doc(), {
      'companyId': companyId,
      'reportingYear': reportingYear,
      'action': action,
      'userId': userId.trim(),
      'detail': _truncateDetail(detail, 500),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Samostalni zapis (npr. izvoz) — ne koristi batch s drugim dokumentom.
  Future<void> logReportEvent({
    required String companyId,
    required int reportingYear,
    required String userId,
    required String action,
    String detail = '',
  }) async {
    if (!_canWriteAuditEntry(userId)) return;
    await _auditCol().doc().set({
      'companyId': companyId,
      'reportingYear': reportingYear,
      'action': action,
      'userId': userId.trim(),
      'detail': _truncateDetail(detail, 500),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CarbonAuditLogEntry>> watchAuditLog({
    required String companyId,
    required int reportingYear,
    int limit = 200,
  }) {
    return _auditCol()
        .where('companyId', isEqualTo: companyId)
        .where('reportingYear', isEqualTo: reportingYear)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CarbonAuditLogEntry.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  /// Zadnji `updatedAt` / `updatedBy` na glavnim dokumentima perioda (prije audit kolekcije).
  Future<
      ({
        DateTime? settingsUpdatedAt,
        String settingsUpdatedBy,
        DateTime? quotasUpdatedAt,
        String quotasUpdatedBy,
      })> loadPeriodDocumentUpdateHints({
    required String companyId,
    required int reportingYear,
  }) async {
    final sSnap = await _settingsRef(companyId, reportingYear).get();
    final qSnap = await _quotasRef(companyId, reportingYear).get();

    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    String by(Map<String, dynamic>? m, String key) =>
        (m == null ? '' : (m[key] ?? '').toString()).trim();

    final sd = sSnap.data();
    final qd = qSnap.data();

    return (
      settingsUpdatedAt: sd == null ? null : ts(sd['updatedAt']),
      settingsUpdatedBy: by(sd, 'updatedBy'),
      quotasUpdatedAt: qd == null ? null : ts(qd['updatedAt']),
      quotasUpdatedBy: by(qd, 'updatedBy'),
    );
  }

  Future<CarbonCompanySetup?> loadSettings({
    required String companyId,
    required int reportingYear,
    required String fallbackCompanyName,
  }) async {
    final snap = await _settingsRef(companyId, reportingYear).get();
    if (!snap.exists || snap.data() == null) {
      return CarbonCompanySetup(
        companyId: companyId,
        reportingYear: reportingYear,
        plantKey: '',
        companyName: fallbackCompanyName,
      );
    }
    final m = Map<String, dynamic>.from(snap.data()!);
    m['companyId'] = companyId;
    m['reportingYear'] = reportingYear;
    if (m['plantKey'] == null || (m['plantKey'] is String && (m['plantKey'] as String).trim().isEmpty)) {
      m['plantKey'] = '';
    }
    return CarbonCompanySetup.fromMap(m);
  }

  Future<void> saveSettings({
    required CarbonCompanySetup setup,
    required String userId,
  }) async {
    final batch = _db.batch();
    final ref = _settingsRef(setup.companyId, setup.reportingYear);
    batch.set(ref, {
      ...setup.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
    _addAuditToBatch(
      batch,
      companyId: setup.companyId,
      reportingYear: setup.reportingYear,
      userId: userId,
      action: 'settings_saved',
    );
    await batch.commit();
  }

  Future<CarbonQuotaSettings> loadQuotas({
    required String companyId,
    required int reportingYear,
  }) async {
    final snap = await _quotasRef(companyId, reportingYear).get();
    if (!snap.exists || snap.data() == null) {
      return CarbonQuotaSettings(
        companyId: companyId,
        reportingYear: reportingYear,
      );
    }
    final m = Map<String, dynamic>.from(snap.data()!);
    m['companyId'] = companyId;
    m['reportingYear'] = reportingYear;
    return CarbonQuotaSettings.fromMap(m);
  }

  Future<void> saveQuotas({
    required CarbonQuotaSettings quotas,
    required String userId,
  }) async {
    final batch = _db.batch();
    final ref = _quotasRef(quotas.companyId, quotas.reportingYear);
    batch.set(ref, {
      ...quotas.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
    _addAuditToBatch(
      batch,
      companyId: quotas.companyId,
      reportingYear: quotas.reportingYear,
      userId: userId,
      action: 'quotas_saved',
    );
    await batch.commit();
  }

  Stream<List<CarbonActivityLine>> watchActivities({
    required String companyId,
    required int reportingYear,
  }) {
    return _activitiesCol()
        .where('companyId', isEqualTo: companyId)
        .where('reportingYear', isEqualTo: reportingYear)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => CarbonActivityLine.fromDoc(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.rowId.compareTo(b.rowId)),
        );
  }

  Future<void> upsertActivity({
    required CarbonActivityLine line,
    required String userId,
  }) async {
    final ref = line.id.isEmpty
        ? _activitiesCol().doc()
        : _activitiesCol().doc(line.id);
    final batch = _db.batch();
    batch.set(ref, {
      ...line.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
    final isNew = line.id.isEmpty;
    _addAuditToBatch(
      batch,
      companyId: line.companyId,
      reportingYear: line.reportingYear,
      userId: userId,
      action: isNew ? 'activity_created' : 'activity_updated',
      detail: '${line.rowId}: ${line.description}',
    );
    await batch.commit();
  }

  Future<void> deleteActivity(String activityDocId) async {
    await _activitiesCol().doc(activityDocId).delete();
  }

  /// Spaja ugrađene defaulte s onim iz Firestore (Firestore pobjeđuje).
  Future<Map<String, CarbonEmissionFactor>> loadEffectiveFactors(
    String companyId,
  ) async {
    final merged = CarbonDefaults.defaultFactorMap();
    final snap = await _db
        .collection('carbon_emission_factors')
        .where('companyId', isEqualTo: companyId)
        .get();
    for (final d in snap.docs) {
      final m = d.data();
      final key = (m['factorKey'] ?? '').toString();
      if (key.isEmpty) continue;
      merged[key] = CarbonEmissionFactor.fromMap(m);
    }
    return merged;
  }

  Future<List<CarbonEmissionFactor>> listStoredFactors(String companyId) async {
    final snap = await _db
        .collection('carbon_emission_factors')
        .where('companyId', isEqualTo: companyId)
        .get();
    return snap.docs.map((d) => CarbonEmissionFactor.fromMap(d.data())).toList();
  }

  Future<void> saveFactorOverride({
    required String companyId,
    required CarbonEmissionFactor factor,
    required String userId,
    required int reportingYear,
  }) async {
    final id = factorDocId(companyId, factor.factorKey);
    final batch = _db.batch();
    final docRef = _db.collection('carbon_emission_factors').doc(id);
    batch.set(docRef, {
      'companyId': companyId,
      ...factor.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
    _addAuditToBatch(
      batch,
      companyId: companyId,
      reportingYear: reportingYear,
      userId: userId,
      action: 'factor_override_saved',
      detail: factor.factorKey,
    );
    await batch.commit();
  }

  Future<void> deleteFactorOverride(String companyId, String factorKey) async {
    await _db
        .collection('carbon_emission_factors')
        .doc(factorDocId(companyId, factorKey))
        .delete();
  }
}
