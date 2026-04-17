class CustomerModel {
  final String id;
  final String companyId;
  final String code;
  final String name;
  final String legalName;
  final String status; // active, inactive, blocked
  final String customerType; // direct, distributor, internal, other

  final String? country;
  final String? city;
  final String? address;
  final String? taxId;
  final String? notes;

  /// Ugovoreni rok isporuke od datuma narudžbe (kalendarski dani).
  final int? contractDeliveryDays;

  /// Ugovoreni rok plaćanja (npr. neto dani).
  final int? contractPaymentDays;

  /// Rok naplate / fakturisanja (dani), ako se razlikuje od plaćanja.
  final int? contractCollectionDays;

  /// Dozvoljeni prekoračeni rok (grace, dani).
  final int? contractGraceDaysLate;

  /// Sektor djelatnosti (NACE ili slobodan opis) — filter u listama.
  final String? activitySector;

  /// Operativna kategorija: A (dobar), B (upozorenje), C (nepouzdan), unrated.
  final String partnerRatingClass;

  /// Ako je C, ali nema alternative — označiti kao strateški (posebna logika u UI).
  final bool isStrategic;

  const CustomerModel({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    required this.legalName,
    required this.status,
    required this.customerType,
    this.country,
    this.city,
    this.address,
    this.taxId,
    this.notes,
    this.contractDeliveryDays,
    this.contractPaymentDays,
    this.contractCollectionDays,
    this.contractGraceDaysLate,
    this.activitySector,
    this.partnerRatingClass = 'unrated',
    this.isStrategic = false,
  });

  factory CustomerModel.fromMap(String id, Map<String, dynamic> map) {
    return CustomerModel(
      id: id,
      companyId: _s(map['companyId']),
      code: _s(map['code']),
      name: _s(map['name']),
      legalName: _s(map['legalName']),
      status: _s(map['status']).isEmpty ? 'active' : _s(map['status']),
      customerType: _s(map['customerType']).isEmpty
          ? 'direct'
          : _s(map['customerType']),
      country: _nullable(map['country']),
      city: _nullable(map['city']),
      address: _nullable(map['address']),
      taxId: _nullable(map['taxId']),
      notes: _nullable(map['notes']),
      contractDeliveryDays: _intOrNull(map['contractDeliveryDays']),
      contractPaymentDays: _intOrNull(map['contractPaymentDays']),
      contractCollectionDays: _intOrNull(map['contractCollectionDays']),
      contractGraceDaysLate: _intOrNull(map['contractGraceDaysLate']),
      activitySector: _nullable(map['activitySector']),
      partnerRatingClass: _partnerRatingClassFrom(map['partnerRatingClass']),
      isStrategic: _bool(map['isStrategic']),
    );
  }

  Map<String, dynamic> toMapForWrite({required bool includeIdFields}) {
    return <String, dynamic>{
      if (includeIdFields) 'customerId': id,
      'companyId': companyId,
      'code': code,
      'name': name,
      'legalName': legalName,
      'status': status,
      'customerType': customerType,
      if ((country ?? '').trim().isNotEmpty) 'country': country,
      if ((city ?? '').trim().isNotEmpty) 'city': city,
      if ((address ?? '').trim().isNotEmpty) 'address': address,
      if ((taxId ?? '').trim().isNotEmpty) 'taxId': taxId,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes,
      if (contractDeliveryDays != null)
        'contractDeliveryDays': contractDeliveryDays,
      if (contractPaymentDays != null)
        'contractPaymentDays': contractPaymentDays,
      if (contractCollectionDays != null)
        'contractCollectionDays': contractCollectionDays,
      if (contractGraceDaysLate != null)
        'contractGraceDaysLate': contractGraceDaysLate,
      'activitySector': (activitySector ?? '').trim(),
      'partnerRatingClass': partnerRatingClass,
      'isStrategic': isStrategic,
    };
  }
}

/// Auto-skor iz narudžbi (Callable `refreshSupplierOperationalSignals`) + NC/claim na dobavljaču.
///
/// Verzija algoritma 2: dodatni signali iz zatvorenih stavki narudžbe i opcionalno
/// `quality_nonconformities` (polja `supplierId` / `partnerId` / `sourceSupplierId`).
class SupplierOperationalAuto {
  final double score;
  final double? deliveryScore;
  final double? qtyScore;
  final double qualityScore;
  final double lateLineRate;
  final int linesAnalyzed;
  final int algorithmVersion;

  /// Snimljeno pri računanju (dokument dobavljača).
  final int nonconformanceCount;
  final int claimCount;

  /// Zatvorene linije gdje primljeno/ naručeno < 0.92 ili > 1.05.
  final int qtyMismatchLines;

  /// Linije sa statusom odbijeno / vraćeno (heuristika po nazivu statusa).
  final int rejectedLines;

  /// Broj zapisa u `quality_nonconformities` vezanih za ovog dobavljača.
  final int linkedNonconformityCount;

  final double? avgQtyFillRatio;

  const SupplierOperationalAuto({
    required this.score,
    this.deliveryScore,
    this.qtyScore,
    required this.qualityScore,
    required this.lateLineRate,
    required this.linesAnalyzed,
    required this.algorithmVersion,
    this.nonconformanceCount = 0,
    this.claimCount = 0,
    this.qtyMismatchLines = 0,
    this.rejectedLines = 0,
    this.linkedNonconformityCount = 0,
    this.avgQtyFillRatio,
  });

  static SupplierOperationalAuto? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    if (!m.containsKey('score')) return null;
    return SupplierOperationalAuto(
      score: _double(m['score']),
      deliveryScore: m['deliveryScore'] == null
          ? null
          : _double(m['deliveryScore']),
      qtyScore: m['qtyScore'] == null ? null : _double(m['qtyScore']),
      qualityScore: _double(m['qualityScore']),
      lateLineRate: _double(m['lateLineRate']),
      linesAnalyzed: _int(m['linesAnalyzed']),
      algorithmVersion: _int(m['algorithmVersion']),
      nonconformanceCount: m.containsKey('nonconformanceCount')
          ? _int(m['nonconformanceCount'])
          : 0,
      claimCount: m.containsKey('claimCount') ? _int(m['claimCount']) : 0,
      qtyMismatchLines: m.containsKey('qtyMismatchLines')
          ? _int(m['qtyMismatchLines'])
          : 0,
      rejectedLines: m.containsKey('rejectedLines')
          ? _int(m['rejectedLines'])
          : 0,
      linkedNonconformityCount: m.containsKey('linkedNonconformityCount')
          ? _int(m['linkedNonconformityCount'])
          : 0,
      avgQtyFillRatio: m['avgQtyFillRatio'] == null
          ? null
          : _double(m['avgQtyFillRatio']),
    );
  }
}

class SupplierModel {
  final String id;
  final String companyId;
  final String code;
  final String name;
  final String legalName;
  final String status; // active, inactive, blocked
  final String supplierType; // material, packaging, service, tooling, transport

  final String? country;
  final String? city;
  final String? address;
  final String? taxId;
  final String? notes;

  /// Ugovoreni rok isporuke od datuma narudžbe (kalendarski dani).
  final int? contractDeliveryDays;

  /// Ugovoreni rok plaćanja (neto dani).
  final int? contractPaymentDays;

  /// Rok naplate / fakturisanja (dani).
  final int? contractCollectionDays;

  /// Dozvoljeni prekoračeni rok (grace, dani).
  final int? contractGraceDaysLate;

  /// Sektor djelatnosti (NACE ili opis).
  final String? activitySector;

  /// A / B / C / unrated — operativna procjena partnera.
  final String partnerRatingClass;

  final int? leadTimeDays;

  // IATF supplier governance fields
  final String supplierCategory; // strategic, approved, conditional, blocked
  final bool isStrategic;
  final String approvalStatus; // approved, conditional, disqualified, pending
  final DateTime? approvalDate;

  final String riskLevel; // low, medium, high
  final int nonconformanceCount;
  final int claimCount;
  final DateTime? lastEvaluationDate;
  final DateTime? nextAuditDate;

  final double qualityRating;
  final double deliveryRating;
  final double responseRating;
  final double overallScore;

  final List<String> approvedMaterialGroups;
  final List<String> approvedProcesses;
  final List<String> certificates;

  /// Agregat iz `order_items` (rokovi, količine) + NC/claim; ne mijenja IATF evaluaciju.
  final SupplierOperationalAuto? operationalAuto;

  const SupplierModel({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    required this.legalName,
    required this.status,
    required this.supplierType,
    this.country,
    this.city,
    this.address,
    this.taxId,
    this.notes,
    this.contractDeliveryDays,
    this.contractPaymentDays,
    this.contractCollectionDays,
    this.contractGraceDaysLate,
    this.activitySector,
    this.partnerRatingClass = 'unrated',
    this.leadTimeDays,
    this.supplierCategory = 'approved',
    this.isStrategic = false,
    this.approvalStatus = 'pending',
    this.approvalDate,
    this.riskLevel = 'medium',
    this.nonconformanceCount = 0,
    this.claimCount = 0,
    this.lastEvaluationDate,
    this.nextAuditDate,
    this.qualityRating = 0,
    this.deliveryRating = 0,
    this.responseRating = 0,
    this.overallScore = 0,
    this.approvedMaterialGroups = const [],
    this.approvedProcesses = const [],
    this.certificates = const [],
    this.operationalAuto,
  });

  factory SupplierModel.fromMap(String id, Map<String, dynamic> map) {
    return SupplierModel(
      id: id,
      companyId: _s(map['companyId']),
      code: _s(map['code']),
      name: _s(map['name']),
      legalName: _s(map['legalName']),
      status: _s(map['status']).isEmpty ? 'active' : _s(map['status']),
      supplierType: _s(map['supplierType']).isEmpty
          ? 'material'
          : _s(map['supplierType']),
      country: _nullable(map['country']),
      city: _nullable(map['city']),
      address: _nullable(map['address']),
      taxId: _nullable(map['taxId']),
      notes: _nullable(map['notes']),
      contractDeliveryDays: _intOrNull(map['contractDeliveryDays']),
      contractPaymentDays: _intOrNull(map['contractPaymentDays']),
      contractCollectionDays: _intOrNull(map['contractCollectionDays']),
      contractGraceDaysLate: _intOrNull(map['contractGraceDaysLate']),
      activitySector: _nullable(map['activitySector']),
      partnerRatingClass: _partnerRatingClassFrom(map['partnerRatingClass']),
      leadTimeDays: _intOrNull(map['leadTimeDays']),
      supplierCategory: _s(map['supplierCategory']).isEmpty
          ? 'approved'
          : _s(map['supplierCategory']),
      isStrategic: _bool(map['isStrategic']),
      approvalStatus: _s(map['approvalStatus']).isEmpty
          ? 'pending'
          : _s(map['approvalStatus']),
      approvalDate: _toDate(map['approvalDate']),
      riskLevel: _s(map['riskLevel']).isEmpty ? 'medium' : _s(map['riskLevel']),
      nonconformanceCount: _int(map['nonconformanceCount']),
      claimCount: _int(map['claimCount']),
      lastEvaluationDate: _toDate(map['lastEvaluationDate']),
      nextAuditDate: _toDate(map['nextAuditDate']),
      qualityRating: _double(map['qualityRating']),
      deliveryRating: _double(map['deliveryRating']),
      responseRating: _double(map['responseRating']),
      overallScore: _double(map['overallScore']),
      approvedMaterialGroups: _stringList(map['approvedMaterialGroups']),
      approvedProcesses: _stringList(map['approvedProcesses']),
      certificates: _stringList(map['certificates']),
      operationalAuto: SupplierOperationalAuto.tryParse(map['operationalAuto']),
    );
  }

  Map<String, dynamic> toMapForWrite({required bool includeIdFields}) {
    return <String, dynamic>{
      if (includeIdFields) 'supplierId': id,
      'companyId': companyId,
      'code': code,
      'name': name,
      'legalName': legalName,
      'status': status,
      'supplierType': supplierType,
      if ((country ?? '').trim().isNotEmpty) 'country': country,
      if ((city ?? '').trim().isNotEmpty) 'city': city,
      if ((address ?? '').trim().isNotEmpty) 'address': address,
      if ((taxId ?? '').trim().isNotEmpty) 'taxId': taxId,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes,
      if (contractDeliveryDays != null)
        'contractDeliveryDays': contractDeliveryDays,
      if (contractPaymentDays != null)
        'contractPaymentDays': contractPaymentDays,
      if (contractCollectionDays != null)
        'contractCollectionDays': contractCollectionDays,
      if (contractGraceDaysLate != null)
        'contractGraceDaysLate': contractGraceDaysLate,
      'activitySector': (activitySector ?? '').trim(),
      'partnerRatingClass': partnerRatingClass,
      if (leadTimeDays != null) 'leadTimeDays': leadTimeDays,
      'supplierCategory': supplierCategory,
      'isStrategic': isStrategic,
      'approvalStatus': approvalStatus,
      if (approvalDate != null) 'approvalDate': approvalDate,
      'riskLevel': riskLevel,
      'nonconformanceCount': nonconformanceCount,
      'claimCount': claimCount,
      if (lastEvaluationDate != null) 'lastEvaluationDate': lastEvaluationDate,
      if (nextAuditDate != null) 'nextAuditDate': nextAuditDate,
      'qualityRating': qualityRating,
      'deliveryRating': deliveryRating,
      'responseRating': responseRating,
      'overallScore': overallScore,
      'approvedMaterialGroups': approvedMaterialGroups,
      'approvedProcesses': approvedProcesses,
      'certificates': certificates,
    };
  }
}

String _s(dynamic v) => (v ?? '').toString().trim();

/// Kanonske vrijednosti: A, B, C, unrated (kompatibilno s backendom).
String _partnerRatingClassFrom(dynamic v) {
  final t = _s(v).toLowerCase();
  switch (t) {
    case 'a':
      return 'A';
    case 'b':
      return 'B';
    case 'c':
      return 'C';
    case 'unrated':
    case '':
      return 'unrated';
    default:
      return 'unrated';
  }
}

String? _nullable(dynamic v) {
  final t = _s(v);
  return t.isEmpty ? null : t;
}

int? _intOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_s(v));
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_s(v)) ?? 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
}

bool _bool(dynamic v) {
  if (v is bool) return v;
  final t = _s(v).toLowerCase();
  return t == 'true' || t == '1' || t == 'yes';
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  try {
    if (v.runtimeType.toString() == 'Timestamp') {
      return (v as dynamic).toDate() as DateTime?;
    }
  } catch (_) {}
  if (v is DateTime) return v;
  return DateTime.tryParse(_s(v));
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
