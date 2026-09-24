/// Poslovni red historije akcija NCR-a (Callable `listNcrActionHistory`).
class NcrActionHistoryEntry {
  final String occurredAt;
  final String stepLabel;
  final String actionLabel;
  final String ownerLabel;
  final String executorLabel;
  final String dueLabel;
  final String statusLabel;
  final String note;
  final String eventSourceLabel;
  final String productLabel;
  final String productionOrderLabel;
  final String machineLabel;

  const NcrActionHistoryEntry({
    required this.occurredAt,
    required this.stepLabel,
    required this.actionLabel,
    required this.ownerLabel,
    required this.executorLabel,
    required this.dueLabel,
    required this.statusLabel,
    required this.note,
    required this.eventSourceLabel,
    this.productLabel = 'Nije evidentirano',
    this.productionOrderLabel = 'Nije evidentirano',
    this.machineLabel = 'Nije evidentirano',
  });

  factory NcrActionHistoryEntry.fromMap(Map<String, dynamic> m) {
    return NcrActionHistoryEntry(
      occurredAt: (m['occurredAt'] ?? '—').toString(),
      stepLabel: (m['stepLabel'] ?? '—').toString(),
      actionLabel: (m['actionLabel'] ?? '—').toString(),
      ownerLabel: (m['ownerLabel'] ?? 'Nije evidentirano').toString(),
      executorLabel: (m['executorLabel'] ?? 'Nije evidentirano').toString(),
      dueLabel: (m['dueLabel'] ?? '—').toString(),
      statusLabel: (m['statusLabel'] ?? '—').toString(),
      note: (m['note'] ?? '—').toString(),
      eventSourceLabel: (m['eventSourceLabel'] ?? '—').toString(),
      productLabel: (m['productLabel'] ?? 'Nije evidentirano').toString(),
      productionOrderLabel:
          (m['productionOrderLabel'] ?? 'Nije evidentirano').toString(),
      machineLabel: (m['machineLabel'] ?? 'Nije evidentirano').toString(),
    );
  }
}

/// Odgovor Callable-a `listNcrActionHistory`.
class NcrActionHistoryListResult {
  final List<NcrActionHistoryEntry> items;
  final String ncrDocumentNo;
  final String ncrStatusLabel;
  final int ledgerEntryCount;

  const NcrActionHistoryListResult({
    required this.items,
    required this.ncrDocumentNo,
    required this.ncrStatusLabel,
    required this.ledgerEntryCount,
  });

  factory NcrActionHistoryListResult.fromMap(Map<String, dynamic> m) {
    final rawItems = m['items'];
    final items = rawItems is List
        ? rawItems
            .map(
              (e) => NcrActionHistoryEntry.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <NcrActionHistoryEntry>[];
    return NcrActionHistoryListResult(
      items: items,
      ncrDocumentNo: (m['ncrDocumentNo'] ?? '—').toString(),
      ncrStatusLabel: (m['ncrStatusLabel'] ?? '—').toString(),
      ledgerEntryCount: _int(m['ledgerEntryCount']),
    );
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Jedan deterministički risk signal (Callable `getNcrActionRiskSignals`).
class NcrActionRiskSignal {
  final String code;
  final String label;
  final String description;
  final String severity;

  const NcrActionRiskSignal({
    required this.code,
    required this.label,
    required this.description,
    required this.severity,
  });

  factory NcrActionRiskSignal.fromMap(Map<String, dynamic> m) {
    return NcrActionRiskSignal(
      code: (m['code'] ?? '').toString(),
      label: (m['label'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      severity: (m['severity'] ?? '').toString(),
    );
  }
}

/// Odgovor Callable-a `getNcrActionRiskSignals` — priprema za M1-I13-E banner.
class NcrActionRiskSignalsResult {
  final String riskLevel;
  final List<NcrActionRiskSignal> signals;
  final String ncrDocumentNo;
  final String ncrStatusLabel;

  const NcrActionRiskSignalsResult({
    required this.riskLevel,
    required this.signals,
    required this.ncrDocumentNo,
    required this.ncrStatusLabel,
  });

  factory NcrActionRiskSignalsResult.fromMap(Map<String, dynamic> m) {
    final raw = m['signals'];
    final signals = raw is List
        ? raw
            .map(
              (e) => NcrActionRiskSignal.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <NcrActionRiskSignal>[];
    return NcrActionRiskSignalsResult(
      riskLevel: (m['riskLevel'] ?? 'none').toString(),
      signals: signals,
      ncrDocumentNo: (m['ncrDocumentNo'] ?? '—').toString(),
      ncrStatusLabel: (m['ncrStatusLabel'] ?? '—').toString(),
    );
  }
}

/// AI objašnjenje rizika (Callable `explainNcrActionRiskSignals`, M1-I13-F).
class NcrActionRiskAiExplanation {
  final bool aiUsed;
  final String procjena;
  final String zastoJeVazno;
  final String preporuceniSljedeciKorak;

  const NcrActionRiskAiExplanation({
    required this.aiUsed,
    required this.procjena,
    required this.zastoJeVazno,
    required this.preporuceniSljedeciKorak,
  });

  factory NcrActionRiskAiExplanation.fromMap(Map<String, dynamic> m) {
    return NcrActionRiskAiExplanation(
      aiUsed: m['aiUsed'] == true,
      procjena: (m['procjena'] ?? '').toString(),
      zastoJeVazno: (m['zastoJeVazno'] ?? '').toString(),
      preporuceniSljedeciKorak:
          (m['preporuceniSljedeciKorak'] ?? '').toString(),
    );
  }
}

/// Red u QMS hub pregledu — ledger zapis + poslovna NCR oznaka (bez raw ID-a u UI).
class NcrActionHistoryHubRow {
  final NcrActionHistoryEntry entry;
  final String ncrDocumentNo;
  final String ncrStatusLabel;
  final String ncrId;

  const NcrActionHistoryHubRow({
    required this.entry,
    required this.ncrDocumentNo,
    required this.ncrStatusLabel,
    required this.ncrId,
  });
}
