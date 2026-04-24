import 'package:cloud_firestore/cloud_firestore.dart';

class WorkforceEmployee {
  const WorkforceEmployee({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.employeeCode,
    /// Globalni katalog `RAD_*` (nepromjenjiv kad je dodijeljen).
    this.systemWorkerCode,
    required this.displayName,
    required this.employmentStatus,
    required this.jobTitle,
    required this.shiftGroup,
    required this.active,
    this.reportsToEmployeeDocId,
    this.hireDate,
    this.internalContactEmail,
    this.internalContactPhone,
    this.linkedUserUid,
    this.photoUrl,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String employeeCode;
  final String? systemWorkerCode;
  final String displayName;
  final String employmentStatus;
  final String jobTitle;
  final String shiftGroup;
  final bool active;
  final String? reportsToEmployeeDocId;
  final String? hireDate;
  final String? internalContactEmail;
  final String? internalContactPhone;
  final String? linkedUserUid;
  final String? photoUrl;

  /// Prikaz stabilnog koda (RAD_* ili naslijeđena šifra).
  String get catalogCode {
    final s = systemWorkerCode?.trim();
    if (s != null && s.isNotEmpty) return s;
    return employeeCode.trim();
  }

  String get subtitleLine {
    final parts = <String>[
      if (jobTitle.isNotEmpty) jobTitle,
      if (shiftGroup.isNotEmpty) 'Smjena/grupa: $shiftGroup',
    ];
    return parts.isEmpty ? employeeCode : parts.join(' · ');
  }

  factory WorkforceEmployee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return WorkforceEmployee(
      id: doc.id,
      companyId: (m['companyId'] ?? '').toString(),
      plantKey: (m['plantKey'] ?? '').toString(),
      employeeCode: (m['employeeCode'] ?? '').toString(),
      systemWorkerCode: m['systemWorkerCode']?.toString(),
      displayName: (m['displayName'] ?? '').toString(),
      employmentStatus: (m['employmentStatus'] ?? 'active').toString(),
      jobTitle: (m['jobTitle'] ?? '').toString(),
      shiftGroup: (m['shiftGroup'] ?? '').toString(),
      active: m['active'] != false,
      reportsToEmployeeDocId: m['reportsToEmployeeDocId']?.toString(),
      hireDate: m['hireDate']?.toString(),
      internalContactEmail: m['internalContactEmail']?.toString(),
      internalContactPhone: m['internalContactPhone']?.toString(),
      linkedUserUid: m['linkedUserUid']?.toString(),
      photoUrl: m['photoUrl']?.toString(),
    );
  }
}
