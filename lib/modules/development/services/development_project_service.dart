import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/development_project_document_model.dart';
import '../models/development_project_model.dart';
import '../models/development_project_risk_model.dart';
import '../models/development_project_stage_model.dart';
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

  CollectionReference<Map<String, dynamic>> _risksCol(String projectId) =>
      _collection.doc(projectId).collection('risks');

  CollectionReference<Map<String, dynamic>> _stagesCol(String projectId) =>
      _collection.doc(projectId).collection('stages');

  CollectionReference<Map<String, dynamic>> _documentsCol(String projectId) =>
      _collection.doc(projectId).collection('documents');

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

  /// Rizici projekta (podkolekcija `risks`).
  Stream<List<DevelopmentProjectRiskModel>> watchRisks(
    String projectId, {
    int limit = 200,
  }) {
    return _risksCol(projectId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(DevelopmentProjectRiskModel.fromDoc)
              .toList(growable: false),
        );
  }

  /// Stage-Gate faze (`stages`), sortirano po [sortOrder].
  Stream<List<DevelopmentProjectStageModel>> watchStages(String projectId) {
    return _stagesCol(projectId)
        .orderBy('sortOrder')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(DevelopmentProjectStageModel.fromDoc)
              .toList(growable: false),
        );
  }

  /// Evidencija dokumenata (metadata).
  Stream<List<DevelopmentProjectDocumentModel>> watchDocuments(
    String projectId, {
    int limit = 120,
  }) {
    return _documentsCol(projectId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(DevelopmentProjectDocumentModel.fromDoc)
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

  /// Kreiranje zapisa dokumenta — Callable `createDevelopmentProjectDocument`.
  Future<String> createDocumentViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String title,
    String? description,
    String docType = DevelopmentDocumentTypes.other,
    String status = DevelopmentDocumentStatuses.draft,
    String? linkedGate,
    String? externalRef,
  }) async {
    final callable =
        _functions().httpsCallable('createDevelopmentProjectDocument');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'title': title.trim(),
      'docType': docType.trim(),
      'status': status.trim(),
    };
    final d = description?.trim();
    if (d != null && d.isNotEmpty) payload['description'] = d;
    final g = linkedGate?.trim();
    if (g != null && g.isNotEmpty) payload['linkedGate'] = g;
    final e = externalRef?.trim();
    if (e != null && e.isNotEmpty) payload['externalRef'] = e;

    final res = await callable.call(payload);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Očekivan odgovor s poslužitelja nije stigao.');
    }
    final id = Map<String, dynamic>.from(raw)['documentId']?.toString() ?? '';
    if (id.isEmpty) throw Exception('Nije vraćen documentId.');
    return id;
  }

  /// Ažuriranje dokumenta — Callable `updateDevelopmentProjectDocument`.
  Future<void> updateDocumentViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String documentId,
    required Map<String, dynamic> patch,
  }) async {
    final callable =
        _functions().httpsCallable('updateDevelopmentProjectDocument');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'documentId': documentId,
      'patch': patch,
    });
  }

  /// Kreiranje rizika — Callable `createDevelopmentProjectRisk`.
  Future<String> createRiskViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String title,
    String? description,
    String severity = DevelopmentRiskLevels.medium,
    String status = DevelopmentRiskStatuses.open,
    String? category,
    bool? blocksRelease,
    String? mitigationNote,
  }) async {
    final callable =
        _functions().httpsCallable('createDevelopmentProjectRisk');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'title': title.trim(),
      'severity': severity.trim(),
      'status': status.trim(),
    };
    final d = description?.trim();
    if (d != null && d.isNotEmpty) payload['description'] = d;
    final c = category?.trim();
    if (c != null && c.isNotEmpty) payload['category'] = c;
    if (blocksRelease != null) payload['blocksRelease'] = blocksRelease;
    final m = mitigationNote?.trim();
    if (m != null && m.isNotEmpty) payload['mitigationNote'] = m;

    final res = await callable.call(payload);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Očekivan odgovor s poslužitelja nije stigao.');
    }
    final id = Map<String, dynamic>.from(raw)['riskId']?.toString() ?? '';
    if (id.isEmpty) throw Exception('Nije vraćen riskId.');
    return id;
  }

  /// Ažuriranje rizika — Callable `updateDevelopmentProjectRisk`.
  Future<void> updateRiskViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String riskId,
    required Map<String, dynamic> patch,
  }) async {
    final callable =
        _functions().httpsCallable('updateDevelopmentProjectRisk');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'riskId': riskId,
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

  /// AI sažetak (Vertex) — Callable `runDevelopmentProjectAiAnalysis`; kontekst učitava backend.
  Future<String> runDevelopmentProjectAiAnalysis({
    required String companyId,
    required String plantKey,
    required String projectId,
    String? analysisFocus,
  }) async {
    final callable =
        _functions().httpsCallable('runDevelopmentProjectAiAnalysis');
    final payload = <String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
    };
    final f = analysisFocus?.trim();
    if (f != null && f.isNotEmpty) {
      payload['analysisFocus'] = f;
    }
    final res = await callable.call(payload);
    final raw = res.data;
    if (raw is! Map) {
      throw Exception('Očekivan odgovor s poslužitelja nije stigao.');
    }
    final md =
        Map<String, dynamic>.from(raw)['analysisMarkdown']?.toString() ?? '';
    if (md.isEmpty) {
      throw Exception('Prazan AI odgovor.');
    }
    return md;
  }

  /// Ako backend nema `stages` (stari projekti), PM/admin poziva seed.
  Future<bool> seedStagesIfEmptyViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
  }) async {
    final callable =
        _functions().httpsCallable('seedDevelopmentProjectStagesIfEmpty');
    final res = await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
    });
    final raw = res.data;
    if (raw is! Map) return false;
    return Map<String, dynamic>.from(raw)['seeded'] == true;
  }

  /// Patch jedne faze (G0–G9) — Callable `updateDevelopmentProjectStage`.
  Future<void> updateStageViaCallable({
    required String companyId,
    required String plantKey,
    required String projectId,
    required String stageId,
    required Map<String, dynamic> patch,
  }) async {
    final callable =
        _functions().httpsCallable('updateDevelopmentProjectStage');
    await callable.call(<String, dynamic>{
      'companyId': companyId,
      'plantKey': plantKey,
      'projectId': projectId,
      'stageId': stageId,
      'patch': patch,
    });
  }
}
