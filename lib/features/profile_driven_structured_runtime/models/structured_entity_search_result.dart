/// Rezultat entity search / scan resolver Callabla.
class StructuredEntitySearchResult {
  const StructuredEntitySearchResult({
    required this.id,
    required this.displayLabel,
    this.secondaryLabel,
    this.raw = const {},
  });

  final String id;
  final String displayLabel;
  final String? secondaryLabel;
  final Map<String, dynamic> raw;

  factory StructuredEntitySearchResult.fromMap(Map<String, dynamic> data) {
    final id = (data['id'] ?? data['uid'] ?? '').toString().trim();
    final code = (data['productCode'] ??
            data['materialCode'] ??
            data['orderCode'] ??
            data['chemicalCode'] ??
            data['employeeCode'] ??
            '')
        .toString()
        .trim();
    final name = (data['displayName'] ??
            data['productName'] ??
            data['email'] ??
            '')
        .toString()
        .trim();
    final label = _composeLabel(code: code, name: name, fallback: id);
    return StructuredEntitySearchResult(
      id: id,
      displayLabel: label,
      secondaryLabel: name.isNotEmpty && code.isNotEmpty ? name : null,
      raw: Map<String, dynamic>.from(data),
    );
  }

  static String _composeLabel({
    required String code,
    required String name,
    required String fallback,
  }) {
    if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
    if (code.isNotEmpty) return code;
    if (name.isNotEmpty) return name;
    return fallback;
  }
}

/// Odabrana entitet vrijednost u formi (header ili red tabele).
class StructuredEntitySelection {
  const StructuredEntitySelection({
    required this.fieldKey,
    required this.entityId,
    required this.displayLabel,
    this.raw = const {},
  });

  final String fieldKey;
  final String entityId;
  final String displayLabel;
  final Map<String, dynamic> raw;

  factory StructuredEntitySelection.fromSearchResult({
    required String fieldKey,
    required StructuredEntitySearchResult result,
    String? valueField,
  }) {
    final vf = (valueField ?? 'id').trim();
    final entityId = (result.raw[vf] ?? result.id).toString().trim();
    return StructuredEntitySelection(
      fieldKey: fieldKey,
      entityId: entityId.isEmpty ? result.id : entityId,
      displayLabel: result.displayLabel,
      raw: result.raw,
    );
  }
}

/// Rezultat scan resolvera.
class StructuredScanResolveResult {
  const StructuredScanResolveResult({
    required this.type,
    this.resolvedId,
    this.displayCode,
    this.displayName,
    this.message,
  });

  final String type;
  final String? resolvedId;
  final String? displayCode;
  final String? displayName;
  final String? message;

  bool get isKnown => type != 'unknown' && (resolvedId ?? '').trim().isNotEmpty;

  StructuredEntitySearchResult? toSearchResult() {
    if (!isKnown) return null;
    return StructuredEntitySearchResult(
      id: resolvedId!.trim(),
      displayLabel: StructuredEntitySearchResult._composeLabel(
        code: (displayCode ?? '').trim(),
        name: (displayName ?? '').trim(),
        fallback: resolvedId!.trim(),
      ),
      secondaryLabel: displayName,
      raw: {
        'id': resolvedId,
        'displayCode': displayCode,
        'displayName': displayName,
        'type': type,
      },
    );
  }

  factory StructuredScanResolveResult.fromMap(Map<String, dynamic> data) {
    return StructuredScanResolveResult(
      type: (data['type'] ?? 'unknown').toString().trim(),
      resolvedId: (data['resolvedId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['resolvedId'] ?? '').toString().trim(),
      displayCode: (data['displayCode'] ?? '').toString().trim().isEmpty
          ? null
          : (data['displayCode'] ?? '').toString().trim(),
      displayName: (data['displayName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['displayName'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim().isEmpty
          ? null
          : (data['message'] ?? '').toString().trim(),
    );
  }
}
