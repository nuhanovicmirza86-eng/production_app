import 'package:flutter/material.dart';

import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../catalog_evidence_runtime/utils/operator_evidence_ux_standard.dart';
import '../export/first_piece_approval_pdf_actions.dart';
import '../export/final_control_record_pdf_actions.dart';
import '../export/in_process_quality_check_record_pdf_actions.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
import '../utils/profile_driven_evidence_detail_display.dart';
import '../utils/profile_driven_evidence_rework_labels.dart';
import '../widgets/profile_driven_evidence_structured_table.dart';

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

  bool _loading = true;
  bool _pdfBusy = false;
  Object? _error;
  ProfileDrivenEvidenceSessionDetail? _session;
  String? _plantLabel;

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
      if (!mounted) return;
      setState(() {
        _session = session;
        _plantLabel = plantLabel;
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

  List<ProductionStationProfileField> get _operatorFieldsForDisplay =>
      _operatorFields
          .where((field) => !profileEvidenceShouldHideDetailFieldKey(field.key))
          .toList(growable: false);

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
    if (label.isNotEmpty) return label;
    final key = session.plantKey.trim();
    if (key.isEmpty) return '—';
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

  Future<void> _runEvidencePdf(
    Future<void> Function() action,
  ) async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await action();
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
    if (label.isNotEmpty) return label;
    return (_session?.plantKey ?? '').trim();
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

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
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
    final catalogVer = session.catalogVersion;
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
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow(
              'Status',
              session.status == 'closed' ? 'Završeno' : session.status,
            ),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
            if (catalogVer != null)
              _kvRow('Verzija kataloga profila', '$catalogVer'),
          ],
        ),
        if (catalogVer != null && catalogVer < 17)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ova evidencija je snimljena s katalogom v$catalogVer. '
                  'Nove sesije trebaju katalog v17+ (Mjesto rada).',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
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
              'Kontrolor kvaliteta',
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
        _sectionCard(
          title: 'Operator audit',
          children: [
            _kvRow(
              'Operater',
              (session.operatorDisplayName ?? session.operatorEmail ?? '—')
                  .trim(),
            ),
            _kvRow(
              'E-mail operatera',
              (session.operatorEmail ?? '—').trim(),
            ),
            _kvRow(
              'Sesiju otvorio',
              (session.createdByDisplayName ?? session.createdByEmail ?? '—')
                  .trim(),
            ),
            _kvRow(
              'E-mail (otvaranje)',
              (session.createdByEmail ?? '—').trim(),
            ),
            _kvRow('Kreirano', formatEvidenceDateTime(session.createdAt)),
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
    final catalogVer = session.catalogVersion;
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
            _kvRow(
              'Status',
              session.status == 'closed' ? 'Završeno' : session.status,
            ),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
            if (catalogVer != null)
              _kvRow('Verzija kataloga profila', '$catalogVer'),
          ],
        ),
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
          ],
        ),
        _sectionCard(
          title: 'Kontrola',
          children: [
            _kvRow(
              'Kontrolor',
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
        _sectionCard(
          title: 'Operator audit',
          children: [
            _kvRow(
              'Operater',
              (session.operatorDisplayName ?? session.operatorEmail ?? '—')
                  .trim(),
            ),
            _kvRow(
              'E-mail operatera',
              (session.operatorEmail ?? '—').trim(),
            ),
            _kvRow(
              'Sesiju otvorio',
              (session.createdByDisplayName ?? session.createdByEmail ?? '—')
                  .trim(),
            ),
            _kvRow(
              'E-mail (otvaranje)',
              (session.createdByEmail ?? '—').trim(),
            ),
            _kvRow('Kreirano', formatEvidenceDateTime(session.createdAt)),
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
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', session.status == 'closed' ? 'Završeno' : session.status),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
          ],
        ),
        _sectionCard(
          title: 'Kontrola pakovanja',
          children: [
            _kvRow(
              'Procesni kontrolor',
              controllerName.isEmpty ? '—' : controllerName,
            ),
            _kvRow(
              'Operater pakovanja',
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
    final operatorName =
        (session.operatorDisplayName ?? session.operatorEmail ?? '—').trim();
    final createdBy =
        (session.createdByDisplayName ?? session.createdByEmail ?? '—').trim();

    return ListView(
      children: [
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', session.status == 'closed' ? 'Završeno' : session.status),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
            if (session.catalogVersion != null)
              _kvRow('Verzija kataloga profila', '${session.catalogVersion}'),
          ],
        ),
        _fieldSection('Unesena polja', _operatorFieldsForDisplay),
        if (_masterDataFieldsForDisplay.isNotEmpty)
          _fieldSection(
            'Podaci iz master šifrarnika',
            _masterDataFieldsForDisplay,
          ),
        _sectionCard(
          title: 'Operator audit',
          children: [
            _kvRow('Operater', operatorName),
            if (session.operatorEmail != null &&
                session.operatorEmail!.trim().isNotEmpty)
              _kvRow('E-mail operatera', session.operatorEmail!),
            _kvRow('Sesiju otvorio', createdBy),
            if (session.createdByEmail != null &&
                session.createdByEmail!.trim().isNotEmpty)
              _kvRow('E-mail (otvaranje)', session.createdByEmail!),
            _kvRow('Kreirano', formatEvidenceDateTime(session.createdAt)),
          ],
        ),
        if (session.controlledInputWarning != null &&
            session.controlledInputWarning!.isNotEmpty)
          _sectionCard(
            title: 'Upozorenje kontrolisanog unosa',
            children: session.controlledInputWarning!.entries.map((e) {
              return _kvRow(
                e.key,
                profileEvidenceDetailSanitizedValue(e.value),
              );
            }).toList(),
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
    final operatorName =
        (session.operatorDisplayName ?? session.operatorEmail ?? '—').trim();
    final createdBy =
        (session.createdByDisplayName ?? session.createdByEmail ?? '—').trim();
    final s = session.summaryFields;

    return ListView(
      children: [
        _sectionCard(
          title: 'Osnovni podaci',
          children: [
            _kvRow('Profil', session.profileDisplayName),
            _kvRow('Stanica', station),
            _kvRow('Pogon', _plantDisplayLabel(session)),
            _kvRow('Status', session.status == 'closed' ? 'Završeno' : session.status),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
            if (session.catalogVersion != null)
              _kvRow('Verzija kataloga profila', '${session.catalogVersion}'),
          ],
        ),
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
        _sectionCard(
          title: 'Operator audit',
          children: [
            _kvRow('Operater', operatorName),
            if (session.operatorEmail != null &&
                session.operatorEmail!.trim().isNotEmpty)
              _kvRow('E-mail operatera', session.operatorEmail!),
            _kvRow('Sesiju otvorio', createdBy),
            if (session.createdByEmail != null &&
                session.createdByEmail!.trim().isNotEmpty)
              _kvRow('E-mail (otvaranje)', session.createdByEmail!),
            _kvRow('Kreirano', formatEvidenceDateTime(session.createdAt)),
          ],
        ),
        const SizedBox(height: 24),
      ],
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
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
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
