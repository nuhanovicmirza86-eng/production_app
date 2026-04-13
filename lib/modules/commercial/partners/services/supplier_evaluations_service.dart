import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SupplierEvaluationModel {
  final String id;
  final String companyId;
  final String supplierId;
  final String supplierCode;
  final String supplierName;
  final String periodKey; // npr. 2026-Q2

  final double qualityRating;
  final double deliveryRating;
  final double responseRating;
  final double complianceRating;

  final double overallScore;
  final String riskLevel; // low, medium, high
  final String approvalStatus; // approved, conditional, disqualified

  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  const SupplierEvaluationModel({
    required this.id,
    required this.companyId,
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    required this.periodKey,
    required this.qualityRating,
    required this.deliveryRating,
    required this.responseRating,
    required this.complianceRating,
    required this.overallScore,
    required this.riskLevel,
    required this.approvalStatus,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  factory SupplierEvaluationModel.fromMap(String id, Map<String, dynamic> map) {
    return SupplierEvaluationModel(
      id: id,
      companyId: _evalS(map['companyId']),
      supplierId: _evalS(map['supplierId']),
      supplierCode: _evalS(map['supplierCode']),
      supplierName: _evalS(map['supplierName']),
      periodKey: _evalS(map['periodKey']),
      qualityRating: _evalD(map['qualityRating']),
      deliveryRating: _evalD(map['deliveryRating']),
      responseRating: _evalD(map['responseRating']),
      complianceRating: _evalD(map['complianceRating']),
      overallScore: _evalD(map['overallScore']),
      riskLevel: _evalS(map['riskLevel']),
      approvalStatus: _evalS(map['approvalStatus']),
      notes: _evalNullable(map['notes']),
      createdAt: _evalToDate(map['createdAt']),
      createdBy: _evalNullable(map['createdBy']),
    );
  }
}

class SupplierEvaluationsService {
  SupplierEvaluationsService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _evaluations =>
      _firestore.collection('supplier_evaluations');

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static double calculateOverall({
    required double qualityRating,
    required double deliveryRating,
    required double responseRating,
    required double complianceRating,
  }) {
    final raw = (qualityRating * 0.40) +
        (deliveryRating * 0.30) +
        (responseRating * 0.20) +
        (complianceRating * 0.10);
    return double.parse(raw.toStringAsFixed(2));
  }

  static String riskLevelFromScore(double score) {
    if (score >= 85) return 'low';
    if (score >= 65) return 'medium';
    return 'high';
  }

  static String approvalStatusFromScore(double score) {
    if (score >= 80) return 'approved';
    if (score >= 60) return 'conditional';
    return 'disqualified';
  }

  Future<List<SupplierEvaluationModel>> listForSupplier({
    required String companyId,
    required String supplierId,
    int limit = 30,
  }) async {
    final cid = companyId.trim();
    final sid = supplierId.trim();
    if (cid.isEmpty || sid.isEmpty) return const [];

    final snap = await _evaluations
        .where('companyId', isEqualTo: cid)
        .where('supplierId', isEqualTo: sid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((d) => SupplierEvaluationModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<String> createEvaluation({
    required Map<String, dynamic> companyData,
    required String supplierId,
    required String supplierCode,
    required String supplierName,
    required String periodKey,
    required double qualityRating,
    required double deliveryRating,
    required double responseRating,
    required double complianceRating,
    String? notes,
  }) async {
    final companyId = _s(companyData['companyId']);
    if (companyId.isEmpty) throw Exception('Missing companyId');

    final res = await _functions
        .httpsCallable('createSupplierEvaluation')
        .call<Map<String, dynamic>>({
      'companyId': companyId,
      'supplierId': supplierId.trim(),
      'supplierCode': supplierCode.trim(),
      'supplierName': supplierName.trim(),
      'periodKey': periodKey.trim(),
      'qualityRating': qualityRating,
      'deliveryRating': deliveryRating,
      'responseRating': responseRating,
      'complianceRating': complianceRating,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Evaluacija nije uspjela.');
    }
    final id = _s(data['evaluationId']);
    if (id.isEmpty) throw Exception('Evaluacija: prazan odgovor.');
    return id;
  }
}

String _evalS(dynamic v) => (v ?? '').toString().trim();
String? _evalNullable(dynamic v) {
  final t = _evalS(v);
  return t.isEmpty ? null : t;
}

double _evalD(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_evalS(v).replaceAll(',', '.')) ?? 0;
}

DateTime? _evalToDate(dynamic v) {
  if (v == null) return null;
  try {
    if (v.runtimeType.toString() == 'Timestamp') {
      return (v as dynamic).toDate() as DateTime?;
    }
  } catch (_) {}
  if (v is DateTime) return v;
  return DateTime.tryParse(_evalS(v));
}

