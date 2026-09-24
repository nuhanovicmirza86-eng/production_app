import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/company_plant_display_name.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../models/ncr_action_history_models.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';
import '../utils/ncr_closure_execution_choice_options.dart';
import '../utils/ncr_next_disposition_catalog.dart';
import '../utils/qms_ncr_display_labels.dart';
import '../widgets/ncr_next_disposition_dialog.dart';
import '../widgets/ncr_action_execution_panel.dart';
import 'ncr_rework_execution_evidence_screen.dart';
import 'ncr_recheck_execution_evidence_screen.dart';
import 'ncr_closure_task_screen.dart';
import '../widgets/ncr_execution_dialogs.dart';
import '../widgets/ncr_action_hodogram_model.dart';
import '../widgets/ncr_action_hodogram_timeline.dart';
import '../widgets/ncr_action_history_timeline.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../../production/ai/models/operonix_ai_entity_chat_binding.dart';
import '../../production/ai/widgets/operonix_ai_assistant_navigator.dart';
import '../widgets/ncr_action_risk_ai_card.dart';
import '../widgets/ncr_action_risk_banner.dart';
import '../widgets/qms_iatf_help.dart';
import 'capa_detail_screen.dart';
import 'qms_methodology_reference_screen.dart';

class _NcrAttRow {
  _NcrAttRow({String label = '', String url = ''})
    : label = TextEditingController(text: label),
      url = TextEditingController(text: url);

  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

/// Detalj neusaglašenosti + povezane CAPA + prilozi (https — obavezni pri zatvaranju/odbacivanju).
class NcrDetailScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final String ncrId;
  /// M1-I10-A — odmah ponudi unos za ovu preddefinisanu akciju nakon učitavanja.
  final NcrNextDispositionAction? preferredNextAction;

  const NcrDetailScreen({
    super.key,
    required this.companyData,
    required this.ncrId,
    this.preferredNextAction,
  });

  @override
  State<NcrDetailScreen> createState() => _NcrDetailScreenState();
}

class _NcrDetailScreenState extends State<NcrDetailScreen> {
  final _svc = QualityCallableService();
  final _description = TextEditingController();
  final _containment = TextEditingController();
  final _reactionPlan = TextEditingController();
  final _capaWaiverReason = TextEditingController();
  final _fiveWhy = TextEditingController();

  final List<_NcrAttRow> _attachmentRows = [];

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ncr;
  var _capaRows = const <QmsCapaRow>[];
  bool _capaLoading = true;
  int _loadGen = 0;

  bool _historyLoading = true;
  String? _historyError;
  var _historyRows = const <NcrActionHistoryHubRow>[];
  /// Risk signali s Callable-a `getNcrActionRiskSignals` (M1-I13-E banner).
  NcrActionRiskSignalsResult? _preparedRiskSignals;

  bool _aiExplanationLoading = false;
  String? _aiExplanationError;
  NcrActionRiskAiExplanation? _aiExplanation;

  String _status = 'OPEN';
  String _severity = 'MEDIUM';
  String _sourceModule = '';
  bool _saving = false;
  bool _holdingLot = false;
  bool _preferredActionOffered = false;
  String? _plantDisplayName;
  final GlobalKey _nextActionSectionKey = GlobalKey();

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _normalizedRole =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  String get _evidenceProfileKey =>
      (_ncr?['evidenceProfileKey'] ?? '').toString().trim();

  String get _evidenceOutcomeKey =>
      (_ncr?['evidenceOutcomeKey'] ?? '').toString().trim();

  String? get _nextActionKey {
    final v = (_ncr?['nextDispositionActionKey'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  bool get _isClosedRecord =>
      NcrActionHodogramLogic.isNcrClosed(_ncr?['status']?.toString());

  static String _capaStatusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'open':
        return 'Otvoreno';
      case 'in_progress':
        return 'U radu';
      case 'waiting_verification':
        return 'Čekajuća verifikacija';
      case 'closed':
        return 'Zatvoreno';
      case 'cancelled':
        return 'Otkazano';
      default:
        return raw.trim().isEmpty ? '—' : raw.trim();
    }
  }

  bool _hasLogisticsModule() {
    final raw = widget.companyData['enabledModules'];
    if (raw is List) {
      final list = raw.map((e) => e.toString().trim().toLowerCase()).toList();
      if (list.isEmpty) return false;
      return list.contains('logistics');
    }
    return false;
  }

  String? get _ncrLotIdForHold {
    final v = _ncr?['lotId']?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static const _statuses = [
    'OPEN',
    'UNDER_REVIEW',
    'CONTAINED',
    'CLOSED',
    'DISMISSED',
  ];

  static const _severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  static const _sourceModules = <String, String>{
    '': '—',
    'production': 'Proizvodnja',
    'maintenance': 'Održavanje',
    'work_time': 'Radno vrijeme',
    'supplier': 'Dobavljač',
    'customer': 'Kupac',
    'audit': 'Audit',
    'process': 'Proces (proizvodnja)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    _containment.dispose();
    _reactionPlan.dispose();
    _capaWaiverReason.dispose();
    _fiveWhy.dispose();
    for (final r in _attachmentRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _disposeAttachmentRows() {
    for (final r in _attachmentRows) {
      r.dispose();
    }
    _attachmentRows.clear();
  }

  /// QMS-NCR-DETAIL-PERF-01: osnovni NCR odmah; teške sekcije naknadno.
  Future<void> _load() async {
    final gen = ++_loadGen;
    await _loadCore(gen: gen, showFullPageLoader: _ncr == null);
    if (!mounted || gen != _loadGen || _ncr == null) return;
    unawaited(_loadSecondary(gen));
  }

  void _applyCoreNcrFields(
    Map<String, dynamic> n, {
    String? plantLabel,
  }) {
    final plantKey = (n['plantKey'] ?? '').toString().trim();
    final profileKey = (n['evidenceProfileKey'] ?? '').toString().trim();
    final rawDesc = (n['description'] ?? '').toString();
    _description.text = QmsNcrDisplayLabels.sanitizeUserFacingDescription(
      rawDesc,
      evidenceProfileKey: profileKey,
      plantDisplayName: plantLabel,
      plantKey: plantKey,
    );
    _containment.text = (n['containmentAction'] ?? '').toString();
    _reactionPlan.text = (n['reactionPlan'] ?? '').toString();
    final st = (n['status'] ?? 'OPEN').toString().toUpperCase();
    _status = _statuses.contains(st) ? st : 'OPEN';
    final sev = (n['severity'] ?? 'MEDIUM').toString().toUpperCase();
    _severity = _severities.contains(sev) ? sev : 'MEDIUM';
    _capaWaiverReason.text = (n['capaWaiverReason'] ?? '').toString();
    final sm = n['sourceModule']?.toString().trim() ?? '';
    _sourceModule = sm.isEmpty || !_sourceModules.containsKey(sm) ? '' : sm;
    final f5 = n['fiveWhySteps'];
    if (f5 is List) {
      _fiveWhy.text = f5.map((e) => e.toString().trim()).join('\n');
    } else {
      _fiveWhy.text = '';
    }

    _disposeAttachmentRows();
    final raw = n['attachments'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          _attachmentRows.add(
            _NcrAttRow(
              label: (m['label'] ?? '').toString(),
              url: (m['url'] ?? '').toString(),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadCore({
    required int gen,
    required bool showFullPageLoader,
  }) async {
    if (showFullPageLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final n = await _svc.getQmsNonConformanceMap(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      if (!mounted || gen != _loadGen) return;
      _applyCoreNcrFields(n, plantLabel: _plantDisplayName);
      setState(() {
        _ncr = n;
        _loading = false;
        _error = null;
      });
      if (!_preferredActionOffered &&
          widget.preferredNextAction != null &&
          (n['nextDispositionActionKey'] ?? '').toString().trim().isEmpty) {
        _preferredActionOffered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _captureNextDisposition(widget.preferredNextAction!);
          }
        });
      }
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadSecondary(int gen) async {
    if (!mounted || gen != _loadGen) return;
    final canHistory =
        ProductionAccessHelper.canViewNcrActionHistory(_normalizedRole);
    final hasAiModule =
        ProductionModuleKeys.hasAiProductionAnalyticsModule(widget.companyData);
    setState(() {
      if (_capaRows.isEmpty) _capaLoading = true;
      if (canHistory) {
        if (_historyRows.isEmpty) _historyLoading = true;
        _historyError = null;
        if (_aiExplanation == null) _aiExplanationLoading = hasAiModule;
        _aiExplanationError = null;
      } else {
        _historyLoading = false;
        _historyError = null;
        _historyRows = const [];
        _preparedRiskSignals = null;
        _aiExplanation = null;
        _aiExplanationError = null;
        _aiExplanationLoading = false;
      }
    });
    await Future.wait<void>([
      _loadCapa(gen),
      _loadPlantLabel(gen),
      if (canHistory) _loadHistoryRiskAi(gen, hasAiModule: hasAiModule),
    ]);
  }

  Future<void> _loadCapa(int gen) async {
    try {
      final caps = await _svc.listCapaForNcr(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _capaRows = caps;
        _capaLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _capaLoading = false);
    }
  }

  Future<void> _loadPlantLabel(int gen) async {
    final n = _ncr;
    if (n == null) return;
    final plantKey = (n['plantKey'] ?? '').toString().trim();
    if (plantKey.isEmpty) return;
    try {
      String? plantLabel = await CompanyPlantDisplayName.resolve(
        companyId: _cid,
        plantKey: plantKey,
      );
      if (plantLabel != null &&
          (QmsNcrDisplayLabels.isTechnicalPlantKey(plantLabel) ||
              (plantLabel.trim() == plantKey &&
                  QmsNcrDisplayLabels.isTechnicalPlantKey(plantKey)))) {
        plantLabel = null;
      }
      if (!mounted || gen != _loadGen) return;
      final n = _ncr;
      if (n == null) return;
      final profileKey = (n['evidenceProfileKey'] ?? '').toString().trim();
      final rawDesc = (n['description'] ?? '').toString();
      _description.text = QmsNcrDisplayLabels.sanitizeUserFacingDescription(
        rawDesc,
        evidenceProfileKey: profileKey,
        plantDisplayName: plantLabel,
        plantKey: plantKey,
      );
      setState(() => _plantDisplayName = plantLabel);
    } catch (_) {
      // Pogon je kozmetika prikaza — ne ruši detalj.
    }
  }

  Future<void> _loadHistoryRiskAi(
    int gen, {
    required bool hasAiModule,
  }) async {
    final historyFuture = _svc.listNcrActionHistory(
      companyId: _cid,
      ncrId: widget.ncrId,
    );
    final riskFuture = _svc.getNcrActionRiskSignals(
      companyId: _cid,
      ncrId: widget.ncrId,
    );
    final aiFuture = hasAiModule
        ? _svc.explainNcrActionRiskSignals(
            companyId: _cid,
            ncrId: widget.ncrId,
          )
        : null;

    try {
      final hist = await historyFuture;
      final risk = await riskFuture;
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _historyRows = hist.items
            .map(
              (e) => NcrActionHistoryHubRow(
                entry: e,
                ncrDocumentNo: hist.ncrDocumentNo,
                ncrStatusLabel: hist.ncrStatusLabel,
                ncrId: widget.ncrId,
              ),
            )
            .toList();
        _preparedRiskSignals = risk;
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _historyError = AppErrorMapper.toMessage(e);
        _historyLoading = false;
        _preparedRiskSignals = null;
        _historyRows = const [];
      });
    }

    if (aiFuture == null) {
      if (mounted && gen == _loadGen) {
        setState(() => _aiExplanationLoading = false);
      }
      return;
    }
    try {
      final aiExplanation = await aiFuture;
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _aiExplanation = aiExplanation;
        _aiExplanationError = null;
        _aiExplanationLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _aiExplanationError = AppErrorMapper.toMessage(e);
        _aiExplanationLoading = false;
      });
    }
  }

  void _retryHeavySections() {
    if (_ncr == null) {
      unawaited(_load());
      return;
    }
    final gen = ++_loadGen;
    unawaited(_loadSecondary(gen));
  }

  Future<void> _captureNextDisposition(NcrNextDispositionAction action) async {
    final draft = await showNcrNextDispositionDialog(
      context: context,
      action: action,
      companyId: _cid,
      existingNcr: _ncr,
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _svc.updateQmsNonConformance(
        companyId: _cid,
        ncrId: widget.ncrId,
        nextDispositionActionKey: draft.action.key,
        nextDispositionOwner: draft.ownerDisplayName,
        nextDispositionOwnerUserKey: draft.ownerUserKey,
        nextDispositionDueAt: draft.dueAtIso,
        nextDispositionReason: draft.reason,
        nextDispositionRoleKey: draft.roleOptionId,
        nextDispositionRoleLabel: draft.roleLabelBs,
        nextDispositionPriorityKey: draft.priorityKey,
        nextDispositionPriorityLabel: draft.priorityLabelBs,
        nextDispositionTask: draft.taskTemplate,
        nextDispositionNote: draft.optionalNote,
        nextDispositionPhase: draft.phaseKey,
        nextDispositionExecutor: draft.executorDisplayName,
        nextDispositionExecutorUserKey: draft.executorUserKey,
        nextDispositionExecutorRoleKey: draft.executorRoleOptionId,
        nextDispositionExecutorRoleLabel: draft.executorRoleLabelBs,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.flowPhase == NcrDispositionFlowPhase.assignReworkExecutor
                ? 'Izvršilac dorade dodijeljen'
                : 'Spremljena akcija: ${draft.action.businessLabelBs}',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===== M1-I12-D — izvršenje akcije (dodijeljeno ≠ urađeno) =====

  Future<void> _runExecutionCall(
    Future<void> Function() body,
    String successBs,
  ) async {
    setState(() => _saving = true);
    try {
      await body();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successBs)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onExecutionPrimaryAction(
    NcrExecutionPrimaryAction action,
  ) async {
    final gate = NcrExecutionLogic.resolve(
      ncr: _ncr,
      currentUid: _currentUid,
      normalizedRole: _normalizedRole,
    );
    if (gate == null || !gate.userMayAct) return;

    switch (action) {
      case NcrExecutionPrimaryAction.assignExecutor:
        await _captureNextDisposition(NcrNextDispositionAction.sendToRework);
        return;
      case NcrExecutionPrimaryAction.confirmRework:
        await _confirmReworkExecution();
        return;
      case NcrExecutionPrimaryAction.runRecheck:
        await _recordRecheckResult();
        return;
      case NcrExecutionPrimaryAction.closeNcr:
        await _closeNcrFromPanel();
        return;
      case NcrExecutionPrimaryAction.newDecision:
        await _pickNewDecision();
        return;
      case NcrExecutionPrimaryAction.recordStop:
        await _recordProductionStop();
        return;
      case NcrExecutionPrimaryAction.releaseStop:
        await _releaseProductionStop();
        return;
      case NcrExecutionPrimaryAction.none:
        return;
    }
  }

  Future<void> _confirmReworkExecution() async {
    final draft = await openNcrReworkExecutionEvidence(
      context,
      taskBs: (_ncr?['nextDispositionTask'] ?? '').toString(),
    );
    if (draft == null || !mounted) return;
    await _runExecutionCall(
      () => _svc.confirmNcrReworkExecution(
        companyId: _cid,
        ncrId: widget.ncrId,
        reworkedQty: draft.reworkedQty,
        separatedQty: draft.separatedQty,
        toRecheckQty: draft.toRecheckQty,
        workDescription: draft.workDescription,
        machineCorrectionDone: draft.machineCorrectionDone,
        correctionDescription: draft.correctionDescription,
        separatedDescription: draft.separatedDescription,
        note: draft.note,
        executedAt: draft.executedAt,
      ),
      'Završetak dorade je potvrđen',
    );
  }

  Future<void> _recordRecheckResult() async {
    if (!ProductionAccessHelper.canRunNcrQualityRecheckRole(_normalizedRole)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ponovnu kontrolu može izvršiti samo kontrola kvaliteta.',
          ),
        ),
      );
      return;
    }
    final rework = _ncr?['executionRework'];
    final expected = rework is Map
        ? int.tryParse((rework['toRecheckQty'] ?? '').toString())
        : null;
    final draft = await openNcrRecheckExecutionEvidence(
      context,
      expectedCheckedQty: expected,
    );
    if (draft == null || !mounted) return;
    await _runExecutionCall(
      () => _svc.recordNcrRecheckResult(
        companyId: _cid,
        ncrId: widget.ncrId,
        checkedQty: draft.checkedQty,
        okQty: draft.okQty,
        rejectedQty: draft.rejectedQty,
        separatedQty: draft.separatedQty,
        checkDescription: draft.checkDescription,
        note: draft.note,
      ),
      draft.rejectedQty > 0
          ? 'Ishod spremljen — potrebna je nova odluka'
          : 'Ponovna kontrola odobrena',
    );
  }

  Future<void> _recordProductionStop() async {
    List<Map<String, dynamic>> approvers = const [];
    try {
      approvers = await _svc.listUsersForNcrDispositionAssignment(
        companyId: _cid,
        roleKeys: const ['production_manager'],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
      return;
    }
    if (!mounted) return;
    if (approvers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nema aktivnog menadžera proizvodnje koji bi odobrio nastavak.',
          ),
        ),
      );
      return;
    }
    final draft = await showDialog<NcrProductionStopDraft>(
      context: context,
      builder: (_) => NcrProductionStopDialog(approverOptions: approvers),
    );
    if (draft == null || !mounted) return;
    await _runExecutionCall(
      () => _svc.recordNcrProductionStop(
        companyId: _cid,
        ncrId: widget.ncrId,
        machineLabel: draft.machineLabel,
        reason: draft.reason,
        restartCondition: draft.restartCondition,
        separatedQty: draft.separatedQty,
        releaseApproverUserKey: draft.releaseApproverUserKey,
        releaseApproverName: draft.releaseApproverName,
        separatedDescription: draft.separatedDescription,
      ),
      'Zaustavljanje proizvodnje je evidentirano',
    );
  }

  Future<void> _releaseProductionStop() async {
    final stop = _ncr?['executionStop'];
    final condition =
        stop is Map ? (stop['restartCondition'] ?? '').toString() : '';
    final draft = await showDialog<NcrStopReleaseDraft>(
      context: context,
      builder: (_) => NcrStopReleaseDialog(restartConditionBs: condition),
    );
    if (draft == null || !mounted) return;
    await _runExecutionCall(
      () => _svc.approveNcrProductionStopRelease(
        companyId: _cid,
        ncrId: widget.ncrId,
        conditionMet: true,
        releaseNote: draft.releaseNote,
      ),
      'Nastavak proizvodnje je odobren',
    );
  }

  Future<void> _pickNewDecision() async {
    final actions = NcrNextDispositionCatalog.actionsForProfile(
      _evidenceProfileKey,
    );
    final picked = await showModalBottomSheet<NcrNextDispositionAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nova odluka za odbijene komade',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...actions.map(
              (a) => ListTile(
                leading: Icon(a.icon),
                title: Text(a.businessLabelBs),
                onTap: () => Navigator.of(ctx).pop(a),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _captureNextDisposition(picked);
  }

  Future<void> _closeNcrFromPanel() async {
    if (NcrActionHodogramLogic.isNcrClosed(_status)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neusaglašenost je već zatvorena.'),
        ),
      );
      return;
    }
    if (!ProductionAccessHelper.canRunNcrQualityRecheckRole(_normalizedRole)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Zatvaranje neusaglašenosti može izvršiti samo kontrola kvaliteta.',
          ),
        ),
      );
      return;
    }
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => NcrClosureTaskScreen(
          companyData: widget.companyData,
          ncrId: widget.ncrId,
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neusaglašenost je uspješno zatvorena.'),
        ),
      );
      await _load();
    }
  }

  Widget _executionPanel() {
    final state = NcrExecutionLogic.resolve(
      ncr: _ncr,
      currentUid: _currentUid,
      normalizedRole: _normalizedRole,
    );
    if (state == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NcrActionExecutionPanel(
        state: state,
        busy: _saving,
        onPrimaryAction: _onExecutionPrimaryAction,
      ),
    );
  }

  OperonixAiEntityChatBinding? _ncrAiChatBinding() {
    final n = _ncr;
    if (n == null) return null;
    final code = QmsNcrDisplayLabels.displayDocumentNumber(
      ncrDocumentNo: n['ncrDocumentNo']?.toString(),
      ncrCode: n['ncrCode']?.toString(),
    ).trim();
    if (code.isEmpty) return null;
    return OperonixAiEntityChatBinding(
      kind: OperonixAiEntityChatKind.ncr,
      businessKey: code,
      displayLabel: code,
    );
  }

  Widget _businessContextCard() {
    final n = _ncr;
    if (n == null) return const SizedBox.shrink();
    final code = QmsNcrDisplayLabels.displayDocumentNumber(
      ncrDocumentNo: n['ncrDocumentNo']?.toString(),
      ncrCode: n['ncrCode']?.toString(),
    );
    final plantKey = (n['plantKey'] ?? '').toString().trim();
    final plantLabel = (_plantDisplayName ?? '').trim();
    final plantShow = plantLabel.isNotEmpty
        ? plantLabel
        : (QmsNcrDisplayLabels.isTechnicalPlantKey(plantKey) ? '' : plantKey);
    final orderBiz = QmsNcrDisplayLabels.businessOrNull(
      n['productionOrderId']?.toString(),
    );
    final productBiz = QmsNcrDisplayLabels.businessOrNull(
      n['productId']?.toString(),
    );
    final lotBiz = QmsNcrDisplayLabels.businessOrNull(n['lotId']?.toString());
    final desc = (n['description'] ?? '').toString();
    String? orderFromDesc;
    String? productFromDesc;
    final orderMatch = RegExp(r'Nalog:\s*([^.]*)').firstMatch(desc);
    if (orderMatch != null) {
      orderFromDesc = orderMatch.group(1)?.trim();
    }
    final productMatch = RegExp(r'Proizvod:\s*([^.]*)').firstMatch(desc);
    if (productMatch != null) {
      productFromDesc = productMatch.group(1)?.trim();
    }
    final orderShow = orderBiz ??
        QmsNcrDisplayLabels.businessOrNull(orderFromDesc) ??
        orderFromDesc;
    final productShow = productBiz ??
        QmsNcrDisplayLabels.businessOrNull(productFromDesc) ??
        productFromDesc;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  k,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Neusaglašenost',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (code.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Broj NCR-a',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const QmsAbbrevInfoIcon(
                            term: QmsAbbrevTerm.ncr,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: Text(code)),
                  ],
                ),
              ),
            row(
              'Izvor',
              QmsNcrDisplayLabels.profileSource(_evidenceProfileKey),
            ),
            if (plantShow.isNotEmpty) row('Pogon', plantShow),
            if ((orderShow ?? '').isNotEmpty) row('Proizvodni nalog', orderShow!),
            if ((productShow ?? '').isNotEmpty) row('Proizvod', productShow!),
            if ((lotBiz ?? '').isNotEmpty) row('Lot / serija', lotBiz!),
            if (_evidenceOutcomeKey.isNotEmpty)
              row('Ishod', QmsNcrDisplayLabels.outcome(_evidenceOutcomeKey)),
          ],
        ),
      ),
    );
  }

  Widget _aiRiskExplanationSection() {
    if (!ProductionAccessHelper.canViewNcrActionHistory(_normalizedRole)) {
      return const SizedBox.shrink();
    }
    if (!ProductionModuleKeys.hasAiProductionAnalyticsModule(widget.companyData)) {
      return const SizedBox.shrink();
    }
    return NcrActionRiskAiCard(
      explanation: _aiExplanation,
      loading: _aiExplanationLoading,
      error: _aiExplanationError,
      onRetry: _retryHeavySections,
    );
  }

  Widget _riskBannerSection() {
    if (!ProductionAccessHelper.canViewNcrActionHistory(_normalizedRole)) {
      return const SizedBox.shrink();
    }
    return NcrActionRiskBanner(
      risk: _preparedRiskSignals,
      loading: _historyLoading,
    );
  }

  Widget _actionHistorySection() {
    if (!ProductionAccessHelper.canViewNcrActionHistory(_normalizedRole)) {
      return const SizedBox.shrink();
    }
    return NcrActionHistoryTimeline(
      entries: _historyRows,
      loading: _historyLoading,
      error: _historyError,
      onRetry: _retryHeavySections,
    );
  }

  Widget _closureEvidenceCard() {
    if (!_isClosedRecord) return const SizedBox.shrink();
    final closure = _ncr?['executionClosure'];
    final closureMap = closure is Map ? closure : null;
    final capaKey = closureMap?['capaDecision']?.toString().trim() ?? '';
    String capaLabel = '—';
    for (final e in ncrClosureCapaDecisionOptions) {
      if (e.key == capaKey) {
        capaLabel = e.value;
        break;
      }
    }
    final reasonKey =
        closureMap?['capaNotRequiredReasonKey']?.toString().trim() ?? '';
    String? reasonLabel;
    if (reasonKey.isNotEmpty) {
      for (final e in ncrClosureCapaNotRequiredReasonOptions) {
        if (e.key == reasonKey) {
          reasonLabel = e.value;
          break;
        }
      }
    }
    reasonLabel ??=
        closureMap?['capaNotRequiredReason']?.toString().trim();
    if ((reasonLabel ?? '').isEmpty) {
      final waiver = (_ncr?['capaWaiverReason'] ?? '').toString().trim();
      if (waiver.isNotEmpty) reasonLabel = waiver;
    }
    final closedBy =
        closureMap?['closedByName']?.toString().trim();
    final closedAt = closureMap?['closedAt']?.toString().trim();
    final note = (_ncr?['closureNote'] ?? '').toString().trim();

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  k,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return Card(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zatvaranje neusaglašenosti',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            row('Status', QmsNcrDisplayLabels.status(_status)),
            if ((closedBy ?? '').isNotEmpty) row('Zatvorio', closedBy!),
            if ((closedAt ?? '').isNotEmpty)
              row(
                'Vrijeme zatvaranja',
                NcrActionHodogramLogic.formatDueBs(closedAt!),
              ),
            if (capaLabel != '—') row('CAPA odluka', capaLabel),
            if ((reasonLabel ?? '').isNotEmpty) row('Razlog', reasonLabel!),
            if (note.isNotEmpty) row('Napomena zatvaranja', note),
            if (_attachmentRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Dokaz zatvaranja',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              ..._attachmentRows.map((r) {
                final label = r.label.text.trim();
                final url = r.url.text.trim();
                if (label.isEmpty && url.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file_outlined),
                  title: Text(label.isEmpty ? 'Prilog' : label),
                  trailing: url.isNotEmpty
                      ? IconButton(
                          tooltip: 'Otvori',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => _openUrl(url),
                        )
                      : null,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hodogramTimeline() {
    final ncr = _ncr;
    if (ncr == null) return const SizedBox.shrink();
    final refType = (ncr['referenceType'] ?? '').toString().trim().toLowerCase();
    final fromEvidence = refType == 'production_evidence_session' ||
        _evidenceOutcomeKey.isNotEmpty ||
        _evidenceProfileKey.isNotEmpty;
    final outcomeKey = _evidenceOutcomeKey;
    final outcomeLabel = outcomeKey.isEmpty
        ? null
        : QmsNcrDisplayLabels.outcome(outcomeKey);
    final snap = NcrActionHodogramLogic.build(
      NcrHodogramInput(
        outcomeKey: outcomeKey.isEmpty ? null : outcomeKey,
        outcomeLabel: outcomeLabel == '—' ? null : outcomeLabel,
        containmentAction: _containment.text,
        holdApplied: false,
        ncrCode: QmsNcrDisplayLabels.displayDocumentNumber(
          ncrDocumentNo: ncr['ncrDocumentNo']?.toString(),
          ncrCode: (ncr['ncrCode'] ?? ncr['code'] ?? '').toString(),
        ),
        ncrDocumentNo: ncr['ncrDocumentNo']?.toString(),
        hasNcr: true,
        fromEvidenceSession: fromEvidence,
        nextDispositionActionKey:
            (ncr['nextDispositionActionKey'] ?? '').toString(),
        nextDispositionActionLabel:
            (ncr['nextDispositionActionLabel'] ?? '').toString(),
        nextDispositionOwner: (ncr['nextDispositionOwner'] ?? '').toString(),
        nextDispositionDueAt: (ncr['nextDispositionDueAt'] ?? '').toString(),
        nextDispositionReason: (ncr['nextDispositionReason'] ?? '').toString(),
        nextDispositionRoleLabel:
            (ncr['nextDispositionRoleLabel'] ?? '').toString(),
        nextDispositionPriorityLabel:
            (ncr['nextDispositionPriorityLabel'] ?? '').toString(),
        nextDispositionTask: (ncr['nextDispositionTask'] ?? '').toString(),
        nextDispositionNote: (ncr['nextDispositionNote'] ?? '').toString(),
        nextDispositionPhase: (ncr['nextDispositionPhase'] ?? '').toString(),
        nextDispositionExecutor:
            (ncr['nextDispositionExecutor'] ?? '').toString(),
        nextDispositionExecutorRoleLabel:
            (ncr['nextDispositionExecutorRoleLabel'] ?? '').toString(),
        ncrStatus: _status,
      ),
    );
    return NcrActionHodogramTimeline(
      snapshot: snap,
      onFocusNextAction: () {
        final ctx = _nextActionSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      },
    );
  }

  Widget _nextActionSection() {
    if (_isClosedRecord) {
      return KeyedSubtree(
        key: _nextActionSectionKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sljedeća akcija',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            _executionPanel(),
          ],
        ),
      );
    }

    final existingKey = _nextActionKey;
    final actions = NcrNextDispositionCatalog.actionsForProfile(
      _evidenceProfileKey,
    );
    final body = existingKey != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sljedeća akcija',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              _executionPanel(),
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        () {
                          final label = (_ncr?['nextDispositionActionLabel'] ??
                                  '')
                              .toString()
                              .trim();
                          return label.isNotEmpty
                              ? label
                              : NcrNextDispositionCatalog.labelForKey(
                                  existingKey,
                                );
                        }(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((_ncr?['nextDispositionRoleLabel'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          existingKey == 'send_to_rework'
                              ? 'Odgovorni vlasnik: ${(_ncr?['nextDispositionRoleLabel'] ?? '').toString().trim()}'
                              : 'Odgovorna uloga: ${(_ncr?['nextDispositionRoleLabel'] ?? '').toString().trim()}',
                        ),
                      ],
                      if ((_ncr?['nextDispositionOwner'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          existingKey == 'send_to_rework'
                              ? 'Vlasnik (osoba): ${(_ncr?['nextDispositionOwner'] ?? '').toString().trim()}'
                              : 'Odgovorna osoba: ${(_ncr?['nextDispositionOwner'] ?? '').toString().trim()}',
                        ),
                      ],
                      if (existingKey == 'send_to_rework') ...[
                        const SizedBox(height: 6),
                        Text(
                          'Izvršilac: ${(() {
                            final e = (_ncr?['nextDispositionExecutor'] ?? '')
                                .toString()
                                .trim();
                            return e.isEmpty ? 'Još nije dodijeljen' : e;
                          })()}',
                        ),
                        if ((_ncr?['nextDispositionExecutorRoleLabel'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          Text(
                            'Uloga izvršioca: ${(_ncr?['nextDispositionExecutorRoleLabel'] ?? '').toString().trim()}',
                          ),
                      ],
                      if ((_ncr?['nextDispositionDueAt'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Text(
                          '${existingKey == 'send_to_rework' ? 'Proizvodni rok' : 'Rok'}: ${NcrActionHodogramLogic.formatDueBs((_ncr?['nextDispositionDueAt'] ?? '').toString())}',
                        )
                      else if (existingKey == 'send_to_rework' &&
                          (_ncr?['nextDispositionPhase'] ?? '').toString() ==
                              'awaiting_executor')
                        const Text(
                          'Proizvodni rok: određuje menadžer proizvodnje',
                        ),
                      if ((_ncr?['nextDispositionPriorityLabel'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Text(
                          'Prioritet: ${(_ncr?['nextDispositionPriorityLabel'] ?? '').toString().trim()}',
                        ),
                      if ((_ncr?['nextDispositionTask'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Zadatak: ${(_ncr?['nextDispositionTask'] ?? '').toString().trim()}',
                        ),
                      ] else if ((_ncr?['nextDispositionReason'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          (_ncr?['nextDispositionReason'] ?? '')
                              .toString()
                              .trim(),
                        ),
                      ],
                      if ((_ncr?['nextDispositionNote'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Napomena: ${(_ncr?['nextDispositionNote'] ?? '').toString().trim()}',
                        ),
                      ],
                      if (existingKey == 'send_to_rework' &&
                          (_ncr?['nextDispositionPhase'] ?? '').toString() ==
                              'executor_assigned') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _captureNextDisposition(
                                    NcrNextDispositionAction.sendToRework,
                                  ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Promijeni izvršioca / rok'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Za promjenu akcije odaberi drugu ispod — prethodna se zamjenjuje uz trag.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...actions.map((a) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _captureNextDisposition(a),
                    icon: Icon(a.icon),
                    label: Text(a.labelHr),
                  ),
                );
              }),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sljedeća akcija',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Odaberi unaprijed definisanu akciju. Unosi se odgovorna osoba, rok i obrazloženje — NCR se ne zatvara automatski.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...actions.map((a) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonalIcon(
                    onPressed:
                        _saving ? null : () => _captureNextDisposition(a),
                    icon: Icon(a.icon),
                    label: Text(a.labelHr),
                  ),
                );
              }),
            ],
          );

    return KeyedSubtree(
      key: _nextActionSectionKey,
      child: body,
    );
  }

  Future<void> _applyWmsHoldOnLot() async {
    final lot = _ncrLotIdForHold;
    if (lot == null || _holdingLot) return;
    setState(() => _holdingLot = true);
    try {
      final refId = _ncr?['referenceId']?.toString().trim();
      final refType = _ncr?['referenceType']?.toString().trim().toLowerCase();
      final insId = refType == 'inspection_result' ? refId : null;
      final r = await _svc.applyQmsHoldOnInventoryLot(
        companyId: _cid,
        lotId: lot,
        ncrId: widget.ncrId,
        inspectionResultId: insId,
        sourceType: 'ncr',
      );
      if (!mounted) return;
      if (r.applied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lot zadržan u WMS.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'WMS hold nije primijenjen: ${r.skipReason ?? "nepoznato"}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _holdingLot = false);
    }
  }

  bool _isPartnerClaimNcr(Map<String, dynamic> n) {
    final s = (n['source'] ?? '').toString().toUpperCase();
    return s == 'CUSTOMER' || s == 'SUPPLIER';
  }

  List<Map<String, String>> _buildAttachmentsPayload() {
    final out = <Map<String, String>>[];
    for (final r in _attachmentRows) {
      final label = r.label.text.trim();
      final url = r.url.text.trim();
      if (label.isEmpty && url.isEmpty) continue;
      if (label.isEmpty || url.isEmpty) {
        throw StateError('Svaki prilog mora imati naziv i https URL.');
      }
      if (!url.toLowerCase().startsWith('https://')) {
        throw StateError('URL mora početi s https://');
      }
      out.add({'label': label, 'url': url});
    }
    return out;
  }

  /// IATF: zatvaranje NCR (CLOSED) — sve ne-otkazane CAPA su `closed` s effective (ili waiver).
  bool _ncrCloseCapaChainSatisfied() {
    if (_capaWaiverReason.text.trim().isNotEmpty) return true;
    if (_capaRows.isEmpty) return false;
    final nonCancelled = _capaRows.where(
      (c) => c.status.toLowerCase() != 'cancelled',
    );
    if (nonCancelled.isEmpty) return false;
    for (final c in nonCancelled) {
      final st = c.status.toLowerCase();
      if (st != 'closed') return false;
      final eff = (c.effectivenessResult ?? 'effective').toLowerCase();
      if (eff == 'not_effective') return false;
    }
    return true;
  }

  Future<void> _save() async {
    late final List<Map<String, String>> att;
    try {
      att = _buildAttachmentsPayload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    if (NcrActionHodogramLogic.isNcrClosed(_ncr?['status']?.toString())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Neusaglašenost je već zatvorena. Tok je završen — nema dodatnih akcija.',
          ),
        ),
      );
      return;
    }
    if (_status == 'CLOSED') {
      final execState = NcrExecutionLogic.resolve(
        ncr: _ncr,
        currentUid: _currentUid,
        normalizedRole: _normalizedRole,
      );
      if (execState?.primaryAction == NcrExecutionPrimaryAction.closeNcr) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Za zatvaranje koristi vođeni ekran — dugme „Zatvori neusaglašenost” '
              'u akcionom panelu.',
            ),
          ),
        );
        return;
      }
    }
    if ((_status == 'CLOSED' || _status == 'DISMISSED') && att.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Za status Zatvoreno / Odbačeno potreban je barem jedan prilog (https).',
          ),
        ),
      );
      return;
    }
    if (_status == 'CLOSED' &&
        (_severity == 'HIGH' || _severity == 'CRITICAL') &&
        !_ncrCloseCapaChainSatisfied()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visoka/kritična ozbiljnost: zatvoreni lanac — sve ne-otkazane CAPA zatvorene s učinkovitošću, '
            'ili unesi odstupanje uz odobrenje.',
          ),
        ),
      );
      return;
    }
    if (_status == 'CLOSED' &&
        (_severity == 'LOW' || _severity == 'MEDIUM') &&
        _reactionPlan.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Niska/srednja ozbiljnost: pri zatvaranju unesi reakcijski plan (zapis o zatvaranju / što je učinjeno).',
          ),
        ),
      );
      return;
    }

    final whyLines = _fiveWhy.text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (whyLines.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('5 zašto: najviše 5 koraka (suzite retke u polju).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _svc.updateQmsNonConformance(
        companyId: _cid,
        ncrId: widget.ncrId,
        status: _status,
        containmentAction: _containment.text,
        reactionPlan: _reactionPlan.text,
        description: _description.text,
        severity: _severity,
        attachments: att,
        capaWaiverReason: (_severity == 'HIGH' || _severity == 'CRITICAL')
            ? _capaWaiverReason.text.trim()
            : '',
        sourceModule: _sourceModule,
        fiveWhySteps: whyLines.isEmpty ? const [] : whyLines,
      );
      if (!mounted) return;
      final auto = res['capaAutoCreated'] == true;
      final idCapa = res['actionPlanId']?.toString();
      if (auto && idCapa != null && idCapa.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'NCR spremljen. Automatski je otvorena CAPA za ovaj NCR.',
            ),
            action: SnackBarAction(
              label: 'Otvori CAPA',
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CapaDetailScreen(
                      companyData: widget.companyData,
                      actionPlanId: idCapa,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('NCR je spremljen.')));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null) return;
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _createCapa() async {
    final titleCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova korektivna/preventivna mjera'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Naslov *',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kreiraj'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    try {
      final id = await _svc.createQmsCapaForNcr(
        companyId: _cid,
        ncrId: widget.ncrId,
        title: title,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CapaDetailScreen(
            companyData: widget.companyData,
            actionPlanId: id,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neusaglašenost'),
        actions: [
          if (!_loading && _error == null && _ncr != null)
            OperonixAiAskAssistantAppBarAction(
              companyData: widget.companyData,
              entityBinding: _ncrAiChatBinding(),
            ),
          if (!_loading && _error == null && !_isClosedRecord)
            IconButton(
              tooltip: 'Nova korektivna/preventivna mjera',
              icon: const Icon(Icons.add),
              onPressed: _createCapa,
            ),
          IconButton(
            tooltip: 'Metodologija · IATF',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const QmsMethodologyReferenceScreen(),
                ),
              );
            },
          ),
          QmsIatfInfoIcon(
            title: 'Neusaglašenost',
            message: QmsIatfStrings.detailNcr,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_ncr != null) ...[
                    _businessContextCard(),
                    if (_isPartnerClaimNcr(_ncr!)) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_ncr!['source'] ?? '')
                                            .toString()
                                            .toUpperCase() ==
                                        'CUSTOMER'
                                    ? 'Kupac'
                                    : 'Dobavljač',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (_ncr!['partnerDisplayName'] ?? '')
                                        .toString()
                                        .isEmpty
                                    ? '—'
                                    : (_ncr!['partnerDisplayName'] ?? '')
                                          .toString(),
                              ),
                              if ((_ncr!['externalClaimRef'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Vanjski broj: ${_ncr!['externalClaimRef']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _hodogramTimeline(),
                    const SizedBox(height: 12),
                    _aiRiskExplanationSection(),
                    const SizedBox(height: 12),
                    _riskBannerSection(),
                    const SizedBox(height: 16),
                    _actionHistorySection(),
                    const SizedBox(height: 16),
                    _closureEvidenceCard(),
                    if (_isClosedRecord) const SizedBox(height: 16),
                    _nextActionSection(),
                    const SizedBox(height: 16),
                    if (!_isClosedRecord) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ncr_st_$_status'),
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(QmsNcrDisplayLabels.status(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ncr_sev_$_severity'),
                      initialValue: _severity,
                      decoration: InputDecoration(
                        labelText: 'Ozbiljnost',
                        border: const OutlineInputBorder(),
                        suffixIcon: QmsIatfInfoIcon(
                          title: 'Ozbiljnost',
                          message: QmsIatfStrings.termSeverity,
                          size: 20,
                        ),
                      ),
                      items: _severities
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(QmsNcrDisplayLabels.severity(s)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _severity = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_severity == 'HIGH' || _severity == 'CRITICAL') ...[
                      TextFormField(
                        controller: _capaWaiverReason,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Odstupanje uz odobrenje',
                          hintText:
                              'Ako ne možeš zatvoriti sve CAPA s pozitivnom verifikacijom',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          suffixIcon: QmsIatfInfoIcon(
                            title: 'Visoka / kritična ozbiljnost',
                            message: QmsIatfStrings.termCapaGateHighSeverity,
                            size: 20,
                          ),
                        ),
                      ),
                      if (!_ncrCloseCapaChainSatisfied() &&
                          _capaWaiverReason.text.trim().isEmpty &&
                          _status == 'CLOSED')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Za zatvaranje neusaglašenosti potrebno je dodati '
                            'dokaz zatvaranja i odabrati CAPA odluku. Koristi '
                            'dugme „Zatvori neusaglašenost” u akcionom panelu.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    QmsIatfSectionTitle(
                      label: 'Mjera zadržavanja',
                      iatfTitle: 'Mjera zadržavanja',
                      iatfMessage: QmsIatfStrings.termContainment,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _containment,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QmsIatfSectionTitle(
                      label: 'Plan brze reakcije',
                      iatfTitle: 'Plan brze reakcije',
                      iatfMessage: QmsIatfStrings.termReactionPlan,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reactionPlan,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ncr_src_$_sourceModule'),
                      initialValue: _sourceModules.containsKey(_sourceModule)
                          ? _sourceModule
                          : '',
                      decoration: const InputDecoration(
                        labelText: 'Modul izvora (IATF sljedljivost)',
                        border: OutlineInputBorder(),
                      ),
                      items: _sourceModules.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _sourceModule = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    QmsIatfSectionTitle(
                      label: '5 zašto (sažetak koraka)',
                      iatfTitle: '5 zašto',
                      iatfMessage:
                          'Učitaj korake po retku (najviše 5). Potpuna analiza ostaje u CAPA / 8D.',
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _fiveWhy,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Zašto?\nZašto?\n…',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            () {
                              final lot = QmsNcrDisplayLabels.businessOrNull(
                                _ncr!['lotId']?.toString(),
                              );
                              final order = QmsNcrDisplayLabels.businessOrNull(
                                _ncr!['productionOrderId']?.toString(),
                              );
                              final parts = <String>[
                                'Lot / serija: ${lot ?? '—'}',
                                if (order != null) 'Nalog: $order',
                              ];
                              return parts.join(' · ');
                            }(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        QmsIatfInfoIcon(
                          title: 'Lot i sljedljivost',
                          message:
                              '${QmsIatfStrings.termLot}\n\n${QmsIatfStrings.termTraceability}',
                          size: 20,
                        ),
                      ],
                    ),
                    if (_hasLogisticsModule() &&
                        (_ncrLotIdForHold ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: _holdingLot ? null : _applyWmsHoldOnLot,
                          icon: _holdingLot
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.pause_circle_outline),
                          label: const Text('Zadrži lot u WMS'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Prilozi (naziv + https URL)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Za Zatvoreno ili Odbačeno potreban je barem jedan prilog. '
                      'Učitaj datoteku u Storage ili drugi sustav i zalijepi javni https link.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _attachmentRows.add(_NcrAttRow()));
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Dodaj red priloga'),
                    ),
                    ..._attachmentRows.asMap().entries.map((e) {
                      final i = e.key;
                      final r = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: r.label,
                                decoration: const InputDecoration(
                                  labelText: 'Naziv',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: r.url,
                                decoration: const InputDecoration(
                                  labelText: 'https://…',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Otvori u pregledniku',
                              onPressed: () {
                                final u = r.url.text.trim();
                                if (u.isNotEmpty) _openUrl(u);
                              },
                              icon: const Icon(Icons.open_in_new),
                            ),
                            IconButton(
                              tooltip: 'Ukloni',
                              onPressed: () {
                                setState(() {
                                  r.dispose();
                                  _attachmentRows.removeAt(i);
                                });
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving ? 'Spremanje…' : 'Spremi neusaglašenost',
                      ),
                    ),
                    const SizedBox(height: 32),
                    ] else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Neusaglašenost je zatvorena — operativni tok se ne mijenja. '
                            'Pregledajte hodogram, dokaz zatvaranja i povezane CAPA zapise.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Povezane korektivne/preventivne mjere',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_capaLoading)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(minHeight: 2),
                              SizedBox(height: 10),
                              Text('Učitavanje povezanih mjera…'),
                            ],
                          ),
                        ),
                      )
                    else if (_capaRows.isEmpty)
                      Text(
                        'Nema zapisa. Koristi „Nova korektivna/preventivna mjera” '
                        'ili prijelaz u status U pregledu / Zadržano za automatsko otvaranje.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ..._capaRows.map((r) {
                        return Card(
                          child: ListTile(
                            title: Text(
                              r.title.isEmpty
                                  ? 'Korektivna/preventivna mjera'
                                  : r.title,
                            ),
                            subtitle: Text(_capaStatusLabel(r.status)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CapaDetailScreen(
                                    companyData: widget.companyData,
                                    actionPlanId: r.id,
                                  ),
                                ),
                              );
                              await _load();
                            },
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
    );
  }
}
