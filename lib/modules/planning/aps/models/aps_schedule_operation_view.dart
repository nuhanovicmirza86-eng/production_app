import '../helpers/aps_callable_timestamp.dart';
import '../helpers/aps_gantt_info_copy.dart';

/// Jedna operacija na Gantt-u — samo polja za prikaz planeru.
class ApsScheduleOperationView {
  const ApsScheduleOperationView({
    required this.resourceCode,
    required this.demandCode,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.status,
    this.demandName,
    this.productCode,
    this.durationMinutes,
  });

  final String resourceCode;
  final String demandCode;
  final String? demandName;
  final String? productCode;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String status;
  final int? durationMinutes;

  String get primaryLabel {
    if (demandCode.trim().isNotEmpty) return demandCode.trim();
    if (demandName != null && demandName!.trim().isNotEmpty) {
      return demandName!.trim();
    }
    return 'Potražnja';
  }

  String? get productLine {
    final parts = <String>[];
    if (demandName != null &&
        demandName!.trim().isNotEmpty &&
        demandName!.trim() != primaryLabel) {
      parts.add(demandName!.trim());
    }
    if (productCode != null && productCode!.trim().isNotEmpty) {
      parts.add(productCode!.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String get statusLabel => ApsGanttInfoCopy.operationStatusLabel(status);

  bool get isDraftPlanned => status == 'draft_planned';

  factory ApsScheduleOperationView.fromMap(
    Map<String, dynamic> map, {
    String? demandName,
    String? productCode,
  }) {
    return ApsScheduleOperationView(
      resourceCode: (map['resourceCode'] ?? '').toString().trim(),
      demandCode: (map['demandCode'] ?? '').toString().trim(),
      demandName: demandName,
      productCode: productCode ??
          ((map['productCode'] ?? '').toString().trim().isEmpty
              ? null
              : (map['productCode'] ?? '').toString().trim()),
      scheduledStart: parseApsCallableTimestamp(map['scheduledStart']),
      scheduledEnd: parseApsCallableTimestamp(map['scheduledEnd']),
      status: (map['status'] ?? '').toString().trim(),
      durationMinutes: _parseInt(map['durationMinutes']),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }
}
