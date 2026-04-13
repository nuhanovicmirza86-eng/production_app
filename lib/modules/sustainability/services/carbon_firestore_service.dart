import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/carbon_models.dart';
import 'carbon_defaults.dart';

class CarbonFirestoreService {
  CarbonFirestoreService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _carbonWrite(Map<String, dynamic> payload) async {
    final res = await _functions
        .httpsCallable('carbonFootprintWrite')
        .call<Map<String, dynamic>>(payload);
    return res.data;
  }

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

  /// Samostalni zapis (npr. izvoz) — Callable + Admin SDK.
  Future<void> logReportEvent({
    required String companyId,
    required int reportingYear,
    required String userId,
    required String action,
    String detail = '',
  }) async {
    final data = await _carbonWrite({
      'op': 'logReportEvent',
      'companyId': companyId,
      'reportingYear': reportingYear,
      'action': action,
      'detail': detail,
    });
    if (data['success'] != true) {
      throw Exception('Audit zapis nije uspio.');
    }
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
    final data = await _carbonWrite({
      'op': 'saveSettings',
      'companyId': setup.companyId,
      'setup': setup.toMap(),
    });
    if (data['success'] != true) {
      throw Exception('Spremanje postavki nije uspjelo.');
    }
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
    final data = await _carbonWrite({
      'op': 'saveQuotas',
      'companyId': quotas.companyId,
      'quotas': quotas.toMap(),
    });
    if (data['success'] != true) {
      throw Exception('Spremanje kvota nije uspjelo.');
    }
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
    final linePayload = <String, dynamic>{
      ...line.toMap(),
      'id': line.id,
    };
    final data = await _carbonWrite({
      'op': 'upsertActivity',
      'companyId': line.companyId,
      'line': linePayload,
    });
    if (data['success'] != true) {
      throw Exception('Spremanje aktivnosti nije uspjelo.');
    }
  }

  Future<void> deleteActivity(String activityDocId) async {
    final snap = await _activitiesCol().doc(activityDocId).get();
    if (!snap.exists) return;
    final cid = (snap.data()?['companyId'] ?? '').toString().trim();
    if (cid.isEmpty) {
      throw Exception('Aktivnost nema companyId.');
    }
    final data = await _carbonWrite({
      'op': 'deleteActivity',
      'companyId': cid,
      'activityDocId': activityDocId,
    });
    if (data['success'] != true) {
      throw Exception('Brisanje aktivnosti nije uspjelo.');
    }
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
    final data = await _carbonWrite({
      'op': 'saveEmissionFactorOverride',
      'companyId': companyId,
      'reportingYear': reportingYear,
      'factor': factor.toMap(),
    });
    if (data['success'] != true) {
      throw Exception('Spremanje faktora nije uspjelo.');
    }
  }

  Future<void> deleteFactorOverride(String companyId, String factorKey) async {
    final data = await _carbonWrite({
      'op': 'deleteEmissionFactorOverride',
      'companyId': companyId,
      'factorKey': factorKey,
    });
    if (data['success'] != true) {
      throw Exception('Brisanje faktora nije uspjelo.');
    }
  }
}
