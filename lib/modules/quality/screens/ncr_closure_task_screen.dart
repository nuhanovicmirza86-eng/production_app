import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/access/production_access_helper.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../models/qms_list_models.dart';
import '../services/ncr_closure_attachment_upload.dart';
import '../services/quality_callable_service.dart';
import '../utils/ncr_closure_execution_choice_options.dart';
import '../utils/qms_ncr_display_labels.dart';
import '../widgets/ncr_action_hodogram_model.dart';
import '../widgets/ncr_evidence_form_fields.dart';

/// M1-I12-D — vođeno zatvaranje neusaglašenosti (dokaz + CAPA odluka).
class NcrClosureTaskScreen extends StatefulWidget {
  const NcrClosureTaskScreen({
    super.key,
    required this.companyData,
    required this.ncrId,
  });

  final Map<String, dynamic> companyData;
  final String ncrId;

  @override
  State<NcrClosureTaskScreen> createState() => _NcrClosureTaskScreenState();
}

class _NcrClosureTaskScreenState extends State<NcrClosureTaskScreen> {
  final _svc = QualityCallableService();
  final _note = TextEditingController();
  final _reasonOther = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _ncr;
  List<QmsCapaRow> _capas = const [];
  List<NcrClosureUploadedAttachment> _attachments = const [];
  String? _capaDecision;
  String? _capaNotRequiredReason;

  String get _cid => (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _reasonOther.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ncr = await _svc.getQmsNonConformanceMap(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      final capas = await _svc.listCapaForNcr(
        companyId: _cid,
        ncrId: widget.ncrId,
      );
      if (!mounted) return;
      setState(() {
        _ncr = ncr;
        _capas = capas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  String _s(Object? v) => (v ?? '').toString().trim();

  bool get _isAlreadyClosed =>
      NcrActionHodogramLogic.isNcrClosed(_s(_ncr?['status']));

  String _displayCode() {
    return QmsNcrDisplayLabels.displayDocumentNumber(
      ncrDocumentNo: _ncr?['ncrDocumentNo']?.toString(),
      ncrCode: _ncr?['ncrCode']?.toString(),
    );
  }

  String _businessSummaryLabel(Object? value) {
    final s = _s(value);
    return s.isEmpty ? 'Nije evidentirano' : s;
  }

  String _outcomeLabel() {
    final key = _s(_ncr?['evidenceOutcomeKey']);
    if (key.isNotEmpty) return QmsNcrDisplayLabels.outcome(key);
    final recheck = _ncr?['executionRecheck'];
    if (recheck is Map) {
      final ol = _s(recheck['outcomeLabel']);
      if (ol.isNotEmpty) return ol;
    }
    return '—';
  }

  String _reworkSummary() {
    final rework = _ncr?['executionRework'];
    if (rework is! Map) return '—';
    final qty = rework['reworkedQty'];
    if (qty == null) return '—';
    return 'Dorada izvršena ($qty kom.)';
  }

  String _recheckSummary() {
    final recheck = _ncr?['executionRecheck'];
    if (recheck is! Map) return '—';
    final ol = _s(recheck['outcomeLabel']);
    if (ol.isNotEmpty) return ol;
    final ok = recheck['okQty'];
    final checked = recheck['checkedQty'];
    if (ok != null && checked != null) {
      return 'Odobreno ($ok / $checked kom.)';
    }
    return '—';
  }

  String _capaStatusBs(String raw) {
    switch (raw.toLowerCase()) {
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
        return raw.isEmpty ? '—' : raw;
    }
  }

  String? _capaDecisionLabel() {
    if (_capaDecision == null) return null;
    for (final e in ncrClosureCapaDecisionOptions) {
      if (e.key == _capaDecision) return e.value;
    }
    return null;
  }

  String? _capaReasonLabel() {
    if (_capaNotRequiredReason == null) return null;
    for (final e in ncrClosureCapaNotRequiredReasonOptions) {
      if (e.key == _capaNotRequiredReason) return e.value;
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _uploadBytes(
      bytes: bytes,
      fileName: x.name.isNotEmpty ? x.name : 'fotografija.jpg',
      contentType:
          NcrClosureAttachmentUploader.guessMimeFromName(x.name) ??
              'image/jpeg',
      label: 'Fotografija zatvaranja',
      successMessage: 'Fotografija dodana',
    );
  }

  Future<void> _pickDocument() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nije moguće učitati datoteku. Pokušajte drugi format ili manji fajl.',
          ),
        ),
      );
      return;
    }
    final name = f.name.isNotEmpty ? f.name : 'dokument.pdf';
    await _uploadBytes(
      bytes: bytes,
      fileName: name,
      contentType:
          NcrClosureAttachmentUploader.guessMimeFromName(name) ??
              'application/octet-stream',
      label: f.name.isNotEmpty ? f.name : 'Dokument zatvaranja',
      successMessage: 'Dokument dodan',
    );
  }

  Future<void> _uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String label,
    required String successMessage,
  }) async {
    final validationError = NcrClosureAttachmentUploader.validateBeforeUpload(
      bytes: bytes,
      contentType: contentType,
    );
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uploaded = await _svc.uploadNcrClosureAttachment(
        companyId: _cid,
        ncrId: widget.ncrId,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        displayLabel: label,
      );
      if (!mounted) return;
      setState(() {
        _attachments = [..._attachments, uploaded];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_closureUploadErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _closureUploadErrorMessage(Object error) {
    final mapped = AppErrorMapper.toMessage(error);
    if (mapped == 'Došlo je do greške. Pokušajte ponovo.') {
      return 'Nije moguće dodati dokaz zatvaranja. Provjerite dozvolu za upload '
          'ili pokušajte drugi fajl.';
    }
    return mapped;
  }

  Future<void> _submit() async {
    if (_isAlreadyClosed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neusaglašenost je već zatvorena.'),
        ),
      );
      return;
    }
    if (_attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dodaj barem jedan prilog — fotografiju ili dokument.',
          ),
        ),
      );
      return;
    }
    final decision = (_capaDecision ?? '').trim();
    if (decision.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberi CAPA odluku.')),
      );
      return;
    }
    String? reasonKey;
    String? reasonOther;
    if (decision == ncrClosureCapaNotRequired) {
      reasonKey = _capaNotRequiredReason;
      if (reasonKey == null || reasonKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Odaberi razlog zašto CAPA nije potrebna.'),
          ),
        );
        return;
      }
      if (reasonKey == ncrClosureReasonOther) {
        reasonOther = _reasonOther.text.trim();
        if (reasonOther.length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unesi razlog (najmanje 3 znaka).')),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final res = await _svc.closeNcrWithExecutionEvidence(
        companyId: _cid,
        ncrId: widget.ncrId,
        capaDecision: decision,
        newAttachments:
            _attachments.map((a) => a.toPayload()).toList(growable: false),
        capaNotRequiredReasonKey: reasonKey,
        capaNotRequiredReasonOther: reasonOther,
        closureNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      if (res['requiresCapaCompletion'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _s(res['message']).isNotEmpty
                  ? _s(res['message'])
                  : 'CAPA je otvorena — dovrši CAPA pa ponovo pokreni zatvaranje.',
            ),
          ),
        );
        await _load();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_closureErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _closureErrorMessage(Object error) {
    final mapped = AppErrorMapper.toMessage(error);
    if (mapped == 'Došlo je do greške. Pokušajte ponovo.' ||
        mapped.toUpperCase() == 'INTERNAL') {
      return 'Nije moguće završiti zatvaranje neusaglašenosti. Pokušajte ponovo.';
    }
    return mapped;
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _capaDecisionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ncrClosureCapaDecisionOptions.map((e) {
        final selected = _capaDecision == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: _saving
              ? null
              : (v) {
                  if (!v) return;
                  setState(() {
                    _capaDecision = e.key;
                    if (_capaDecision != ncrClosureCapaNotRequired) {
                      _capaNotRequiredReason = null;
                    }
                  });
                },
        );
      }).toList(),
    );
  }

  Widget _capaReasonChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ncrClosureCapaNotRequiredReasonOptions.map((e) {
        final selected = _capaNotRequiredReason == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: _saving
              ? null
              : (v) {
                  if (!v) return;
                  setState(() => _capaNotRequiredReason = e.key);
                },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role =
        ProductionAccessHelper.normalizeRole(widget.companyData['role']);
    if (!ProductionAccessHelper.canRunNcrQualityRecheckRole(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zatvaranje neusaglašenosti')),
        body: const Center(
          child: Text(
            'Zatvaranje neusaglašenosti može izvršiti samo kontrola kvaliteta.',
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zatvaranje neusaglašenosti'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _loading || _saving ? null : _load,
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
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                )
              : _isAlreadyClosed
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        NcrEvidenceSectionCard(
                          icon: Icons.task_alt_outlined,
                          title: 'Neusaglašenost je zatvorena',
                          children: [
                            Text(
                              'Tok je zatvoren. Nisu potrebne dodatne akcije.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _summaryRow('NCR broj', _displayCode()),
                            _summaryRow(
                              'Proizvod',
                              _businessSummaryLabel(
                                _ncr?['businessProductLabel'],
                              ),
                            ),
                            _summaryRow(
                              'Nalog',
                              _businessSummaryLabel(
                                _ncr?['businessProductionOrderLabel'],
                              ),
                            ),
                            _summaryRow('Ponovna kontrola', _recheckSummary()),
                          ],
                        ),
                      ],
                    )
                  : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    NcrEvidenceSectionCard(
                      icon: Icons.summarize_outlined,
                      title: 'Sažetak slučaja',
                      children: [
                        _summaryRow('NCR broj', _displayCode()),
                          _summaryRow(
                            'Proizvod',
                            _businessSummaryLabel(_ncr?['businessProductLabel']),
                          ),
                          _summaryRow(
                            'Nalog',
                            _businessSummaryLabel(
                              _ncr?['businessProductionOrderLabel'],
                            ),
                          ),
                          _summaryRow(
                            'Mašina',
                            _businessSummaryLabel(_ncr?['businessMachineLabel']),
                          ),
                          _summaryRow('Početni ishod', _outcomeLabel()),
                          _summaryRow('Dorada', _reworkSummary()),
                          _summaryRow('Ponovna kontrola', _recheckSummary()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NcrEvidenceSectionCard(
                      icon: Icons.attach_file_outlined,
                      title: 'Dokaz zatvaranja',
                      children: [
                        Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : _pickPhoto,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Dodaj fotografiju'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : _pickDocument,
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: const Text('Dodaj dokument'),
                                ),
                              ),
                            ],
                          ),
                          if (_attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ..._attachments.map(
                              (a) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    const Icon(Icons.check_circle_outline),
                                title: Text(a.label),
                                subtitle: Text(a.fileName),
                                trailing: IconButton(
                                  tooltip: 'Ukloni',
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                            _attachments = _attachments
                                                .where((x) => x != a)
                                                .toList();
                                          }),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _note,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Napomena (opcionalno)',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NcrEvidenceSectionCard(
                      icon: Icons.fact_check_outlined,
                      title: 'CAPA odluka',
                      children: [
                        Text(
                            'Odaberi odluku',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          _capaDecisionChips(),
                          if (_capaDecision == ncrClosureCapaNotRequired) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Kontrolisani razlog',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            _capaReasonChips(),
                            if (_capaNotRequiredReason ==
                                ncrClosureReasonOther) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _reasonOther,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Opis razloga',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                          if (_capaDecision == ncrClosureCapaAlreadyExists &&
                              _capas.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Povezane CAPA',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ..._capas.map(
                              (c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  c.actionPlanCode?.isNotEmpty == true
                                      ? c.actionPlanCode!
                                      : c.title,
                                ),
                                subtitle: Text(
                                  'Status: ${_capaStatusBs(c.status)}',
                                ),
                              ),
                            ),
                          ],
                          if (_capaDecision == ncrClosureCapaRequired)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Sistem će otvoriti CAPA zapis. Neusaglašenost '
                                'se zatvara tek nakon dovršetka CAPA.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NcrEvidenceSectionCard(
                      icon: Icons.verified_outlined,
                      title: 'Završna potvrda',
                      children: [
                        _summaryRow('Zatvara', 'Kontrola kvaliteta'),
                        _summaryRow(
                          'Vrijeme zatvaranja',
                          'Automatski pri potvrdi',
                        ),
                        _summaryRow('Status', 'Zatvoreno'),
                        if (_capaDecisionLabel() != null)
                          _summaryRow('CAPA odluka', _capaDecisionLabel()!),
                        if (_capaReasonLabel() != null)
                          _summaryRow('Razlog', _capaReasonLabel()!),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.task_alt_outlined),
                      label: Text(
                        _saving
                            ? 'Zatvaranje…'
                            : 'Potvrdi zatvaranje neusaglašenosti',
                      ),
                    ),
                  ],
                ),
    );
  }
}
