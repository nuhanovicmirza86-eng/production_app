/// AI-M2-G4 — UI model za agregat [aiListAssistantFeedbackSignals] (D4).
/// Samo BCS labele i brojevi — bez prompt/payload/response/UID.
class OperonixAiFeedbackSignalCountRow {
  const OperonixAiFeedbackSignalCountRow({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  factory OperonixAiFeedbackSignalCountRow.fromMap(Map<String, dynamic> m) {
    final label = (m['keyLabel'] ?? m['label'] ?? '').toString().trim();
    final raw = m['count'];
    final count = raw is int
        ? raw
        : int.tryParse(raw?.toString() ?? '') ?? 0;
    return OperonixAiFeedbackSignalCountRow(
      label: label.isEmpty ? 'Ostalo' : label,
      count: count < 0 ? 0 : count,
    );
  }
}

class OperonixAiFeedbackSignalsSnapshot {
  const OperonixAiFeedbackSignalsSnapshot({
    required this.companyDisplayName,
    required this.plantDisplayName,
    required this.periodFrom,
    required this.periodTo,
    required this.total,
    required this.helpful,
    required this.notHelpful,
    required this.helpfulLabel,
    required this.notHelpfulLabel,
    required this.bySurface,
    required this.byContract,
    required this.byModule,
    required this.topReasons,
    required this.note,
  });

  final String companyDisplayName;
  final String plantDisplayName;
  final String? periodFrom;
  final String? periodTo;
  final int total;
  final int helpful;
  final int notHelpful;
  final String helpfulLabel;
  final String notHelpfulLabel;
  final List<OperonixAiFeedbackSignalCountRow> bySurface;
  final List<OperonixAiFeedbackSignalCountRow> byContract;
  final List<OperonixAiFeedbackSignalCountRow> byModule;
  final List<OperonixAiFeedbackSignalCountRow> topReasons;
  final String note;

  factory OperonixAiFeedbackSignalsSnapshot.fromMap(Map<String, dynamic> data) {
    final company = data['company'];
    final plant = data['plant'];
    final period = data['period'];
    final totals = data['totals'];

    String companyName = 'Kompanija';
    if (company is Map) {
      final n = (company['displayName'] ?? '').toString().trim();
      if (n.isNotEmpty) companyName = n;
    }

    String plantName = 'Svi pogoni';
    if (plant is Map) {
      final n = (plant['displayName'] ?? '').toString().trim();
      if (n.isNotEmpty) plantName = n;
    }

    String? from;
    String? to;
    if (period is Map) {
      final f = (period['from'] ?? '').toString().trim();
      final t = (period['to'] ?? '').toString().trim();
      from = f.isEmpty ? null : f;
      to = t.isEmpty ? null : t;
    }

    int total = 0;
    int helpful = 0;
    int notHelpful = 0;
    var helpfulLabel = 'Korisno';
    var notHelpfulLabel = 'Nije korisno';
    if (totals is Map) {
      total = _asInt(totals['total']);
      helpful = _asInt(totals['helpful']);
      notHelpful = _asInt(totals['notHelpful']);
      final hl = (totals['helpfulLabel'] ?? '').toString().trim();
      final nhl = (totals['notHelpfulLabel'] ?? '').toString().trim();
      if (hl.isNotEmpty) helpfulLabel = hl;
      if (nhl.isNotEmpty) notHelpfulLabel = nhl;
    }

    List<OperonixAiFeedbackSignalCountRow> rows(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => OperonixAiFeedbackSignalCountRow.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((r) => r.label.isNotEmpty)
          .toList(growable: false);
    }

    final note = (data['note'] ?? '').toString().trim();

    return OperonixAiFeedbackSignalsSnapshot(
      companyDisplayName: companyName,
      plantDisplayName: plantName,
      periodFrom: from,
      periodTo: to,
      total: total,
      helpful: helpful,
      notHelpful: notHelpful,
      helpfulLabel: helpfulLabel,
      notHelpfulLabel: notHelpfulLabel,
      bySurface: rows(data['bySurface']),
      byContract: rows(data['byContract']),
      byModule: rows(data['byModule']),
      topReasons: rows(data['topReasons']),
      note: note.isEmpty
          ? 'Agregirani signali za buduće poboljšanje. '
              'AI se ne fine-tunea i ne mijenja poslovne podatke.'
          : note,
    );
  }

  static int _asInt(Object? raw) {
    if (raw is int) return raw < 0 ? 0 : raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
