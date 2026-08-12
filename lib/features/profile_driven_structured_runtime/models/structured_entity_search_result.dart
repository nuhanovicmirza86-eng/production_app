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
    this.productId,
    this.productCode,
    this.message,
  });

  final String type;
  final String? resolvedId;
  final String? displayCode;
  final String? displayName;
  final String? productId;
  final String? productCode;
  final String? message;

  bool get isKnown => type != 'unknown' && (resolvedId ?? '').trim().isNotEmpty;

  StructuredEntitySearchResult? toSearchResult() {
    if (!isKnown) return null;
    final code = (displayCode ?? '').trim();
    final name = (displayName ?? '').trim();
    final id = resolvedId!.trim();
    final type = this.type.trim();
    final raw = <String, dynamic>{
      'id': id,
      'displayCode': displayCode,
      'displayName': displayName,
      'type': type,
    };
    if (type == 'product') {
      raw['productCode'] = code;
      raw['productName'] = name;
      raw['displayName'] = name;
    } else if (type == 'production_order') {
      raw['orderCode'] = code;
      raw['productionOrderCode'] = code;
      if (name.isNotEmpty) raw['productName'] = name;
      final pid = (productId ?? '').trim();
      final pCode = (productCode ?? '').trim();
      if (pid.isNotEmpty) raw['productId'] = pid;
      if (pCode.isNotEmpty) raw['productCode'] = pCode;
    }
    return StructuredEntitySearchResult(
      id: id,
      displayLabel: StructuredEntitySearchResult._composeLabel(
        code: code,
        name: name,
        fallback: id,
      ),
      secondaryLabel: name.isEmpty ? null : name,
      raw: raw,
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
      productId: (data['productId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['productId'] ?? '').toString().trim(),
      productCode: (data['productCode'] ?? '').toString().trim().isEmpty
          ? null
          : (data['productCode'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim().isEmpty
          ? null
          : (data['message'] ?? '').toString().trim(),
    );
  }
}
