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
