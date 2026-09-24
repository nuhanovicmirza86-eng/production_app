import 'package:flutter/material.dart';

import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/ai/models/operonix_ai_entity_chat_binding.dart';
import '../../../modules/production/ai/widgets/operonix_ai_assistant_navigator.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../../modules/quality/screens/ncr_detail_screen.dart';
import '../../../modules/quality/services/quality_callable_service.dart';
import '../../../modules/quality/utils/ncr_next_disposition_catalog.dart';
import '../../../modules/quality/utils/qms_ncr_display_labels.dart';
import '../../../modules/quality/widgets/ncr_action_hodogram_model.dart';
import '../../../modules/quality/widgets/ncr_action_hodogram_timeline.dart';
import '../../../modules/quality/widgets/qms_iatf_help.dart';
import '../../catalog_evidence_runtime/utils/line_clearance_line_name.dart';
import '../../catalog_evidence_runtime/utils/line_clearance_verification.dart';
import '../../catalog_evidence_runtime/utils/omp_material_lot_source_display.dart';
import '../../catalog_evidence_runtime/utils/operator_evidence_ux_standard.dart';
import '../../profile_driven_structured_runtime/utils/structured_piece_quantity.dart';
import '../../../modules/production/bom/bom_item_traceability.dart';
import '../export/first_piece_approval_pdf_actions.dart';
import '../export/final_control_record_pdf_actions.dart';
import '../export/in_process_quality_check_record_pdf_actions.dart';
import '../export/operation_material_preparation_record_pdf_actions.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import '../utils/evidence_order_context_display.dart';
import '../utils/evidence_detail_handoff.dart';
import '../utils/profile_driven_evidence_detail_display.dart';
import '../utils/profile_driven_evidence_rework_labels.dart';
import '../widgets/evidence_order_routing_context_card.dart';
import '../widgets/profile_driven_evidence_structured_table.dart';
import '../widgets/qms_controlled_form_help.dart';

/// M2-C — read-only detalj zatvorene profile-driven evidencije.
class ProfileDrivenEvidenceDetailScreen extends StatefulWidget {
  const ProfileDrivenEvidenceDetailScreen({
    super.key,
    required this.companyData,
    required this.sessionId,
  });

  final Map<String, dynamic> companyData;
  final String sessionId;

  @override
  State<ProfileDrivenEvidenceDetailScreen> createState() =>
      _ProfileDrivenEvidenceDetailScreenState();
}

class _ProfileDrivenEvidenceDetailScreenState
    extends State<ProfileDrivenEvidenceDetailScreen> {
  final _service = ProfileDrivenEvidenceCallableService();
  final _firstPiecePdfActions = FirstPieceApprovalPdfActions();
  final _inProcessPdfActions = InProcessQualityCheckRecordPdfActions();
  final _finalControlPdfActions = FinalControlRecordPdfActions();
  final _operationMaterialPrepPdfActions =
      OperationMaterialPreparationRecordPdfActions();

  bool _loading = true;
  bool _pdfBusy = false;
  Object? _error;
  ProfileDrivenEvidenceSessionDetail? _session;
  List<ProductionEvidenceAuditItem> _auditItems = const [];
  Object? _auditError;
  String? _plantLabel;
  final _qualitySvc = QualityCallableService();
  Map<String, dynamic>? _outcomeNcrSummary;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _service.getProfileDrivenEvidenceSession(
        companyId: _companyId,
        sessionId: widget.sessionId,
      );
      String? plantLabel;
      if (session.plantKey.isNotEmpty) {
        plantLabel = await CompanyPlantDisplayName.resolve(
          companyId: _companyId,
          plantKey: session.plantKey,
        );
      }
      Map<String, dynamic>? ncrSummary;
      final ncrId = (session.outcomeNcrId ?? '').trim();
      if (ncrId.isNotEmpty) {
        try {
          ncrSummary = await _qualitySvc.getQmsNonConformanceMap(
            companyId: _companyId,
            ncrId: ncrId,
          );
        } catch (_) {
          ncrSummary = null;
        }
      }
      var auditItems = const <ProductionEvidenceAuditItem>[];
      Object? auditError;
      try {
        auditItems = await _service.listProductionEvidenceSessionAuditTrail(
          companyId: _companyId,
          sessionId: widget.sessionId,
        );
      } catch (e) {
        auditError = e;
        auditItems = const [];
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _plantLabel = plantLabel;
        _outcomeNcrSummary = ncrSummary;
        _auditItems = auditItems;
        _auditError = auditError;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<ProductionStationProfileField> get _fieldDefs {
    final session = _session;
    if (session == null) return const [];
    return ProductionStationProfileField.sortedList(
      session.profileFieldDefs.map(ProductionStationProfileField.fromMap),
    );
  }

  List<ProductionStationProfileField> get _operatorFields =>
      _fieldDefs.where((f) => f.isOperatorEditable).toList(growable: false);

  List<ProductionStationProfileField> get _operatorFieldsForDisplay {
    final isOmp = (_session?.processProfileType ?? '').trim() ==
        'operation_material_preparation';
    return _operatorFields
        .where((field) => !profileEvidenceShouldHideDetailFieldKey(field.key))
        // M1-I11-B/C — lot + klasifikacija u sekciji „Lot / sljedivost”.
        .where(
          (field) =>
              !isOmp ||
              (field.key != 'materialLot' &&
                  field.key != 'materialLotSource' &&
                  field.key != 'inventoryLotDocId' &&
                  field.key != ompBomItemKindSnapshot &&
                  field.key != ompTraceabilityModeSnapshot &&
                  field.key != ompLotRequiredSnapshot),
        )
        .where((field) {
          if (field.key != lineClearanceLineNameFieldKey) return true;
          return isLineClearanceLineNameFallbackVisible(
            fieldValues: _session?.fieldValues,
          );
        })
        .where((field) {
          final profile = (_session?.processProfileType ?? '').trim();
          if (profile == lineClearanceProfileKey) {
            if (lineClearanceHiddenOrderFieldKeys.contains(field.key)) {
              return false;
            }
          }
          return field.isVisibleGiven(
            fieldValues: _session?.fieldValues ?? const {},
            enumSelections: const {},
          );
        })
        .toList(growable: false);
  }

  List<ProductionStationProfileField> get _masterDataFieldsForDisplay =>
      _fieldDefs
          .where(profileEvidenceShouldShowMasterSnapshotField)
          .toList(growable: false);

  String _displayValueForField(ProductionStationProfileField field) {
    final session = _session;
    if (session == null) return '—';
    return profileEvidenceDetailFieldDisplayValue(
      field: field,
      session: session,
    );
  }

  String _displayLabel(ProductionStationProfileField field) =>
      profileEvidenceDetailFieldLabel(field);

  String _plantDisplayLabel(ProfileDrivenEvidenceSessionDetail session) {
    final label = (_plantLabel ?? '').trim();
    if (label.isNotEmpty &&
        !QmsNcrDisplayLabels.isTechnicalPlantKey(label)) {
      return label;
    }
    final key = session.plantKey.trim();
    if (key.isEmpty) return '—';
    if (QmsNcrDisplayLabels.isTechnicalPlantKey(key)) return '—';
    if (profileEvidenceLooksLikeInternalDocumentId(key)) return '—';
    return key;
  }

  bool get _canExportFirstPiecePdf {
    final s = _session;
    if (s == null) return false;
    return s.processProfileType == 'first_piece_approval' &&
        s.status.trim().toLowerCase() == 'closed';
  }

  bool get _canExportInProcessRecordPdf {
    final s = _session;
    if (s == null) return false;
    return s.processProfileType == 'in_process_quality_check' &&
        s.status.trim().toLowerCase() == 'closed';
  }

  bool get _canExportFinalControlRecordPdf {
    final s = _session;
    if (s == null) return false;
    return s.processProfileType == 'final_control' &&
        s.status.trim().toLowerCase() == 'closed';
  }

  bool get _canExportOperationMaterialPrepPdf {
    final s = _session;
    if (s == null) return false;
    return s.processProfileType == 'operation_material_preparation' &&
        s.status.trim().toLowerCase() == 'closed';
  }

  Future<void> _runEvidencePdf(
    Future<void> Function() action,
  ) async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await action();
      try {
        await _service.recordProductionEvidencePdfGenerated(
          companyId: _companyId,
          sessionId: widget.sessionId,
        );
        final items = await _service.listProductionEvidenceSessionAuditTrail(
          companyId: _companyId,
          sessionId: widget.sessionId,
        );
        if (mounted) setState(() => _auditItems = items);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileDrivenEvidenceErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  String get _plantLabelForPdf {
    final label = (_plantLabel ?? '').trim();
    if (label.isNotEmpty &&
        !QmsNcrDisplayLabels.isTechnicalPlantKey(label)) {
      return label;
    }
    final key = (_session?.plantKey ?? '').trim();
    if (key.isEmpty ||
        QmsNcrDisplayLabels.isTechnicalPlantKey(key) ||
        profileEvidenceLooksLikeInternalDocumentId(key)) {
      return '—';
    }
    return key;
  }

  String _sessionStatusLabel(ProfileDrivenEvidenceSessionDetail session) {
    return EvidenceDetailHandoff.statusLabelFor(session);
  }

  Widget _predajaIVerifikacijaSection(
    ProfileDrivenEvidenceSessionDetail session,
  ) {
    final savedBy = EvidenceDetailHandoff.performedByName(
      fieldValues: session.fieldValues,
      auditItems: _auditItems,
    );
    final verifiedBy = EvidenceDetailHandoff.verifiedByName(
      fieldValues: session.fieldValues,
      auditItems: _auditItems,
    );
    return _sectionCard(
      title: EvidenceDetailHandoff.sectionTitle,
      children: [
        _kvRow(
          EvidenceDetailHandoff.performedByLabel,
          savedBy.isEmpty ? '—' : savedBy,
        ),
        _kvRow(
          EvidenceDetailHandoff.performedAtLabel,
          formatEvidenceDateTime(
            EvidenceDetailHandoff.performedAt(auditItems: _auditItems),
          ),
        ),
        _kvRow(
          EvidenceDetailHandoff.verifiedByLabel,
          verifiedBy.isEmpty ? '—' : verifiedBy,
        ),
        _kvRow(
          EvidenceDetailHandoff.verifiedAtLabel,
          formatEvidenceDateTime(
            EvidenceDetailHandoff.verifiedAt(
              session: session,
              auditItems: _auditItems,
            ),
          ),
        ),
        _kvRow(
          EvidenceDetailHandoff.statusLabel,
          _sessionStatusLabel(session),
        ),
        if (session.processProfileType.trim() == lineClearanceProfileKey) ...[
          _kvRow(
            lineClearanceSiteConditionCheckedLabel,
            formatEvidenceYesNoOrDash(
              session.fieldValues[lineClearanceSiteConditionCheckedKey],
            ),
          ),
          _kvRow(
            lineClearanceReadyForWorkLabel,
            formatEvidenceYesNoOrDash(
              session.fieldValues[lineClearanceReadyForWorkKey],
            ),
          ),
          if ((session.fieldValues[lineClearanceReadinessCorrectionKey] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
            _kvRow(
              lineClearanceReadinessCorrectionLabel,
              session.fieldValues[lineClearanceReadinessCorrectionKey]
                  .toString()
                  .trim(),
            ),
        ],
      ],
    );
  }

  Widget _evidenceAuditTrailSection() {
    if (_auditError != null) {
      return _sectionCard(
        title: 'Historija i audit trag',
        children: [
          const Text('Historija nije učitana. Pokušajte ponovo.'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _load,
              child: const Text('Pokušaj ponovo'),
            ),
          ),
        ],
      );
    }
    if (_auditItems.isEmpty) {
      return _sectionCard(
        title: 'Historija i audit trag',
        children: const [
          Text('Još nema zabilježenih radnji za ovu evidenciju.'),
        ],
      );
    }
    return _sectionCard(
      title: 'Historija i audit trag',
      children: [
        for (var i = 0; i < _auditItems.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          _auditTrailRow(_auditItems[i]),
        ],
      ],
    );
  }

  String _bsAuditVisibleText(String raw) {
    return raw.replaceAll(RegExp(r'\bOperator\b'), 'Operater');
  }

  Widget _auditTrailRow(ProductionEvidenceAuditItem item) {
    final name = item.performedByName.trim().isEmpty
        ? 'Korisnik'
        : item.performedByName.trim();
    final role = _bsAuditVisibleText(item.performedByRoleLabel.trim());
    final when = formatEvidenceDateTime(item.performedAt);
    final rawTitle = item.actionLabel.trim().isNotEmpty
        ? item.actionLabel.trim()
        : item.summary;
    final title = _bsAuditVisibleText(rawTitle);
    final summary = _bsAuditVisibleText(item.summary.trim());
    if (EvidenceDetailHandoff.looksLikeInternalEvidenceText(name) ||
        EvidenceDetailHandoff.looksLikeInternalEvidenceText(title) ||
        EvidenceDetailHandoff.looksLikeInternalEvidenceText(summary)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          role.isEmpty ? name : '$name · $role',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          when,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (summary.isNotEmpty && summary != title)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kvRow(
    String label,
    String value, {
    QmsAbbrevTerm? abbrev,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ),
                if (abbrev != null)
                  QmsAbbrevInfoIcon(term: abbrev, size: 16),
              ],
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _fieldSection(
    String title,
    List<ProductionStationProfileField> fields,
  ) {
    if (fields.isEmpty) {
      return _sectionCard(
        title: title,
        children: const [Text('Nema podataka za prikaz.')],
      );
    }

    return _sectionCard(
      title: title,
      children: fields.map((field) {
        return _kvRow(
          _displayLabel(field),
          _displayValueForField(field),
        );
      }).toList(),
    );
  }

  Widget _buildOutcomeActionCard(ProfileDrivenEvidenceSessionDetail session) {
    if (!session.hasOutcomeNcr) return const SizedBox.shrink();
    final ncrCode = (session.outcomeNcrCode ?? '').trim();
    final label = (session.outcomeLabel ?? '').trim();
    final containment = (session.outcomeContainmentAction ?? '').trim();
    final holdApplied = session.outcomeHoldApplied;
    final holdSkip = (session.outcomeHoldSkipReason ?? '').trim();
    final ncr = _outcomeNcrSummary;
    final nextKey = (ncr?['nextDispositionActionKey'] ?? '').toString().trim();
    final nextLabel = (ncr?['nextDispositionActionLabel'] ?? '').toString().trim();
    final nextOwner = (ncr?['nextDispositionOwner'] ?? '').toString().trim();
    final nextDue = (ncr?['nextDispositionDueAt'] ?? '').toString().trim();
    final nextReason = (ncr?['nextDispositionReason'] ?? '').toString().trim();
    final nextRole =
        (ncr?['nextDispositionRoleLabel'] ?? '').toString().trim();
    final nextPriority =
        (ncr?['nextDispositionPriorityLabel'] ?? '').toString().trim();
    final nextTask = (ncr?['nextDispositionTask'] ?? '').toString().trim();
    final nextNote = (ncr?['nextDispositionNote'] ?? '').toString().trim();
    final actions = NcrNextDispositionCatalog.actionsForProfile(
      session.processProfileType,
    );

    return _sectionCard(
      title: 'Neusaglašenost',
      children: [
        NcrActionHodogramTimeline(
          snapshot: NcrActionHodogramLogic.build(
            NcrHodogramInput(
              outcomeKey: (session.outcomeKey ?? '').trim().isEmpty
                  ? null
                  : session.outcomeKey,
              outcomeLabel: label.isEmpty ? null : label,
              containmentAction: containment.isEmpty ? null : containment,
              holdApplied: holdApplied,
              holdSkipReason: holdSkip.isEmpty ? null : holdSkip,
              ncrCode: ncrCode.isEmpty ? null : ncrCode,
              hasNcr: true,
              fromEvidenceSession: true,
              nextDispositionActionKey: nextKey.isEmpty ? null : nextKey,
              nextDispositionActionLabel:
                  nextLabel.isEmpty ? null : nextLabel,
              nextDispositionOwner: nextOwner.isEmpty ? null : nextOwner,
              nextDispositionDueAt: nextDue.isEmpty ? null : nextDue,
              nextDispositionReason: nextReason.isEmpty ? null : nextReason,
              nextDispositionRoleLabel: nextRole.isEmpty ? null : nextRole,
              nextDispositionPriorityLabel:
                  nextPriority.isEmpty ? null : nextPriority,
              nextDispositionTask: nextTask.isEmpty ? null : nextTask,
              nextDispositionNote: nextNote.isEmpty ? null : nextNote,
              nextDispositionPhase: (ncr?['nextDispositionPhase'] ?? '')
                      .toString()
                      .trim()
                      .isEmpty
                  ? null
                  : (ncr?['nextDispositionPhase'] ?? '').toString(),
              nextDispositionExecutor:
                  (ncr?['nextDispositionExecutor'] ?? '').toString().trim().isEmpty
                      ? null
                      : (ncr?['nextDispositionExecutor'] ?? '').toString(),
              nextDispositionExecutorRoleLabel:
                  (ncr?['nextDispositionExecutorRoleLabel'] ?? '')
                          .toString()
                          .trim()
                          .isEmpty
                      ? null
                      : (ncr?['nextDispositionExecutorRoleLabel'] ?? '')
                          .toString(),
              ncrStatus: (ncr?['status'] ?? '').toString(),
            ),
          ),
          onFocusNextAction: () => _openNcrForNextAction(session, null),
          compact: true,
        ),
        const SizedBox(height: 12),
        if (ncrCode.isNotEmpty)
          _kvRow('Broj NCR-a', ncrCode, abbrev: QmsAbbrevTerm.ncr),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          _kvRow('Ishod', label),
        ],
        if (containment.isNotEmpty) ...[
          const SizedBox(height: 8),
          _kvRow('Mjera zadržavanja', containment),
        ],
        if (holdApplied) ...[
          const SizedBox(height: 4),
          _kvRow(
            'Zadržavanje lota (WMS)',
            'Primijenjeno',
            abbrev: QmsAbbrevTerm.wms,
          ),
        ] else if (holdSkip.isNotEmpty) ...[
          const SizedBox(height: 4),
          _kvRow(
            'Zadržavanje lota (WMS)',
            holdSkip == 'lot_not_provided'
                ? 'Nije primijenjeno (nema lota na evidenciji)'
                : 'Nije primijenjeno',
            abbrev: QmsAbbrevTerm.wms,
          ),
        ],
        if (nextKey.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Sljedeća akcija',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          _kvRow(
            'Akcija',
            nextLabel.isNotEmpty
                ? nextLabel
                : NcrNextDispositionCatalog.labelForKey(nextKey),
          ),
          if (nextRole.isNotEmpty) _kvRow('Odgovorna uloga', nextRole),
          if (nextOwner.isNotEmpty) _kvRow('Odgovorna osoba', nextOwner),
          if (nextDue.isNotEmpty)
            _kvRow('Rok', NcrActionHodogramLogic.formatDueBs(nextDue)),
          if (nextPriority.isNotEmpty) _kvRow('Prioritet', nextPriority),
          if (nextTask.isNotEmpty)
            _kvRow('Zadatak', nextTask)
          else if (nextReason.isNotEmpty)
            _kvRow('Obrazloženje', nextReason),
          if (nextNote.isNotEmpty) _kvRow('Napomena', nextNote),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'Preporučene akcije',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Odaberi unaprijed definisanu akciju. '
                  'Otvara se unos u neusaglašenosti — zapis se ne zatvara automatski.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const QmsAbbrevInfoIcon(term: QmsAbbrevTerm.ncr, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          ...actions.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => _openNcrForNextAction(session, a),
                icon: Icon(a.icon),
                label: Text(a.labelHr),
              ),
            );
          }),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _openNcrForNextAction(session, null),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Otvori neusaglašenost u QMS'),
            ),
            const QmsAbbrevInfoIcon(term: QmsAbbrevTerm.qms, size: 18),
          ],
        ),
      ],
    );
  }

  Future<void> _openNcrForNextAction(
    ProfileDrivenEvidenceSessionDetail session,
    NcrNextDispositionAction? preferred,
  ) async {
    final ncrId = (session.outcomeNcrId ?? '').trim();
    if (ncrId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NcrDetailScreen(
          companyData: widget.companyData,
          ncrId: ncrId,
          preferredNextAction: preferred,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Widget _orderRoutingContextSection(ProfileDrivenEvidenceSessionDetail session) {
    final snap = session.orderSnapshot;
    if (snap == null) return const SizedBox.shrink();
    return EvidenceOrderRoutingContextCard(snapshot: snap);
  }

  Widget _buildBody(ProfileDrivenEvidenceSessionDetail session) {
    if (session.isReworkAndPainting) {
      return _buildReworkBody(session);
    }
    if (session.isPackagingControl) {
      return _buildPackagingBody(session);
    }
    if (session.isInProcessQualityCheck) {
      return _buildInProcessQualityBody(session);
    }
    if (session.isFinalControl) {
      return _buildFinalControlBody(session);
    }
    return _buildFlatProfileBody(session);
  }

  bool get _showQmsMarkingBanner {
    final s = _session;
    if (s == null) return false;
    const keys = {
      'first_piece_approval',
      'packaging_control',
      'in_process_quality_check',
      'final_control',
      'operation_material_preparation',
    };
    return keys.contains(s.processProfileType.trim());
  }

  Widget _qmsMarkingBannerIfNeeded(ProfileDrivenEvidenceSessionDetail session) {
    if (!_showQmsMarkingBanner) return const SizedBox.shrink();
    return QmsControlledFormMarkingBanner(fieldValues: session.fieldValues);
  }

  String _formatQtyInt(num? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return formatFieldValue(value);
  }

  String _formatQtyWithUnit(num? value, String? unit) {
    final qty = _formatQtyInt(value);
    if (qty == '—') return '—';
    final u = (unit ?? '').trim();
    return u.isEmpty ? qty : '$qty $u';
  }

  Widget _buildInProcessQualityBody(ProfileDrivenEvidenceSessionDetail session) {
    final station =
        (session.stationDisplayName ?? '').trim().isNotEmpty
            ? session.stationDisplayName!
            : (session.stationSlot != null
                  ? 'Stanica ${session.stationSlot}'
                  : '—');
    final s = session.summaryFields;
    final lines = session.inspectionLines;
    final unit = (s.unit ?? '').trim();
    final productCtx = _resolveInProcessProductContext(session);
    final orderCode = (s.productionOrderCode ??
            session.fieldValues['productionOrderCode'] ??
            '')
        .toString()
        .trim();
    final workContextRaw =
        (session.fieldValues['workContextType'] ?? '').toString().trim();
    final workContextLabel = workContextRaw == 'machine'
        ? 'Mašina'
        : workContextRaw == 'workbench'
            ? 'Radni sto'
            : (workContextRaw.isEmpty ? '—' : workContextRaw);
    final machineName =
        (session.fieldValues['machineNameSnapshot'] ?? '').toString().trim();
    final workbenchName =
        (session.fieldValues['workbenchNameSnapshot'] ?? '').toString().trim();
    final workLocation =
        (session.fieldValues['workLocationNameSnapshot'] ?? '')
            .toString()
            .trim();

    return ListView(
      children: [
        _orderRoutingContextSection(session),
        _qmsMarkingBannerIfNeeded(session),
        _buildOutcomeActionCard(session),
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', _sessionStatusLabel(session)),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
          ],
        ),
        _predajaIVerifikacijaSection(session),
        _evidenceAuditTrailSection(),
        _sectionCard(
          title: 'Proizvodni kontekst',
          children: [
            _kvRow(
              'Proizvodni nalog',
              orderCode.isEmpty ? '—' : orderCode,
            ),
            _kvRow('Proizvod', productCtx.displayName),
            _kvRow('Šifra proizvoda', productCtx.code),
            _kvRow('Naziv proizvoda', productCtx.name),
            _kvRow(
              'Operacija',
              EvidenceOrderContextDisplay.operationStepLabelForEvidenceDetail(
                session.orderSnapshot,
              ),
            ),
            _kvRow('Mjesto rada', workContextLabel),
            if (workContextRaw == 'machine' || machineName.isNotEmpty)
              _kvRow(
                'Mašina',
                machineName.isNotEmpty
                    ? machineName
                    : (workLocation.isNotEmpty ? workLocation : '—'),
              ),
            if (workContextRaw == 'workbench' || workbenchName.isNotEmpty)
              _kvRow(
                'Radni sto',
                workbenchName.isNotEmpty
                    ? workbenchName
                    : (workLocation.isNotEmpty ? workLocation : '—'),
              ),
            if (workContextRaw.isEmpty &&
                machineName.isEmpty &&
                workbenchName.isEmpty &&
                workLocation.isNotEmpty)
              _kvRow('Lokacija rada', workLocation),
          ],
        ),
        _sectionCard(
          title: 'Kontrola',
          children: [
            _kvRow(
              'Operater kvaliteta',
              (s.operatorSummary ??
                      session.fieldValues['inspectorNameSnapshot'] ??
                      '')
                  .toString()
                  .trim()
                  .isEmpty
                  ? '—'
                  : (s.operatorSummary ??
                          session.fieldValues['inspectorNameSnapshot'])
                      .toString()
                      .trim(),
            ),
            _kvRow(
              'Proizvodni operater',
              (s.packagingOperatorName ??
                      session.fieldValues['productionOperatorNameSnapshot'] ??
                      '')
                  .toString()
                  .trim()
                  .isEmpty
                  ? '—'
                  : (s.packagingOperatorName ??
                          session.fieldValues['productionOperatorNameSnapshot'])
                      .toString()
                      .trim(),
            ),
            ..._operatorFieldsForDisplay.map((field) {
              // Header kontekst i osobe su već gore / u Proizvodnom kontekstu.
              if (field.key == 'workCenterId' ||
                  field.key == 'inspectorEmployeeId' ||
                  field.key == 'productionOperatorEmployeeId' ||
                  field.key == 'productionOrderId' ||
                  field.key == 'workContextType' ||
                  field.key == 'machineId' ||
                  field.key == 'workbenchId') {
                return const SizedBox.shrink();
              }
              return _kvRow(
                _displayLabel(field),
                _displayValueForField(field),
              );
            }),
          ],
        ),
        _sectionCard(
          title: 'Kontrolisane količine',
          children: [
            _kvRow(
              'Ukupno kontrolisano',
              _formatQtyWithUnit(s.quantity, unit),
            ),
            _kvRow(
              'Ukupno prolazi',
              _formatQtyWithUnit(s.okTotalQty, unit),
            ),
            _kvRow(
              'Ukupno ne prolazi',
              _formatQtyWithUnit(s.scrapTotalQty, unit),
            ),
            if (unit.isNotEmpty) _kvRow('Jedinica', unit),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nema redova kontrolnih tačaka.'),
              ),
          ],
        ),
        if (lines.isNotEmpty)
          _sectionCard(
            title: 'Kontrolne tačke',
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _buildInspectionLineTile(index: i + 1, row: lines[i]),
              ],
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFinalControlBody(ProfileDrivenEvidenceSessionDetail session) {
    final station =
        (session.stationDisplayName ?? '').trim().isNotEmpty
            ? session.stationDisplayName!
            : (session.stationSlot != null
                  ? 'Stanica ${session.stationSlot}'
                  : '—');
    final s = session.summaryFields;
    final lines = session.controlledItems;
    final unit = (s.unit ?? '').trim();
    final productCtx = _resolveFinalControlProductContext(session);
    final orderCode = (s.productionOrderCode ??
            session.fieldValues['productionOrderCode'] ??
            '')
        .toString()
        .trim();
    final dispositionRaw =
        (session.fieldValues['finalDisposition'] ?? '').toString().trim();
    final dispositionLabel = switch (dispositionRaw) {
      'approved' => 'Odobreno',
      'recheck_required' => 'Potrebna ponovna kontrola',
      'rework_required' => 'Potrebna dorada',
      'blocked' => 'Blokirano / nije odobreno za dalje',
      _ => dispositionRaw.isEmpty ? '—' : dispositionRaw,
    };
    final bannerText = switch (dispositionRaw) {
      'approved' => 'ODOBRENO / FINALNA KONTROLA ZADOVOLJAVA',
      'recheck_required' => 'POTREBNA PONOVNA KONTROLA',
      'rework_required' => 'POTREBNA DORADA',
      'blocked' => 'BLOKIRANO / NIJE ODOBRENO ZA DALJE',
      _ => null,
    };
    final bannerColor = switch (dispositionRaw) {
      'approved' => Colors.green.shade800,
      'recheck_required' => Colors.orange.shade800,
      'rework_required' => Colors.deepOrange.shade800,
      'blocked' => Colors.red.shade800,
      _ => Theme.of(context).colorScheme.primary,
    };

    return ListView(
      children: [
        _orderRoutingContextSection(session),
        _qmsMarkingBannerIfNeeded(session),
        _buildOutcomeActionCard(session),
        if (bannerText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Material(
              color: bannerColor,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  bannerText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Evidencija', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', _sessionStatusLabel(session)),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
          ],
        ),
        _predajaIVerifikacijaSection(session),
        _evidenceAuditTrailSection(),
        _sectionCard(
          title: 'Proizvodni kontekst',
          children: [
            _kvRow(
              'Proizvodni nalog',
              orderCode.isEmpty ? '—' : orderCode,
            ),
            _kvRow('Proizvod', productCtx.displayName),
            _kvRow('Šifra proizvoda', productCtx.code),
            _kvRow('Naziv proizvoda', productCtx.name),
            _kvRow(
              'Operacija',
              EvidenceOrderContextDisplay.operationStepLabelForEvidenceDetail(
                session.orderSnapshot,
              ),
            ),
          ],
        ),
        _sectionCard(
          title: 'Kontrola',
          children: [
            _kvRow(
              'Operater kvaliteta',
              (s.operatorSummary ??
                      session.fieldValues['controllerNameSnapshot'] ??
                      '')
                  .toString()
                  .trim()
                  .isEmpty
                  ? '—'
                  : (s.operatorSummary ??
                          session.fieldValues['controllerNameSnapshot'])
                      .toString()
                      .trim(),
            ),
            _kvRow('Finalna dispozicija', dispositionLabel),
            ..._operatorFieldsForDisplay.map((field) {
              if (field.key == 'controllerEmployeeId' ||
                  field.key == 'productionOrderId' ||
                  field.key == 'productId' ||
                  field.key == 'finalDisposition') {
                return const SizedBox.shrink();
              }
              return _kvRow(
                _displayLabel(field),
                _displayValueForField(field),
              );
            }),
          ],
        ),
        _sectionCard(
          title: 'Kontrolisane količine',
          children: [
            _kvRow(
              'Ukupno kontrolisano',
              _formatQtyWithUnit(s.quantity, unit),
            ),
            _kvRow(
              'Ukupno OK',
              _formatQtyWithUnit(s.okTotalQty, unit),
            ),
            _kvRow(
              'Ukupno škart',
              _formatQtyWithUnit(s.scrapTotalQty, unit),
            ),
            _kvRow(
              'Ukupno dorada',
              _formatQtyWithUnit(s.reworkAgainTotalQty, unit),
            ),
            if (unit.isNotEmpty) _kvRow('Jedinica', unit),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nema kontrolisanih komada.'),
              ),
          ],
        ),
        if (lines.isNotEmpty)
          _sectionCard(
            title: 'Kontrolisani komadi',
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _buildControlledItemTile(index: i + 1, row: lines[i]),
              ],
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  ({String displayName, String code, String name}) _resolveFinalControlProductContext(
    ProfileDrivenEvidenceSessionDetail session,
  ) {
    final s = session.summaryFields;
    var name = (s.productName ??
            session.fieldValues['productNameSnapshot'] ??
            '')
        .toString()
        .trim();
    var code = (s.productCode ?? session.fieldValues['productCode'] ?? '')
        .toString()
        .trim();
    for (final row in session.controlledItems) {
      if (name.isEmpty) {
        name = (row['productNameSnapshot'] ?? '').toString().trim();
      }
      if (code.isEmpty) {
        code = (row['productCode'] ?? '').toString().trim();
      }
      if (name.isNotEmpty && code.isNotEmpty) break;
    }
    final display = name.isNotEmpty
        ? name
        : (code.isNotEmpty ? code : '—');
    return (
      displayName: display,
      code: code.isEmpty ? '—' : code,
      name: name.isEmpty ? '—' : name,
    );
  }

  Widget _buildControlledItemTile({
    required int index,
    required Map<String, dynamic> row,
  }) {
    final name = (row['productNameSnapshot'] ?? '').toString().trim();
    final code = (row['productCode'] ?? '').toString().trim();
    final title = name.isNotEmpty
        ? name
        : (code.isNotEmpty ? code : 'Stavka $index');
    final unit = (row['unit'] ?? '').toString().trim();
    num? n(dynamic v) {
      if (v is num) return v;
      return num.tryParse('$v');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $title', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (code.isNotEmpty) _kvRow('Šifra', code),
        _kvRow('Kontrolisano', _formatQtyWithUnit(n(row['inspectedQty']), unit)),
        _kvRow('OK', _formatQtyWithUnit(n(row['goodQty']), unit)),
        _kvRow('Škart', _formatQtyWithUnit(n(row['scrapQty']), unit)),
        _kvRow('Dorada', _formatQtyWithUnit(n(row['reworkQty']), unit)),
        if ((row['defectReason'] ?? '').toString().trim().isNotEmpty)
          _kvRow('Razlog greške', row['defectReason'].toString().trim()),
        if ((row['comment'] ?? '').toString().trim().isNotEmpty)
          _kvRow('Napomena', row['comment'].toString().trim()),
      ],
    );
  }

  /// Proizvod iz header snapshota ili prve kontrolne tačke (bez UID prikaza).
  ({String displayName, String code, String name}) _resolveInProcessProductContext(
    ProfileDrivenEvidenceSessionDetail session,
  ) {
    final s = session.summaryFields;
    var name = (s.productName ??
            session.fieldValues['productNameSnapshot'] ??
            '')
        .toString()
        .trim();
    var code = (s.productCode ?? session.fieldValues['productCode'] ?? '')
        .toString()
        .trim();
    for (final row in session.inspectionLines) {
      if (name.isEmpty) {
        name = (row['productNameSnapshot'] ?? '').toString().trim();
      }
      if (code.isEmpty) {
        code = (row['productCode'] ?? '').toString().trim();
      }
      if (name.isNotEmpty && code.isNotEmpty) break;
    }
    final display = name.isNotEmpty
        ? name
        : (code.isNotEmpty ? code : '—');
    return (
      displayName: display,
      code: code.isEmpty ? '—' : code,
      name: name.isEmpty ? '—' : name,
    );
  }

  Widget _buildInspectionLineTile({
    required int index,
    required Map<String, dynamic> row,
  }) {
    final checkpoint = (row['checkpointName'] ?? '').toString().trim();
    final unit = (row['unit'] ?? '').toString().trim();
    final inspected = _formatQtyWithUnit(
      row['qtyInspected'] is num
          ? row['qtyInspected'] as num
          : num.tryParse('${row['qtyInspected']}'),
      unit,
    );
    final pass = _formatQtyInt(
      row['qtyPass'] is num
          ? row['qtyPass'] as num
          : num.tryParse('${row['qtyPass']}'),
    );
    final fail = _formatQtyInt(
      row['qtyFail'] is num
          ? row['qtyFail'] as num
          : num.tryParse('${row['qtyFail']}'),
    );
    final reasonCode = (row['defectReasonCode'] ?? '').toString().trim();
    final reason = reasonCode.isEmpty
        ? '—'
        : OperatorEvidenceUxStandard.defectReasonLabel(reasonCode);
    final note = (row['measurementNote'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$index. ${checkpoint.isEmpty ? 'Kontrolna tačka' : checkpoint} — '
          '$inspected / prolazi $pass / ne prolazi $fail',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        if ((row['productNameSnapshot'] ?? row['productCode'] ?? '')
            .toString()
            .trim()
            .isNotEmpty)
          _kvRow(
            'Proizvod',
            [
              (row['productCode'] ?? '').toString().trim(),
              (row['productNameSnapshot'] ?? '').toString().trim(),
            ].where((e) => e.isNotEmpty).join(' · '),
          ),
        _kvRow('Razlog greške', reason),
        _kvRow('Napomena', note.isEmpty ? '—' : note),
      ],
    );
  }

  Widget _buildPackagingBody(ProfileDrivenEvidenceSessionDetail session) {
    final station =
        (session.stationDisplayName ?? '').trim().isNotEmpty
            ? session.stationDisplayName!
            : (session.stationSlot != null
                  ? 'Stanica ${session.stationSlot}'
                  : '—');
    final s = session.summaryFields;
    final lines = session.packagingCheckLines;
    final multi = lines.length > 1;
    final checkedLabel = multi ? 'Ukupno provjereno' : 'Provjereno';
    final acceptedLabel = multi ? 'Ukupno prihvaćeno' : 'Prihvaćeno';
    final rejectedLabel = multi ? 'Ukupno odbijeno' : 'Odbijeno';

    final controllerName = (s.operatorSummary ??
            session.fieldValues['controllerNameSnapshot'] ??
            '')
        .toString()
        .trim();
    final packagingOperator = (s.packagingOperatorName ??
            session.fieldValues['packagingOperatorNameSnapshot'] ??
            '')
        .toString()
        .trim();

    return ListView(
      children: [
        _orderRoutingContextSection(session),
        _qmsMarkingBannerIfNeeded(session),
        _buildOutcomeActionCard(session),
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', _sessionStatusLabel(session)),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
          ],
        ),
        _predajaIVerifikacijaSection(session),
        _evidenceAuditTrailSection(),
        _sectionCard(
          title: 'Kontrola pakovanja',
          children: [
            _kvRow(
              'Operater kvaliteta',
              controllerName.isEmpty ? '—' : controllerName,
            ),
            _kvRow(
              'Operater proizvodnje',
              packagingOperator.isEmpty ? '—' : packagingOperator,
            ),
            _kvRow(checkedLabel, _formatQtyInt(s.quantity)),
            _kvRow(acceptedLabel, _formatQtyInt(s.okTotalQty)),
            _kvRow(rejectedLabel, _formatQtyInt(s.scrapTotalQty)),
            ..._operatorFieldsForDisplay.map((field) {
              if (field.key == 'controllerEmployeeId' ||
                  field.key == 'packagingOperatorEmployeeId') {
                return const SizedBox.shrink();
              }
              return _kvRow(
                _displayLabel(field),
                _displayValueForField(field),
              );
            }),
          ],
        ),
        if (lines.isNotEmpty)
          _sectionCard(
            title: 'Kontrolisane jedinice pakovanja',
            children: [
              ProfileDrivenEvidenceStructuredTable(
                columns: const [
                  ProfileDrivenEvidenceStructuredColumn('Lot / serija', 'lotOrSerial'),
                  ProfileDrivenEvidenceStructuredColumn('Provjereno', 'unitsChecked'),
                  ProfileDrivenEvidenceStructuredColumn('Prihvaćeno', 'unitsAccepted'),
                  ProfileDrivenEvidenceStructuredColumn('Odbijeno', 'unitsRejected'),
                  ProfileDrivenEvidenceStructuredColumn('Razlog', 'defectReasonCode'),
                  ProfileDrivenEvidenceStructuredColumn('Etiketa', 'labelCorrect'),
                  ProfileDrivenEvidenceStructuredColumn('Pečat', 'sealIntact'),
                  ProfileDrivenEvidenceStructuredColumn('Napomena', 'lineNote'),
                ],
                rows: lines,
                cellBuilder: (row, key) {
                  switch (key) {
                    case 'unitsChecked':
                    case 'unitsAccepted':
                    case 'unitsRejected':
                      return evidenceRowText(row[key]);
                    case 'defectReasonCode':
                      return packagingDefectReasonLabel(
                        (row[key] ?? '').toString(),
                      );
                    case 'labelCorrect':
                    case 'sealIntact':
                      final v = row[key];
                      if (v == true) return 'DA';
                      if (v == false) return 'NE';
                      return '—';
                    default:
                      return evidenceRowText(row[key]);
                  }
                },
              ),
            ],
          ),
        if (_masterDataFieldsForDisplay.isNotEmpty)
          _fieldSection(
            'Podaci iz master šifrarnika',
            _masterDataFieldsForDisplay,
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFlatProfileBody(ProfileDrivenEvidenceSessionDetail session) {
    final station =
        (session.stationDisplayName ?? '').trim().isNotEmpty
            ? session.stationDisplayName!
            : (session.stationSlot != null
                  ? 'Stanica ${session.stationSlot}'
                  : '—');
    final isOmp =
        session.processProfileType.trim() == 'operation_material_preparation';
    final lotSourceLabel = isOmp
        ? ompMaterialLotSourceDisplayLabel(session.fieldValues)
        : null;
    final lotValue = (session.fieldValues['materialLot'] ?? '').toString().trim();
    final lotRequired = isOmp && ompLotIsRequired(session.fieldValues);
    final kindLabel = isOmp
        ? bomItemKindLabelBs(
            (session.fieldValues[ompBomItemKindSnapshot] ?? '').toString(),
          )
        : null;
    final modeLabel = isOmp
        ? bomTraceabilityModeLabelBs(
            (session.fieldValues[ompTraceabilityModeSnapshot] ?? '').toString(),
          )
        : null;

    return ListView(
      children: [
        _orderRoutingContextSection(session),
        _qmsMarkingBannerIfNeeded(session),
        _buildOutcomeActionCard(session),
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', _sessionStatusLabel(session)),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
          ],
        ),
        _predajaIVerifikacijaSection(session),
        _evidenceAuditTrailSection(),
        if (isOmp)
          _sectionCard(
            title: 'Lot / sljedivost',
            children: [
              if (kindLabel != null) _kvRow('Vrsta stavke', kindLabel),
              if (modeLabel != null) _kvRow('Način sljedivosti', modeLabel),
              _kvRow(
                'Lot obavezan',
                bomLotRequiredLabelBs(lotRequired),
              ),
              if (!lotRequired)
                _kvRow('Lot / šarža', ompLotNotRequiredBanner)
              else ...[
                if (lotValue.isNotEmpty) _kvRow('Lot / šarža', lotValue),
                if (lotValue.isNotEmpty && lotSourceLabel != null)
                  _kvRow('Izvor lota', lotSourceLabel),
              ],
            ],
          ),
        _fieldSection('Unesena polja', _operatorFieldsForDisplay),
        if (_masterDataFieldsForDisplay.isNotEmpty)
          _fieldSection(
            'Podaci iz master šifrarnika',
            _masterDataFieldsForDisplay,
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildReworkBody(ProfileDrivenEvidenceSessionDetail session) {
    final station =
        (session.stationDisplayName ?? '').trim().isNotEmpty
            ? session.stationDisplayName!
            : (session.stationSlot != null
                  ? 'Stanica ${session.stationSlot}'
                  : '—');
    final s = session.summaryFields;

    return ListView(
      children: [
        _orderRoutingContextSection(session),
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', _sessionStatusLabel(session)),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
          ],
        ),
        _predajaIVerifikacijaSection(session),
        _evidenceAuditTrailSection(),
        _sectionCard(
          title: 'Zaglavlje operacije',
          children: [
            _kvRow('Tip obrade', formatReworkOperationTypeLabel(s.operationType)),
            _kvRow('Rezultat obrade', formatReworkResultStatusLabel(s.resultStatus)),
            _kvRow('Trajanje operacije', formatReworkDurationMinutes(s.durationMinutes)),
            ..._operatorFieldsForDisplay.map((field) {
              return _kvRow(
                _displayLabel(field),
                _displayValueForField(field),
              );
            }),
          ],
        ),
        _sectionCard(
          title: 'Komadi / proizvodi',
          children: [
            ProfileDrivenEvidenceStructuredTable(
              columns: const [
                ProfileDrivenEvidenceStructuredColumn('Šifra', 'productCode'),
                ProfileDrivenEvidenceStructuredColumn('Naziv', 'productName'),
                ProfileDrivenEvidenceStructuredColumn('Tip komada', 'pieceType'),
                ProfileDrivenEvidenceStructuredColumn('Količina', 'quantity'),
                ProfileDrivenEvidenceStructuredColumn('Jedinica', 'unit'),
                ProfileDrivenEvidenceStructuredColumn('Lot / serija', 'lotOrSerial'),
              ],
              rows: session.processedItems,
              cellBuilder: (row, key) {
                switch (key) {
                  case 'productCode':
                    return evidenceRowText(row['productCodeSnapshot']);
                  case 'productName':
                    return evidenceRowText(row['productNameSnapshot']);
                  case 'pieceType':
                    return evidenceRowText(row['pieceType']);
                  case 'quantity':
                    return evidenceRowText(row['processedQuantity']);
                  case 'unit':
                    return evidenceRowText(row['unit']);
                  case 'lotOrSerial':
                    return evidenceRowText(row['lotOrSerial']);
                  default:
                    return '—';
                }
              },
            ),
          ],
        ),
        _sectionCard(
          title: 'Utrošeni materijali',
          children: [
            ProfileDrivenEvidenceStructuredTable(
              columns: const [
                ProfileDrivenEvidenceStructuredColumn('Šifra', 'materialCode'),
                ProfileDrivenEvidenceStructuredColumn('Naziv', 'materialName'),
                ProfileDrivenEvidenceStructuredColumn('Tip', 'materialType'),
                ProfileDrivenEvidenceStructuredColumn('Količina', 'quantity'),
                ProfileDrivenEvidenceStructuredColumn('Jedinica', 'unit'),
                ProfileDrivenEvidenceStructuredColumn('Lot / serija', 'lotOrBatch'),
              ],
              rows: session.materialConsumptions,
              cellBuilder: (row, key) {
                switch (key) {
                  case 'materialCode':
                    return evidenceRowText(row['materialCodeSnapshot']);
                  case 'materialName':
                    return evidenceRowText(row['materialNameSnapshot']);
                  case 'materialType':
                    return evidenceRowText(
                      row['materialTypeSnapshot'] ?? row['materialType'],
                    );
                  case 'quantity':
                    return evidenceRowText(row['consumedQuantity']);
                  case 'unit':
                    return evidenceRowText(row['unit']);
                  case 'lotOrBatch':
                    return evidenceRowText(row['lotOrBatch']);
                  default:
                    return '—';
                }
              },
            ),
          ],
        ),
        _sectionCard(
          title: 'Rad operatera',
          children: [
            ProfileDrivenEvidenceStructuredTable(
              columns: const [
                ProfileDrivenEvidenceStructuredColumn('Operater', 'operator'),
                ProfileDrivenEvidenceStructuredColumn('Početak', 'startedAt'),
                ProfileDrivenEvidenceStructuredColumn('Kraj', 'finishedAt'),
                ProfileDrivenEvidenceStructuredColumn('OK', 'okQty'),
                ProfileDrivenEvidenceStructuredColumn('Neispravni', 'scrapQty'),
                ProfileDrivenEvidenceStructuredColumn('Ponovna dorada', 'reworkAgainQty'),
                ProfileDrivenEvidenceStructuredColumn('Ukupno', 'processedQty'),
              ],
              rows: session.operatorWorkLogs,
              cellBuilder: (row, key) {
                switch (key) {
                  case 'operator':
                    return evidenceRowText(row['operatorDisplayNameSnapshot']);
                  case 'startedAt':
                    return evidenceRowDateTime(row['startedAt']);
                  case 'finishedAt':
                    return evidenceRowDateTime(row['finishedAt']);
                  case 'okQty':
                    return evidenceRowText(row['okQty']);
                  case 'scrapQty':
                    return evidenceRowText(row['scrapQty']);
                  case 'reworkAgainQty':
                    return evidenceRowText(row['reworkAgainQty']);
                  case 'processedQty':
                    return evidenceRowText(row['processedQty']);
                  default:
                    return '—';
                }
              },
            ),
          ],
        ),
        _sectionCard(
          title: 'Škartni komadi',
          children: [
            ProfileDrivenEvidenceStructuredTable(
              columns: const [
                ProfileDrivenEvidenceStructuredColumn('Šifra', 'productCode'),
                ProfileDrivenEvidenceStructuredColumn('Naziv', 'productName'),
                ProfileDrivenEvidenceStructuredColumn('Količina škarta', 'scrapQuantity'),
                ProfileDrivenEvidenceStructuredColumn('Jedinica', 'unit'),
                ProfileDrivenEvidenceStructuredColumn('Razlog škarta', 'scrapReason'),
                ProfileDrivenEvidenceStructuredColumn('Faza škarta', 'scrapStage'),
                ProfileDrivenEvidenceStructuredColumn('Operater', 'operator'),
              ],
              rows: session.scrapItems,
              cellBuilder: (row, key) {
                switch (key) {
                  case 'productCode':
                    return evidenceRowText(row['productCodeSnapshot']);
                  case 'productName':
                    return evidenceRowText(row['productNameSnapshot']);
                  case 'scrapQuantity':
                    return evidenceRowText(row['scrapQuantity']);
                  case 'unit':
                    return evidenceRowText(row['unit']);
                  case 'scrapReason':
                    return evidenceRowText(row['scrapReason']);
                  case 'scrapStage':
                    return evidenceRowText(row['scrapStage']);
                  case 'operator':
                    return evidenceRowText(row['operatorDisplayNameSnapshot']);
                  default:
                    return '—';
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  OperonixAiEntityChatBinding? _evidenceAiChatBinding() {
    final session = _session;
    if (session == null) return null;
    final sessionKey = session.sessionId.trim().isNotEmpty
        ? session.sessionId.trim()
        : widget.sessionId.trim();
    if (sessionKey.isEmpty) return null;

    final order = (session.summaryFields.productionOrderCode ??
            session.fieldValues['productionOrderCode']?.toString() ??
            session.orderSnapshot?.productionOrderCode ??
            '')
        .toString()
        .trim();
    final profile = session.profileDisplayName.trim();
    final parts = <String>[
      if (profile.isNotEmpty) profile,
      if (order.isNotEmpty) order,
    ];
    final label = parts.isEmpty ? 'Zatvorena evidencija' : parts.join(' · ');

    return OperonixAiEntityChatBinding(
      kind: OperonixAiEntityChatKind.evidenceSession,
      businessKey: sessionKey,
      displayLabel: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalj evidencije'),
        actions: [
          if (_canExportFirstPiecePdf)
            PopupMenuButton<String>(
              tooltip: 'PDF odobrenja prvog komada',
              enabled: !_loading && !_pdfBusy,
              onSelected: (value) {
                Future<void> Function()? action;
                switch (value) {
                  case 'preview':
                    action = () => _firstPiecePdfActions.preview(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                        );
                    break;
                  case 'download':
                    action = () => _firstPiecePdfActions.downloadOrShare(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                        );
                    break;
                  case 'print':
                    action = () => _firstPiecePdfActions.print(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                        );
                    break;
                }
                if (action != null) _runEvidencePdf(action);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'preview',
                  child: Text('Pregled PDF'),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Text('Preuzmi PDF'),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Text('Print PDF'),
                ),
              ],
              icon: _pdfBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (_canExportInProcessRecordPdf)
            PopupMenuButton<String>(
              tooltip: 'PDF evidencijskog zapisnika procesne kontrole',
              enabled: !_loading && !_pdfBusy,
              onSelected: (value) {
                Future<void> Function()? action;
                switch (value) {
                  case 'preview':
                    action = () => _inProcessPdfActions.preview(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'download':
                    action = () => _inProcessPdfActions.downloadOrShare(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'print':
                    action = () => _inProcessPdfActions.print(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'share':
                    action = () => _inProcessPdfActions.share(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                }
                if (action != null) _runEvidencePdf(action);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'preview',
                  child: Text('Pregled PDF'),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Text('Preuzmi PDF'),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Text('Print PDF'),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text('Pošalji PDF'),
                ),
              ],
              icon: _pdfBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (_canExportFinalControlRecordPdf)
            PopupMenuButton<String>(
              tooltip: 'PDF evidencijskog zapisnika finalne kontrole',
              enabled: !_loading && !_pdfBusy,
              onSelected: (value) {
                Future<void> Function()? action;
                switch (value) {
                  case 'preview':
                    action = () => _finalControlPdfActions.preview(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'download':
                    action = () => _finalControlPdfActions.downloadOrShare(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'print':
                    action = () => _finalControlPdfActions.print(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'share':
                    action = () => _finalControlPdfActions.share(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                }
                if (action != null) _runEvidencePdf(action);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'preview',
                  child: Text('Pregled PDF'),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Text('Preuzmi PDF'),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Text('Print PDF'),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text('Pošalji PDF'),
                ),
              ],
              icon: _pdfBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (_canExportOperationMaterialPrepPdf)
            PopupMenuButton<String>(
              tooltip:
                  'PDF evidencijskog zapisnika pripreme materijala za operaciju',
              enabled: !_loading && !_pdfBusy,
              onSelected: (value) {
                Future<void> Function()? action;
                switch (value) {
                  case 'preview':
                    action = () => _operationMaterialPrepPdfActions.preview(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'download':
                    action =
                        () => _operationMaterialPrepPdfActions.downloadOrShare(
                              companyId: _companyId,
                              sessionId: widget.sessionId,
                              companyData: widget.companyData,
                              plantDisplayName: _plantLabelForPdf,
                              session: _session,
                            );
                    break;
                  case 'print':
                    action = () => _operationMaterialPrepPdfActions.print(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                  case 'share':
                    action = () => _operationMaterialPrepPdfActions.share(
                          companyId: _companyId,
                          sessionId: widget.sessionId,
                          companyData: widget.companyData,
                          plantDisplayName: _plantLabelForPdf,
                          session: _session,
                        );
                    break;
                }
                if (action != null) _runEvidencePdf(action);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'preview',
                  child: Text('Pregled PDF'),
                ),
                PopupMenuItem(
                  value: 'download',
                  child: Text('Preuzmi PDF'),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Text('Print PDF'),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text('Pošalji PDF'),
                ),
              ],
              icon: _pdfBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (!_loading && _error == null && _session != null)
            OperonixAiAskAssistantAppBarAction(
              companyData: widget.companyData,
              entityBinding: _evidenceAiChatBinding(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profileDrivenEvidenceErrorMessage(_error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Pokušaj ponovo'),
                    ),
                  ],
                ),
              ),
            )
          : _session == null
          ? const Center(child: Text('Evidencija nije pronađena.'))
          : _buildBody(_session!),
    );
  }
}
