import 'package:cloud_firestore/cloud_firestore.dart';

/// Veza Operonix ↔ ERP (`finance_document_links`).
class FinanceDocumentLinkModel {
  const FinanceDocumentLinkModel({
    required this.id,
    required this.companyId,
    required this.connectionId,
    required this.provider,
    required this.operonixEntityType,
    required this.operonixEntityId,
    this.operonixModule = '',
    this.erpEntityType = '',
    this.erpEntityId = '',
    this.erpDocumentNumber = '',
    this.plantKey = '',
    this.businessYearId = '',
    this.currency = '',
    this.syncStatus = '',
    this.amountNet,
    this.amountGross,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String connectionId;
  final String provider;
  final String operonixModule;
  final String operonixEntityType;
  final String operonixEntityId;
  final String erpEntityType;
  final String erpEntityId;
  final String erpDocumentNumber;
  final String plantKey;
  final String businessYearId;
  final String currency;
  final String syncStatus;
  final double? amountNet;
  final double? amountGross;
  final DateTime? updatedAt;

  factory FinanceDocumentLinkModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return FinanceDocumentLinkModel(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      connectionId: (data['connectionId'] ?? '').toString(),
      provider: (data['provider'] ?? '').toString(),
      operonixModule: (data['operonixModule'] ?? '').toString(),
      operonixEntityType: (data['operonixEntityType'] ?? '').toString(),
      operonixEntityId: (data['operonixEntityId'] ?? '').toString(),
      erpEntityType: (data['erpEntityType'] ?? '').toString(),
      erpEntityId: (data['erpEntityId'] ?? '').toString(),
      erpDocumentNumber: (data['erpDocumentNumber'] ?? '').toString(),
      plantKey: (data['plantKey'] ?? '').toString(),
      businessYearId: (data['businessYearId'] ?? '').toString(),
      currency: (data['currency'] ?? '').toString(),
      syncStatus: (data['syncStatus'] ?? '').toString(),
      amountNet: _d(data['amountNet']),
      amountGross: _d(data['amountGross']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
