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
    final orderCode = (data['productionOrderCode'] ??
            data['orderCode'] ??
            '')
        .toString()
        .trim();
    // Production order search/scan: label = samo broj naloga.
    if (orderCode.isNotEmpty ||
        (data['type']?.toString().trim() == 'production_order')) {
      final raw = Map<String, dynamic>.from(data);
      if (orderCode.isNotEmpty) {
        raw['orderCode'] = orderCode;
        raw['productionOrderCode'] = orderCode;
      }
      final productLabel = productDisplayLabel(raw);
      return StructuredEntitySearchResult(
        id: id,
        displayLabel: productionOrderDisplayLabel(raw),
        secondaryLabel: productLabel == '—' ? null : productLabel,
        raw: raw,
      );
    }
    final code = (data['productCode'] ??
            data['materialCode'] ??
            data['chemicalCode'] ??
            data['employeeCode'] ??
            data['machineCode'] ??
            data['workbenchCode'] ??
            data['code'] ??
            '')
        .toString()
        .trim();
    final name = (data['displayName'] ??
            data['productName'] ??
            data['machineName'] ??
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
    // M1-I5-C7A — nikad ne pokazuj sirovi Firestore ID u UI.
    if (fallback.isNotEmpty && !_looksLikeInternalDocId(fallback)) {
      return fallback;
    }
    return '—';
  }

  /// Tipičan auto-ID (bez poslovne šifre s `-` / `_` / razmakom).
  static bool _looksLikeInternalDocId(String value) {
    final t = value.trim();
    if (t.length < 16 || t.length > 32) return false;
    if (t.contains('-') || t.contains('_') || t.contains(' ')) return false;
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(t);
  }

  /// Poslovna oznaka proizvodnog naloga (ne document id).
  static String productionOrderDisplayLabel(Map<String, dynamic> raw) {
    final code = (raw['productionOrderCode'] ??
            raw['orderCode'] ??
            raw['displayCode'] ??
            raw['code'] ??
            '')
        .toString()
        .trim();
    if (code.isNotEmpty && !_looksLikeInternalDocId(code)) return code;
    return '—';
  }

  /// Poslovna oznaka proizvoda: šifra — naziv.
  static String productDisplayLabel(Map<String, dynamic> raw) {
    final code = (raw['productCode'] ?? raw['displayCode'] ?? '')
        .toString()
        .trim();
    final name = (raw['productName'] ??
            raw['productNameSnapshot'] ??
            raw['displayName'] ??
            '')
        .toString()
        .trim();
    return _composeLabel(code: code, name: name, fallback: '');
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
    this.productName,
    this.machineId,
    this.machineName,
    this.machineCode,
    this.inputMaterialLot,
    this.plannedQty,
    this.message,
  });

  final String type;
  final String? resolvedId;
  final String? displayCode;
  final String? displayName;
  final String? productId;
  final String? productCode;
  final String? productName;
  final String? machineId;
  final String? machineName;
  final String? machineCode;
  final String? inputMaterialLot;
  final double? plannedQty;
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
      final pName = (productName ?? '').trim();
      if (pName.isNotEmpty) {
        raw['productName'] = pName;
      }
      final pid = (productId ?? '').trim();
      final pCode = (productCode ?? '').trim();
      if (pid.isNotEmpty) raw['productId'] = pid;
      if (pCode.isNotEmpty) raw['productCode'] = pCode;
      final mid = (machineId ?? '').trim();
      if (mid.isNotEmpty) raw['machineId'] = mid;
      final mName = (machineName ?? '').trim();
      if (mName.isNotEmpty) raw['machineName'] = mName;
      final mCode = (machineCode ?? '').trim();
      if (mCode.isNotEmpty) raw['machineCode'] = mCode;
      final lot = (inputMaterialLot ?? '').trim();
      if (lot.isNotEmpty) raw['inputMaterialLot'] = lot;
      if (plannedQty != null) raw['plannedQty'] = plannedQty;
      // Nalog polje = samo poslovni broj; proizvod ide u zasebno polje.
      return StructuredEntitySearchResult(
        id: id,
        displayLabel: StructuredEntitySearchResult.productionOrderDisplayLabel(
          raw,
        ),
        secondaryLabel: pName.isEmpty
            ? null
            : StructuredEntitySearchResult.productDisplayLabel(raw),
        raw: raw,
      );
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
    String? opt(String key) {
      final t = (data[key] ?? '').toString().trim();
      return t.isEmpty ? null : t;
    }

    double? numOpt(String key) {
      final v = data[key];
      if (v is num) return v.toDouble();
      if (v is String && v.trim().isNotEmpty) return double.tryParse(v.trim());
      return null;
    }

    return StructuredScanResolveResult(
      type: (data['type'] ?? 'unknown').toString().trim(),
      resolvedId: opt('resolvedId'),
      displayCode: opt('displayCode'),
      displayName: opt('displayName'),
      productId: opt('productId'),
      productCode: opt('productCode'),
      productName: opt('productName'),
      machineId: opt('machineId'),
      machineName: opt('machineName'),
      machineCode: opt('machineCode'),
      inputMaterialLot: opt('inputMaterialLot'),
      plannedQty: numOpt('plannedQty'),
      message: opt('message'),
    );
  }

  /// M1-I5-C7A — izbor iz autocomplete pretrage → isti payload kao QR sken.
  factory StructuredScanResolveResult.fromOrderSearchResult(
    StructuredEntitySearchResult item,
  ) {
    final raw = item.raw;
    String? opt(String key) {
      final t = (raw[key] ?? '').toString().trim();
      return t.isEmpty ? null : t;
    }

    final code = (raw['productionOrderCode'] ??
            raw['orderCode'] ??
            item.displayLabel)
        .toString()
        .trim();
    return StructuredScanResolveResult(
      type: 'production_order',
      resolvedId: item.id,
      displayCode: code.isEmpty ? null : code,
      displayName: opt('productName'),
      productId: opt('productId'),
      productCode: opt('productCode'),
      productName: opt('productName'),
      machineId: opt('machineId'),
      machineName: opt('machineName'),
      machineCode: opt('machineCode'),
      inputMaterialLot: opt('inputMaterialLot'),
      plannedQty: raw['plannedQty'] is num
          ? (raw['plannedQty'] as num).toDouble()
          : null,
    );
  }
}
