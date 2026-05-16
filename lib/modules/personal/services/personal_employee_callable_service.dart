import 'package:cloud_functions/cloud_functions.dart';

/// Payload za Callable [createEmployee] (`functions_personal` / region `europe-west1`).
class CreateEmployeePayload {
  const CreateEmployeePayload({
    required this.companyId,
    required this.homePlantKey,
    required this.firstName,
    required this.lastName,
    required this.employmentType,
  });

  final String companyId;
  final String homePlantKey;
  final String firstName;
  final String lastName;
  final String employmentType;
}

/// Odgovor Callablea — identifikator novog dokumenta `employees/{employeeId}`.
class CreateEmployeeResult {
  const CreateEmployeeResult({required this.employeeId});

  final String employeeId;
}

/// Personal modul — Callable-i za zaposlenike (skeleton; bez UI).
///
/// Regija mora odgovarati backend deployu (`europe-west1`).
class PersonalEmployeeCallableService {
  PersonalEmployeeCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<CreateEmployeeResult> createEmployee(CreateEmployeePayload payload) async {
    final companyId = payload.companyId.trim();
    if (companyId.isEmpty) {
      throw StateError('companyId je obavezan.');
    }
    final homePlantKey = payload.homePlantKey.trim();
    if (homePlantKey.isEmpty) {
      throw StateError('homePlantKey je obavezan.');
    }
    final firstName = payload.firstName.trim();
    if (firstName.isEmpty) {
      throw StateError('firstName je obavezan.');
    }
    final lastName = payload.lastName.trim();
    if (lastName.isEmpty) {
      throw StateError('lastName je obavezan.');
    }
    final employmentType = payload.employmentType.trim();
    if (employmentType.isEmpty) {
      throw StateError('employmentType je obavezan.');
    }

    final raw = await _functions
        .httpsCallable('createEmployee')
        .call<Map<String, dynamic>>({
          'companyId': companyId,
          'homePlantKey': homePlantKey,
          'firstName': firstName,
          'lastName': lastName,
          'employmentType': employmentType,
        });

    final data = raw.data;
    final employeeId = (data['employeeId'] ?? '').toString().trim();
    if (employeeId.isEmpty) {
      throw StateError('Callable createEmployee: prazan employeeId u odgovoru.');
    }
    return CreateEmployeeResult(employeeId: employeeId);
  }
}
