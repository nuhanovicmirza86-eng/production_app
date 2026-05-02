import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/development_project_model.dart';
import '../models/development_project_task_model.dart';
import '../utils/development_constants.dart';

/// Rezultat Callable `createDevelopmentProject`.
class DevelopmentProjectCreateResult {
  const DevelopmentProjectCreateResult({
    required this.projectId,
    required this.projectCode,
  });

  final String projectId;
  final String projectCode;
}

/// Čitanje kolekcije `development_projects`; mutacije preko Callable (Admin SDK).
class DevelopmentProjectService {
  DevelopmentProjectService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static FirebaseFunctions _functions() =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('development_projects');

  /// Stream pojedinačnog projekta (live).
  Stream<DevelopmentProjectModel?> watchProject(String projectId) {
    return _collection.doc(projectId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DevelopmentProjectModel.fromDoc(doc);
    });
  }

  /// Stream projekata za tenant + pogon, opcijski filtrirano po poslovnoj godini.
  Stream<List<DevelopmentProjectModel>> watchProjects({
    required String companyId,
    required String plantKey,
    String? businessYearId,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> q = _collection
        .where('companyId', isEqualTo: companyId)
        .where('plantKey', isEqualTo: plantKey);

    if (businessYearId != null && businessYearId.trim().isNotEmpty) {
      q = q.where('businessYearId', isEqualTo: businessYearId.trim());
    }

    q = q.orderBy('updatedAt', descending: true).limit(limit);

    return q.snapshots().map(
          (snap) => snap.docs
              .map(DevelopmentProjectModel.fromDoc)
              .toList(growable: false),
        );
  }

  Future<DevelopmentProjectModel?> getProject(String projectId) async {
    final doc = await _collection.doc(projectId).get();
    if (!doc.exists) return null;
    return DevelopmentProjectModel.fromDoc(doc);
  }

  CollectionReference<Map<String, dynamic>> _tasksCol(String projectId) =>
      _collection.doc(projectId).collection('tasks');

  /// Zadaci projekta (podkolekcija `tasks`).
  Stream<List<DevelopmentProjectTaskModel>> watchTasks(
    String projectId, {
    int limit = 200,
  }) {
    return _tasksCol(projectId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(DevelopmentProjectTaskModel.fromDoc)
              .toList(growable: false),
        );
  }

  /// Kreiranje zadatka — Callable `createDevelopmentProjectTask`.
  Future<String> createTaskViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String title,
    String? description,
    String status = DevelopmentTaskStatuses.open,
  }) async {
    final callable = _functions().httpsCallable('createDevelopmentProjectTask');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'title': title.trim(),
      'status': status.trim(),
    };
    final d = description?.trim();
    if (d != null && d.isNotEmpty) payload['description'] = d;

    final res = await callable.call(payload);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Očekivan odgovor s poslužitelja nije stigao.');
    }
    final id = Map<String, dynamic>.from(raw)['taskId']?.toString() ?? '';
    if (id.isEmpty) throw Exception('Nije vraćen taskId.');
    return id;
  }

  /// Ažuriranje zadatka — Callable `updateDevelopmentProjectTask`.
  Future<void> updateTaskViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String taskId,
    required Map<String, dynamic> patch,
  }) async {
    final callable = _functions().httpsCallable('updateDevelopmentProjectTask');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'taskId': taskId,
      'patch': patch,
    });
  }

  /// Kreiranje projekta — Callable `createDevelopmentProject`.
  Future<DevelopmentProjectCreateResult> createProjectViaCallable({
    required String companyId,
    required String plantKey,
    required String businessYearId,
    required String projectName,
    required String projectType,
    String priority = DevelopmentPriorities.medium,
    String? customerName,
    String? projectManagerId,
  }) async {
    final callable =
        _functions().httpsCallable('createDevelopmentProject');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'businessYearId': businessYearId.trim(),
      'projectName': projectName.trim(),
      'projectType': projectType.trim(),
      'priority': priority.trim(),
    };
    final cn = customerName?.trim();
    if (cn != null && cn.isNotEmpty) {
      payload['customerName'] = cn;
    }
    final pm = projectManagerId?.trim();
    if (pm != null && pm.isNotEmpty) {
      payload['projectManagerId'] = pm;
    }

    final res = await callable.call(payload);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Očekivan odgovor s poslužitelja nije stigao.');
    }
    final data = Map<String, dynamic>.from(raw);
    final id = data['projectId']?.toString() ?? '';
    final code = data['projectCode']?.toString() ?? '';
    if (id.isEmpty) {
      throw Exception('Kreiranje nije vratilo projectId.');
    }
    return DevelopmentProjectCreateResult(projectId: id, projectCode: code);
  }

  /// Ažuriranje polja projekta — Callable `updateDevelopmentProject`.
  Future<void> updateProjectViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required Map<String, dynamic> patch,
  }) async {
    final callable = _functions().httpsCallable('updateDevelopmentProject');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'patch': patch,
    });
  }

  /// Zamjena `team` + `teamMemberIds` + PM — Callable `replaceDevelopmentProjectTeam`.
  Future<void> replaceProjectTeamViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required List<Map<String, dynamic>> team,
  }) async {
    final callable = _functions().httpsCallable('replaceDevelopmentProjectTeam');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'team': team,
    });
  }
}
