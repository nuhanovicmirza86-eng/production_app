/// Jedna pretpostavka scenarija (preset ili korisnik) iz Callable odgovora.
class FinanceCashFlowScenarioAssumptionEntry {
  const FinanceCashFlowScenarioAssumptionEntry({
    this.value,
    required this.unit,
    required this.source,
    required this.labelBa,
    required this.labelEn,
    this.descriptionBa,
    this.descriptionEn,
  });

  final double? value;
  final String unit;
  final String source;
  final String labelBa;
  final String labelEn;
  final String? descriptionBa;
  final String? descriptionEn;

  factory FinanceCashFlowScenarioAssumptionEntry.fromCallableMap(
    Map<String, dynamic> raw,
  ) {
    final v = raw['value'];
    return FinanceCashFlowScenarioAssumptionEntry(
      value: v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v')),
      unit: (raw['unit'] ?? '').toString(),
      source: (raw['source'] ?? '').toString(),
      labelBa: (raw['labelBa'] ?? '').toString(),
      labelEn: (raw['labelEn'] ?? '').toString(),
      descriptionBa: raw['descriptionBa']?.toString(),
      descriptionEn: raw['descriptionEn']?.toString(),
    );
  }

  String labelForLocale(bool english) =>
      english && labelEn.isNotEmpty ? labelEn : labelBa;

  String? descriptionForLocale(bool english) {
    final d = english ? descriptionEn : descriptionBa;
    if (d != null && d.isNotEmpty) return d;
    return english ? descriptionBa : descriptionEn;
  }

  bool get isPreset => source == 'preset';
  bool get isUser => source == 'user';
}

/// Mapa pretpostavk po kanonskom ključu.
class FinanceCashFlowScenarioAssumptions {
  const FinanceCashFlowScenarioAssumptions({
    required this.entries,
  });

  final Map<String, FinanceCashFlowScenarioAssumptionEntry> entries;

  factory FinanceCashFlowScenarioAssumptions.fromCallableMap(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return const FinanceCashFlowScenarioAssumptions(entries: {});
    final out = <String, FinanceCashFlowScenarioAssumptionEntry>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        out[entry.key] = FinanceCashFlowScenarioAssumptionEntry.fromCallableMap(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return FinanceCashFlowScenarioAssumptions(entries: out);
  }

  /// Flat map za what_if create/update Callable.
  Map<String, dynamic> toWhatIfPayload() {
    final out = <String, dynamic>{};
    for (final e in entries.entries) {
      out[e.key] = e.value.value;
    }
    return out;
  }
}
