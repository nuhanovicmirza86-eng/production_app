import 'package:flutter/material.dart';

import '../../../core/company_plant_display_name.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../models/profile_driven_evidence_session.dart';
import '../services/profile_driven_evidence_callable_service.dart';
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

  bool _loading = true;
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

  List<ProductionStationProfileField> get _snapshotFields =>
      _fieldDefs.where((f) => !f.isOperatorEditable).toList(growable: false);

  String _displayValue(String key, dynamic raw) {
    if (key == 'heavyMetalsPresent') {
      return formatHeavyMetalsLabel(raw?.toString());
    }
    return formatFieldValue(raw);
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
    final session = _session!;
    if (fields.isEmpty) {
      return _sectionCard(
        title: title,
        children: const [Text('Nema podataka za prikaz.')],
      );
    }

    return _sectionCard(
      title: title,
      children: fields.map((field) {
        final raw = session.fieldValues[field.key];
        return _kvRow(
          field.label.isNotEmpty ? field.label : field.key,
          _displayValue(field.key, raw),
        );
      }).toList(),
    );
  }

  Widget _buildBody(ProfileDrivenEvidenceSessionDetail session) {
    if (session.isReworkAndPainting) {
      return _buildReworkBody(session);
    }
    return _buildFlatProfileBody(session);
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
            _kvRow('Pogon', _plantLabel ?? session.plantKey),
            _kvRow('Status', session.status == 'closed' ? 'Završeno' : session.status),
            _kvRow('Početak', formatEvidenceDateTime(session.startedAt)),
            _kvRow('Završetak', formatEvidenceDateTime(session.endedAt)),
            if (session.catalogVersion != null)
              _kvRow('Verzija kataloga profila', '${session.catalogVersion}'),
          ],
        ),
        _fieldSection('Unesena polja', _operatorFields),
        _fieldSection('Snapshoti iz master podataka', _snapshotFields),
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
              return _kvRow(e.key, formatFieldValue(e.value));
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
            _kvRow('Pogon', _plantLabel ?? session.plantKey),
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
            ..._operatorFields.map((field) {
              final raw = session.fieldValues[field.key];
              return _kvRow(
                field.label.isNotEmpty ? field.label : field.key,
                _displayValue(field.key, raw),
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
