/// Kontekst za ekran „Izvrši kontrolu“ (Callable [getQmsInspectionExecutionContext]).
class QmsMeasureSlot {
  final String characteristicRef;
  final String name;
  final double? nominal;
  final double? toleranceMin;
  final double? toleranceMax;
  final String? unit;

  const QmsMeasureSlot({
    required this.characteristicRef,
    required this.name,
    this.nominal,
    this.toleranceMin,
    this.toleranceMax,
    this.unit,
  });

  factory QmsMeasureSlot.fromMap(Map<String, dynamic> m) {
    double? d(dynamic x) =>
        x == null ? null : double.tryParse(x.toString());
    return QmsMeasureSlot(
      characteristicRef: (m['characteristicRef'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      nominal: d(m['nominal']),
      toleranceMin: d(m['toleranceMin']),
      toleranceMax: d(m['toleranceMax']),
      unit: m['unit']?.toString(),
    );
  }
}

class QmsInspectionExecutionContext {
  final String inspectionPlanId;
  final String inspectionType;
  final String inspectionPlanStatus;
  final String productId;
  final String controlPlanId;
  final String controlPlanTitle;
  /// Raw status polje kontrolnog plana (draft / approved / obsolete).
  final String controlPlanStatus;
  final bool executionReady;
  /// `obsolete` | `not_approved` kad [executionReady] je false.
  final String? executionBlockedReason;
  final List<QmsMeasureSlot> measureSlots;

  const QmsInspectionExecutionContext({
    required this.inspectionPlanId,
    required this.inspectionType,
    required this.inspectionPlanStatus,
    required this.productId,
    required this.controlPlanId,
    required this.controlPlanTitle,
    this.controlPlanStatus = '',
    this.executionReady = true,
    this.executionBlockedReason,
    required this.measureSlots,
  });

  factory QmsInspectionExecutionContext.fromMap(Map<String, dynamic> m) {
    final raw = m['measureSlots'];
    final slots = <QmsMeasureSlot>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          slots.add(QmsMeasureSlot.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return QmsInspectionExecutionContext(
      inspectionPlanId: (m['inspectionPlanId'] ?? '').toString(),
      inspectionType: (m['inspectionType'] ?? '').toString(),
      inspectionPlanStatus: (m['inspectionPlanStatus'] ?? '').toString(),
      productId: (m['productId'] ?? '').toString(),
      controlPlanId: (m['controlPlanId'] ?? '').toString(),
      controlPlanTitle: (m['controlPlanTitle'] ?? '').toString(),
      controlPlanStatus: (m['controlPlanStatus'] ?? '').toString(),
      // Legacy Callable-i bez polja: ponašaj se kao „spremno“ (staro upozorenje u payloadu).
      executionReady: m['executionReady'] != false,
      executionBlockedReason: m['executionBlockedReason']?.toString(),
      measureSlots: slots,
    );
  }
}
