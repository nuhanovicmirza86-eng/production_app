/// M1-I12-D — otvorena akcija neusaglašenosti u inboxu po ulozi.
class NcrOpenActionTask {
  const NcrOpenActionTask({
    required this.ncrId,
    required this.actionKind,
    required this.actionLabelBs,
    required this.statusLabelBs,
    required this.canAct,
    this.ncrCode,
    this.productLabel,
    this.productionOrderCode,
    this.machineName,
    this.dueAt,
    this.taskDescription,
    this.executionStatus,
    this.expectedCheckedQty,
  });

  final String ncrId;
  final String actionKind;
  final String actionLabelBs;
  final String statusLabelBs;
  final bool canAct;
  final String? ncrCode;
  final String? productLabel;
  final String? productionOrderCode;
  final String? machineName;
  final String? dueAt;
  final String? taskDescription;
  final String? executionStatus;
  final int? expectedCheckedQty;

  String get displayNcrCode =>
      (ncrCode ?? '').trim().isNotEmpty ? ncrCode!.trim() : 'Neusaglašenost';

  String get displayProduct {
    final label = (productLabel ?? '').trim();
    if (label.isNotEmpty) return label;
    return '—';
  }

  factory NcrOpenActionTask.fromMap(Map<String, dynamic> map) {
    final qtyRaw = map['expectedCheckedQty'];
    int? qty;
    if (qtyRaw is num) {
      qty = qtyRaw.toInt();
    } else {
      qty = int.tryParse('$qtyRaw');
    }
    return NcrOpenActionTask(
      ncrId: (map['ncrId'] ?? '').toString().trim(),
      actionKind: (map['actionKind'] ?? '').toString().trim(),
      actionLabelBs: (map['actionLabelBs'] ?? '').toString().trim(),
      statusLabelBs: (map['statusLabelBs'] ?? '').toString().trim(),
      canAct: map['canAct'] == true,
      ncrCode: map['ncrCode']?.toString(),
      productLabel: map['productLabel']?.toString(),
      productionOrderCode: map['productionOrderCode']?.toString(),
      machineName: map['machineName']?.toString(),
      dueAt: map['dueAt']?.toString(),
      taskDescription: map['taskDescription']?.toString(),
      executionStatus: map['executionStatus']?.toString(),
      expectedCheckedQty: qty,
    );
  }
}
