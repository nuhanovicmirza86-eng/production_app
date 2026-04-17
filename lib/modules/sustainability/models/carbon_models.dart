import 'package:cloud_firestore/cloud_firestore.dart';

class CarbonCompanySetup {
  final String companyId;
  final int reportingYear;
  final String plantKey;
  final String companyName;
  final String countryCode;
  final String city;
  final String industry;
  final String period;
  final String currency;
  final int employeeCount;
  final double revenue;
  final double unitsProduced;
  final int locationCount;
  final String boundaryNotes;

  const CarbonCompanySetup({
    required this.companyId,
    required this.reportingYear,
    required this.plantKey,
    required this.companyName,
    this.countryCode = 'BA',
    this.city = '',
    this.industry = '',
    this.period = 'Godišnji',
    this.currency = 'BAM',
    this.employeeCount = 0,
    this.revenue = 0,
    this.unitsProduced = 0,
    this.locationCount = 1,
    this.boundaryNotes = '',
  });

  String get reportingKey => '${countryCode}_$reportingYear';

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'reportingYear': reportingYear,
      'plantKey': plantKey,
      'companyName': companyName,
      'countryCode': countryCode,
      'city': city,
      'industry': industry,
      'period': period,
      'currency': currency,
      'employeeCount': employeeCount,
      'revenue': revenue,
      'unitsProduced': unitsProduced,
      'locationCount': locationCount,
      'boundaryNotes': boundaryNotes,
    };
  }

  factory CarbonCompanySetup.fromMap(Map<String, dynamic> m) {
    return CarbonCompanySetup(
      companyId: _s(m['companyId']),
      reportingYear: _i(m['reportingYear'], DateTime.now().year),
      plantKey: _s(m['plantKey']),
      companyName: _s(m['companyName']),
      countryCode: _s(m['countryCode']).isEmpty ? 'BA' : _s(m['countryCode']),
      city: _s(m['city']),
      industry: _s(m['industry']),
      period: _s(m['period']).isEmpty ? 'Godišnji' : _s(m['period']),
      currency: _s(m['currency']).isEmpty ? 'BAM' : _s(m['currency']),
      employeeCount: _i(m['employeeCount'], 0),
      revenue: _d(m['revenue']),
      unitsProduced: _d(m['unitsProduced']),
      locationCount: _i(m['locationCount'], 1),
      boundaryNotes: _s(m['boundaryNotes']),
    );
  }

  CarbonCompanySetup copyWith({
    String? companyName,
    String? countryCode,
    String? city,
    String? industry,
    String? period,
    String? currency,
    int? employeeCount,
    double? revenue,
    double? unitsProduced,
    int? locationCount,
    String? boundaryNotes,
  }) {
    return CarbonCompanySetup(
      companyId: companyId,
      reportingYear: reportingYear,
      plantKey: plantKey,
      companyName: companyName ?? this.companyName,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      industry: industry ?? this.industry,
      period: period ?? this.period,
      currency: currency ?? this.currency,
      employeeCount: employeeCount ?? this.employeeCount,
      revenue: revenue ?? this.revenue,
      unitsProduced: unitsProduced ?? this.unitsProduced,
      locationCount: locationCount ?? this.locationCount,
      boundaryNotes: boundaryNotes ?? this.boundaryNotes,
    );
  }
}

class CarbonQuotaSettings {
  final String companyId;
  final int reportingYear;
  final int baselineYear;
  final double baselineEmissionsTCO2e;
  final double reductionTargetPercent;
  final double absoluteQuotaTCO2e;
  final double intensityTargetPerEmployee;
  final double intensityTargetPerUnit;

  const CarbonQuotaSettings({
    required this.companyId,
    required this.reportingYear,
    this.baselineYear = 0,
    this.baselineEmissionsTCO2e = 0,
    this.reductionTargetPercent = 0,
    this.absoluteQuotaTCO2e = 0,
    this.intensityTargetPerEmployee = 0,
    this.intensityTargetPerUnit = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'reportingYear': reportingYear,
      'baselineYear': baselineYear,
      'baselineEmissionsTCO2e': baselineEmissionsTCO2e,
      'reductionTargetPercent': reductionTargetPercent,
      'absoluteQuotaTCO2e': absoluteQuotaTCO2e,
      'intensityTargetPerEmployee': intensityTargetPerEmployee,
      'intensityTargetPerUnit': intensityTargetPerUnit,
    };
  }

  factory CarbonQuotaSettings.fromMap(Map<String, dynamic> m) {
    return CarbonQuotaSettings(
      companyId: _s(m['companyId']),
      reportingYear: _i(m['reportingYear'], DateTime.now().year),
      baselineYear: _i(m['baselineYear'], 0),
      baselineEmissionsTCO2e: _d(m['baselineEmissionsTCO2e']),
      reductionTargetPercent: _d(m['reductionTargetPercent']),
      absoluteQuotaTCO2e: _d(m['absoluteQuotaTCO2e']),
      intensityTargetPerEmployee: _d(m['intensityTargetPerEmployee']),
      intensityTargetPerUnit: _d(m['intensityTargetPerUnit']),
    );
  }

  CarbonQuotaSettings copyWith({
    int? baselineYear,
    double? baselineEmissionsTCO2e,
    double? reductionTargetPercent,
    double? absoluteQuotaTCO2e,
    double? intensityTargetPerEmployee,
    double? intensityTargetPerUnit,
  }) {
    return CarbonQuotaSettings(
      companyId: companyId,
      reportingYear: reportingYear,
      baselineYear: baselineYear ?? this.baselineYear,
      baselineEmissionsTCO2e:
          baselineEmissionsTCO2e ?? this.baselineEmissionsTCO2e,
      reductionTargetPercent:
          reductionTargetPercent ?? this.reductionTargetPercent,
      absoluteQuotaTCO2e: absoluteQuotaTCO2e ?? this.absoluteQuotaTCO2e,
      intensityTargetPerEmployee:
          intensityTargetPerEmployee ?? this.intensityTargetPerEmployee,
      intensityTargetPerUnit:
          intensityTargetPerUnit ?? this.intensityTargetPerUnit,
    );
  }
}

class CarbonEmissionFactor {
  final String factorKey;
  final String scope;
  final String category;
  final String activity;
  final String unit;
  final double factorKgCo2ePerUnit;
  final String sourceName;
  final String sourceUrl;
  final String factorStatus;

  const CarbonEmissionFactor({
    required this.factorKey,
    required this.scope,
    required this.category,
    required this.activity,
    required this.unit,
    required this.factorKgCo2ePerUnit,
    this.sourceName = '',
    this.sourceUrl = '',
    this.factorStatus = 'default',
  });

  Map<String, dynamic> toMap() {
    return {
      'factorKey': factorKey,
      'scope': scope,
      'category': category,
      'activity': activity,
      'unit': unit,
      'factorKgCo2ePerUnit': factorKgCo2ePerUnit,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'factorStatus': factorStatus,
    };
  }

  factory CarbonEmissionFactor.fromMap(Map<String, dynamic> m) {
    return CarbonEmissionFactor(
      factorKey: _s(m['factorKey']),
      scope: _s(m['scope']),
      category: _s(m['category']),
      activity: _s(m['activity']),
      unit: _s(m['unit']),
      factorKgCo2ePerUnit: _d(m['factorKgCo2ePerUnit']),
      sourceName: _s(m['sourceName']),
      sourceUrl: _s(m['sourceUrl']),
      factorStatus: _s(m['factorStatus']),
    );
  }
}

class CarbonActivityLine {
  final String id;
  final String companyId;
  final int reportingYear;
  final String rowId;
  final bool include;
  final String plantKey;
  /// Firestore ID proizvoda (šifrarnik) — za zbrojeve; u UI-u se prikazuje šifra.
  final String productId;
  /// Šifra proizvoda iz šifrarnika (za prikaz/CSV); može biti prazna kod starijih zapisa.
  final String productCode;
  /// Opcionalno: ljudski čitljiv naziv proizvoda (prikaz u izvještajima).
  final String productLabel;
  /// Opcionalno: koliko ste proizveli uz ovaj red (jedinice proizvoda); ne utječe na
  /// `unitsProduced` u postavkama kompanije niti na izračun kg CO2e (emisija = quantity × faktor).
  final double productOutputQty;
  final String activityDate;
  final String activityType;
  final String description;
  final double quantity;
  final String unit;
  final String factorKey;
  final String evidenceRef;
  final String ownerDept;
  final String status;
  final String notes;

  const CarbonActivityLine({
    required this.id,
    required this.companyId,
    required this.reportingYear,
    required this.rowId,
    this.include = true,
    required this.plantKey,
    this.productId = '',
    this.productCode = '',
    this.productLabel = '',
    this.productOutputQty = 0,
    this.activityDate = '',
    required this.activityType,
    required this.description,
    this.quantity = 0,
    required this.unit,
    required this.factorKey,
    this.evidenceRef = '',
    this.ownerDept = '',
    this.status = '',
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'reportingYear': reportingYear,
      'rowId': rowId,
      'include': include,
      'plantKey': plantKey,
      'productId': productId,
      'productCode': productCode,
      'productLabel': productLabel,
      'productOutputQty': productOutputQty,
      'activityDate': activityDate,
      'activityType': activityType,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'factorKey': factorKey,
      'evidenceRef': evidenceRef,
      'ownerDept': ownerDept,
      'status': status,
      'notes': notes,
    };
  }

  factory CarbonActivityLine.fromDoc(String id, Map<String, dynamic> m) {
    return CarbonActivityLine(
      id: id,
      companyId: _s(m['companyId']),
      reportingYear: _i(m['reportingYear'], DateTime.now().year),
      rowId: _s(m['rowId']),
      include: m['include'] == true,
      plantKey: _s(m['plantKey']),
      productId: _s(m['productId']),
      productCode: _s(m['productCode']),
      productLabel: _s(m['productLabel']),
      productOutputQty: _d(m['productOutputQty']),
      activityDate: _s(m['activityDate']),
      activityType: _s(m['activityType']),
      description: _s(m['description']),
      quantity: _d(m['quantity']),
      unit: _s(m['unit']),
      factorKey: _s(m['factorKey']),
      evidenceRef: _s(m['evidenceRef']),
      ownerDept: _s(m['ownerDept']),
      status: _s(m['status']),
      notes: _s(m['notes']),
    );
  }
}

/// Jedan zapis u povijesti izmjena karbonskog izvještaja (append-only u Firestore).
class CarbonAuditLogEntry {
  final String id;
  final String companyId;
  final int reportingYear;
  final String action;
  final String userId;
  final String detail;
  final DateTime? createdAt;

  const CarbonAuditLogEntry({
    required this.id,
    required this.companyId,
    required this.reportingYear,
    required this.action,
    required this.userId,
    this.detail = '',
    this.createdAt,
  });

  factory CarbonAuditLogEntry.fromDoc(String id, Map<String, dynamic> m) {
    final ts = m['createdAt'];
    DateTime? at;
    if (ts is Timestamp) at = ts.toDate();
    return CarbonAuditLogEntry(
      id: id,
      companyId: _s(m['companyId']),
      reportingYear: _i(m['reportingYear'], 0),
      action: _s(m['action']),
      userId: _s(m['userId']),
      detail: _s(m['detail']),
      createdAt: at,
    );
  }
}

class CarbonDashboardSummary {
  final double totalKgCo2e;
  final double scope1Kg;
  final double scope2Kg;
  final double scope3Kg;
  final double totalTCO2e;
  final double perEmployeeTCO2e;
  final double perUnitKgCo2e;
  final double per1000RevenueTCO2e;
  final int includedActivityCount;
  final int rowsWithQuantity;

  const CarbonDashboardSummary({
    required this.totalKgCo2e,
    required this.scope1Kg,
    required this.scope2Kg,
    required this.scope3Kg,
    required this.totalTCO2e,
    required this.perEmployeeTCO2e,
    required this.perUnitKgCo2e,
    required this.per1000RevenueTCO2e,
    required this.includedActivityCount,
    required this.rowsWithQuantity,
  });
}

/// Zbroj emisija po `plantKey` (prazan ključ = „bez oznake pogona”).
class CarbonPlantRollup {
  final String plantKey;
  final double totalKgCo2e;
  final double totalTCO2e;
  final int lineCount;

  const CarbonPlantRollup({
    required this.plantKey,
    required this.totalKgCo2e,
    required this.totalTCO2e,
    required this.lineCount,
  });

  String get displayPlant =>
      plantKey.trim().isEmpty ? '(bez oznake pogona)' : plantKey.trim();
}

/// Razrada emisija po pogonu s podjelom na scope 1 / 2 / 3 (kg CO2e).
class CarbonPlantDetailedRollup {
  final String plantKey;
  final double scope1Kg;
  final double scope2Kg;
  final double scope3Kg;
  final int lineCount;

  const CarbonPlantDetailedRollup({
    required this.plantKey,
    required this.scope1Kg,
    required this.scope2Kg,
    required this.scope3Kg,
    required this.lineCount,
  });

  double get totalKgCo2e => scope1Kg + scope2Kg + scope3Kg;

  double get totalTCO2e => totalKgCo2e / 1000;

  String get displayPlant =>
      plantKey.trim().isEmpty ? '(bez oznake pogona)' : plantKey.trim();
}

/// Jedna kombinacija pogon + proizvod (samo redovi s productId), s scope zbrojevima.
class CarbonProductPlantRollup {
  final String plantKey;
  final String productId;
  final String productCode;
  final String productLabel;
  final double scope1Kg;
  final double scope2Kg;
  final double scope3Kg;
  final int lineCount;
  final double totalProductOutputQty;

  const CarbonProductPlantRollup({
    required this.plantKey,
    required this.productId,
    this.productCode = '',
    this.productLabel = '',
    required this.scope1Kg,
    required this.scope2Kg,
    required this.scope3Kg,
    required this.lineCount,
    this.totalProductOutputQty = 0,
  });

  double get totalKgCo2e => scope1Kg + scope2Kg + scope3Kg;

  double get totalTCO2e => totalKgCo2e / 1000;

  String get displayPlant =>
      plantKey.trim().isEmpty ? '(bez oznake pogona)' : plantKey.trim();

  /// Za PDF: naziv + šifra, bez tehničkog ID-a.
  String get displayProductTitle {
    final code = productCode.trim();
    final lb = productLabel.trim();
    if (lb.isNotEmpty && code.isNotEmpty) return '$lb · $code';
    if (lb.isNotEmpty) return lb;
    if (code.isNotEmpty) return code;
    return 'Proizvod';
  }
}

/// Zbroj emisija po proizvodu (`productId` + prikazni `productLabel`).
class CarbonProductRollup {
  final String productId;
  final String productCode;
  final String productLabel;
  final double totalKgCo2e;
  final double totalTCO2e;
  final int lineCount;
  /// Zbroj opcionalnog polja „proizvedena količina” po redovima (ne utječe na emisiju).
  final double totalProductOutputQty;

  const CarbonProductRollup({
    required this.productId,
    this.productCode = '',
    required this.productLabel,
    required this.totalKgCo2e,
    required this.totalTCO2e,
    required this.lineCount,
    this.totalProductOutputQty = 0,
  });

  String get displayTitle {
    final code = productCode.trim();
    final lb = productLabel.trim();
    if (code.isNotEmpty && lb.isNotEmpty) {
      return '$lb · šifra $code';
    }
    if (lb.isNotEmpty) return lb;
    if (code.isNotEmpty) return 'šifra $code';
    final id = productId.trim();
    return id;
  }
}

String _s(dynamic v) => (v ?? '').toString().trim();

int _i(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_s(v)) ?? fallback;
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
}
