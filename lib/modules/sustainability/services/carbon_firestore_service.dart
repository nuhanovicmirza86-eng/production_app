import 'package:cloud_firestore/cloud_firestore.dart';

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
    await _settingsRef(setup.companyId, setup.reportingYear).set({
      ...setup.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
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
    await _quotasRef(quotas.companyId, quotas.reportingYear).set({
      ...quotas.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
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
    await ref.set({
      ...line.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
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
  }) async {
    final id = factorDocId(companyId, factor.factorKey);
    await _db.collection('carbon_emission_factors').doc(id).set({
      'companyId': companyId,
      ...factor.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    }, SetOptions(merge: true));
  }

  Future<void> deleteFactorOverride(String companyId, String factorKey) async {
    await _db
        .collection('carbon_emission_factors')
        .doc(factorDocId(companyId, factorKey))
        .delete();
  }
}
