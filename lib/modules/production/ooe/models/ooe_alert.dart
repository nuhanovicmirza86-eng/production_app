import 'package:cloud_firestore/cloud_firestore.dart';

/// Jedan alarm (`ooe_alerts`) — upisuje Callable.
class OoeAlert {
  final String id;
  final String companyId;
  final String plantKey;
  final String machineId;
  final String ruleId;
  final String ruleType;
  final String? ruleName;
  final String status;
  final String? message;
  final double? actualValue;
  final double? threshold;
  final bool? autoDismiss;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByUid;

  const OoeAlert({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.machineId,
    required this.ruleId,
    required this.ruleType,
    this.ruleName,
    required this.status,
    this.message,
    this.actualValue,
    this.threshold,
    this.autoDismiss,
    this.createdAt,
    this.updatedAt,
    this.acknowledgedAt,
    this.acknowledgedByUid,
  });

  static const String statusOpen = 'open';
  static const String statusAcknowledged = 'acknowledged';
  static const String statusDismissed = 'dismissed';

  factory OoeAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) {
      return OoeAlert(
        id: doc.id,
        companyId: '',
        plantKey: '',
        machineId: '',
        ruleId: '',
        ruleType: '',
        status: statusOpen,
      );
    }
    return OoeAlert.fromMap(doc.id, m);
  }

  factory OoeAlert.fromMap(String id, Map<String, dynamic> m) {
    return OoeAlert(
      id: id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      machineId: (m['machineId'] ?? '').toString(),
      ruleId: (m['ruleId'] ?? '').toString(),
      ruleType: (m['ruleType'] ?? '').toString(),
      ruleName: m['ruleName']?.toString(),
      status: (m['status'] ?? statusOpen).toString(),
      message: m['message']?.toString(),
      actualValue: (m['actualValue'] as num?)?.toDouble(),
      threshold: (m['threshold'] as num?)?.toDouble(),
      autoDismiss: m['autoDismiss'] == true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      acknowledgedAt: (m['acknowledgedAt'] as Timestamp?)?.toDate(),
      acknowledgedByUid: m['acknowledgedByUid']?.toString(),
    );
  }
}
