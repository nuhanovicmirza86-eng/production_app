import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only model za `employees/{employeeId}` (Personal modul v1).
class PersonalEmployeeDoc {
  PersonalEmployeeDoc({
    required this.employeeId,
    required this.companyId,
    required this.homePlantKey,
    required this.assignedPlantKeys,
    required this.firstName,
    required this.lastName,
    required this.employmentType,
    required this.status,
  });

  final String employeeId;
  final String companyId;
  final String homePlantKey;
  final List<String> assignedPlantKeys;
  final String firstName;
  final String lastName;
  final String employmentType;
  final String status;

  static PersonalEmployeeDoc fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? <String, dynamic>{};
    return PersonalEmployeeDoc(
      employeeId: d.id,
      companyId: (m['companyId'] ?? '').toString().trim(),
      homePlantKey: (m['homePlantKey'] ?? '').toString().trim(),
      assignedPlantKeys: _readStringList(m['assignedPlantKeys']),
      firstName: (m['firstName'] ?? '').toString().trim(),
      lastName: (m['lastName'] ?? '').toString().trim(),
      employmentType: (m['employmentType'] ?? '').toString().trim(),
      status: (m['status'] ?? '').toString().trim(),
    );
  }

  static List<String> _readStringList(dynamic v) {
    if (v == null) {
      return const [];
    }
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
