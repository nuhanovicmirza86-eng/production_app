import 'package:cloud_firestore/cloud_firestore.dart';

/// Agregat KPI za Finance dashboard (`finance_kpi_snapshots`).
/// Svi monetarni iznosi u [currency] / [baseCurrency] — konverziju za prikaz radi Flutter.
class FinanceKpiSnapshotModel {
  const FinanceKpiSnapshotModel({
    required this.id,
    required this.companyId,
    required this.businessYearId,
    required this.periodYear,
    required this.periodMonth,
    this.plantKey = '',
    this.revenue = 0,
    this.totalCost = 0,
    this.grossMargin = 0,
    this.scrapCost = 0,
    this.downtimeLoss = 0,
    this.maintenanceCost = 0,
    this.energyCost = 0,
    this.costPerProduct = 0,
    this.currency = 'EUR',
    this.baseCurrency,
    this.updatedAt,
    this.downtimeOeeMinutes = 0,
    this.machineHourlyRate,
    this.machineHourlyRateEur,
    this.copqProductionScrapQty = 0,
    this.copqProductionReworkQty = 0,
    this.copqProductionCost = 0,
    this.copqQualityNcrClosedCount = 0,
    this.copqQualityEstimatedCost = 0,
    this.maintenanceClosedFaultCount = 0,
    this.orderProfitabilityAvailable = false,
    this.kpiProducedGoodQty = 0,
  });

  final String id;
  final String companyId;
  final String businessYearId;
  final int periodYear;
  final int periodMonth;
  final String plantKey;
  final double revenue;
  final double totalCost;
  final double grossMargin;
  final double scrapCost;
  final double downtimeLoss;
  final double maintenanceCost;
  final double energyCost;
  final double costPerProduct;

  /// Bazna valuta agregata (isto kao canonical base).
  final String currency;

  /// Eksplicitno polje ako postoji (inace koristi [currency]).
  final String? baseCurrency;

  final DateTime? updatedAt;

  final int downtimeOeeMinutes;

  final double? machineHourlyRate;

  final double? machineHourlyRateEur;

  /// Količine scrappa / reworka (proizvodni nalozi, `updatedAt` u periodu).
  final double copqProductionScrapQty;
  final double copqProductionReworkQty;

  /// COPQ iz proizvodnje u bazi (što × postavljene jedinične cijene).
  final double copqProductionCost;

  /// Broj zatvorenih NCR-a u periodu (modul quality).
  final int copqQualityNcrClosedCount;

  /// Procjena COPQ iz NCR-a (`copqClosedNcrEstimateInBase` × broj).
  final double copqQualityEstimatedCost;

  /// Broj zatvorenih kvarova u periodu (`faults`).
  final int maintenanceClosedFaultCount;

  /// Nema komercijalnog prihoda u snimku (npr. PN nije vezan na kupčku stavku ili nema tečaja).
  final bool orderProfitabilityAvailable;

  /// Ukupno dobrih komada na PN-evima u KPI periodu (brojnik za grubu jedinicu troška).
  final double kpiProducedGoodQty;

  /// Satnica u baznoj valuti (preferiraj ovo nad legacy [machineHourlyRateEur]).
  double? get effectiveMachineHourlyRate =>
      machineHourlyRate ?? machineHourlyRateEur;

  String get canonicalBaseCurrency {
    final b = baseCurrency?.trim();
    if (b != null && b.isNotEmpty) return b.toUpperCase();
    return currency.trim().toUpperCase();
  }

  factory FinanceKpiSnapshotModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceKpiSnapshotModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      periodYear: _i(data['periodYear']),
      periodMonth: _i(data['periodMonth']),
      plantKey: (data['plantKey'] ?? '').toString(),
      revenue: _d(data['revenue']),
      totalCost: _d(data['totalCost']),
      grossMargin: _d(data['grossMargin']),
      scrapCost: _d(data['scrapCost']),
      downtimeLoss: _d(data['downtimeLoss']),
      maintenanceCost: _d(data['maintenanceCost']),
      energyCost: _d(data['energyCost']),
      costPerProduct: _d(data['costPerProduct']),
      currency: (data['currency'] ?? 'EUR').toString(),
      baseCurrency: data['baseCurrency']?.toString(),
      updatedAt: _ts(data['updatedAt']),
      downtimeOeeMinutes: _i(data['downtimeOeeMinutes']),
      machineHourlyRate: _dOpt(data['machineHourlyRate']),
      machineHourlyRateEur: _dOpt(data['machineHourlyRateEur']),
      copqProductionScrapQty: _d(data['copqProductionScrapQty']),
      copqProductionReworkQty: _d(data['copqProductionReworkQty']),
      copqProductionCost: _d(data['copqProductionCost']),
      copqQualityNcrClosedCount: _i(data['copqQualityNcrClosedCount']),
      copqQualityEstimatedCost: _d(data['copqQualityEstimatedCost']),
      maintenanceClosedFaultCount: _i(data['maintenanceClosedFaultCount']),
      orderProfitabilityAvailable:
          data['orderProfitabilityAvailable'] == true,
      kpiProducedGoodQty: _d(data['kpiProducedGoodQty']),
    );
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0;
  }

  static double? _dOpt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    }
    return null;
  }
}
