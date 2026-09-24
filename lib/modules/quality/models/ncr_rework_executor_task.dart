/// M1-I12-D — poslovni kontekst zadatka dorade za dodijeljenog izvršioca.
class NcrReworkExecutorTask {
  const NcrReworkExecutorTask({
    required this.ncrId,
    this.ncrCode,
    this.productCode,
    this.productName,
    this.productLabel,
    this.productionOrderCode,
    this.machineName,
    this.workCenterName,
    this.taskDescription,
    this.note,
    this.dueAt,
    this.priorityLabel,
    this.containment,
    this.outcomeLabel,
    this.quantityHint,
    this.executionStatus,
    this.canConfirm = false,
  });

  final String ncrId;
  final String? ncrCode;
  final String? productCode;
  final String? productName;
  final String? productLabel;
  final String? productionOrderCode;
  final String? machineName;
  final String? workCenterName;
  final String? taskDescription;
  final String? note;
  final String? dueAt;
  final String? priorityLabel;
  final String? containment;
  final String? outcomeLabel;
  final int? quantityHint;
  final String? executionStatus;
  final bool canConfirm;

  String get displayNcrCode =>
      (ncrCode ?? '').trim().isNotEmpty ? ncrCode!.trim() : 'Neusaglašenost';

  String get displayProduct {
    final label = (productLabel ?? '').trim();
    if (label.isNotEmpty) return label;
    final code = (productCode ?? '').trim();
    final name = (productName ?? '').trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
    return name.isNotEmpty ? name : (code.isNotEmpty ? code : '—');
  }

  String get displayMachine {
    final machine = (machineName ?? '').trim();
    if (machine.isNotEmpty) return machine;
    final wc = (workCenterName ?? '').trim();
    return wc.isNotEmpty ? wc : '—';
  }

  factory NcrReworkExecutorTask.fromMap(Map<String, dynamic> map) {
    final qtyRaw = map['quantityHint'];
    int? qty;
    if (qtyRaw is num) {
      qty = qtyRaw.toInt();
    } else {
      qty = int.tryParse('$qtyRaw');
    }
    return NcrReworkExecutorTask(
      ncrId: (map['ncrId'] ?? '').toString().trim(),
      ncrCode: map['ncrCode']?.toString(),
      productCode: map['productCode']?.toString(),
      productName: map['productName']?.toString(),
      productLabel: map['productLabel']?.toString(),
      productionOrderCode: map['productionOrderCode']?.toString(),
      machineName: map['machineName']?.toString(),
      workCenterName: map['workCenterName']?.toString(),
      taskDescription: map['taskDescription']?.toString(),
      note: map['note']?.toString(),
      dueAt: map['dueAt']?.toString(),
      priorityLabel: map['priorityLabel']?.toString(),
      containment: map['containment']?.toString(),
      outcomeLabel: map['outcomeLabel']?.toString(),
      quantityHint: qty,
      executionStatus: map['executionStatus']?.toString(),
      canConfirm: map['canConfirm'] == true,
    );
  }
}
