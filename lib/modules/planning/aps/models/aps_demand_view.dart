import '../helpers/aps_callable_timestamp.dart';

/// Planirana potražnja za operativni P1 ekran.
class ApsDemandView {
  const ApsDemandView({
    required this.id,
    required this.demandCode,
    required this.demandName,
    required this.demandType,
    required this.quantity,
    required this.quantityUom,
    required this.dueDate,
    required this.status,
    this.estimatedMinutesPerUnit,
    this.isActive = true,
  });

  final String id;
  final String demandCode;
  final String demandName;
  final String demandType;
  final num quantity;
  final String quantityUom;
  final DateTime? dueDate;
  final String status;
  final num? estimatedMinutesPerUnit;
  final bool isActive;

  String get displayLabel {
    if (demandName.trim().isNotEmpty) return demandName.trim();
    return demandCode.trim().isNotEmpty ? demandCode.trim() : 'Potražnja';
  }

  String get subtitleLabel {
    final code = demandCode.trim();
    if (code.isEmpty || code == displayLabel) {
      return '${quantity.toString()} $quantityUom';
    }
    return '$code · ${quantity.toString()} $quantityUom';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ApsDemandView && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory ApsDemandView.fromMap(Map<String, dynamic> map) {
    final active = map['isActive'];
    return ApsDemandView(
      id: (map['id'] ?? '').toString().trim(),
      demandCode: (map['demandCode'] ?? '').toString().trim(),
      demandName: (map['demandName'] ?? '').toString().trim(),
      demandType: (map['demandType'] ?? 'manual').toString().trim(),
      quantity: (map['quantity'] as num?) ?? 0,
      quantityUom: (map['quantityUom'] ?? 'pcs').toString().trim(),
      dueDate: parseApsCallableTimestamp(map['dueDate']),
      status: (map['status'] ?? '').toString().trim(),
      estimatedMinutesPerUnit: map['estimatedMinutesPerUnit'] as num?,
      isActive: active is bool ? active : true,
    );
  }
}
