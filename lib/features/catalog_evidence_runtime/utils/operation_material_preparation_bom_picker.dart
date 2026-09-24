import '../../../modules/production/bom/bom_item_traceability.dart';
import '../../../modules/production/bom/services/bom_service.dart';
import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';

/// M1-I9-B — stanje PRIMARY BOM-a za picker materijala (operation_material_preparation).
enum OmpBomPickerMode {
  /// Još nema productId / učitavanje.
  idle,
  loading,
  /// Aktivni PRIMARY + stavke — picker iz BOM-a.
  bomBound,
  /// Nema aktivnog PRIMARY ili prazne stavke — soft fallback na searchProducts.
  softFallback,
}

class OmpBomPickerState {
  const OmpBomPickerState({
    this.mode = OmpBomPickerMode.idle,
    this.productId = '',
    this.bomId = '',
    this.bomVersion = '',
    this.items = const [],
    this.errorMessage,
  });

  final OmpBomPickerMode mode;
  final String productId;
  final String bomId;
  final String bomVersion;
  final List<StructuredEntitySearchResult> items;
  final String? errorMessage;

  bool get isBomBound =>
      mode == OmpBomPickerMode.bomBound && items.isNotEmpty;

  bool get isSoftFallback => mode == OmpBomPickerMode.softFallback;

  OmpBomPickerState copyWith({
    OmpBomPickerMode? mode,
    String? productId,
    String? bomId,
    String? bomVersion,
    List<StructuredEntitySearchResult>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OmpBomPickerState(
      mode: mode ?? this.mode,
      productId: productId ?? this.productId,
      bomId: bomId ?? this.bomId,
      bomVersion: bomVersion ?? this.bomVersion,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Mapira `bom_items` u entity search rezultate (bez raw ID u labeli).
StructuredEntitySearchResult ompBomItemToSearchResult(
  Map<String, dynamic> item, {
  required String bomId,
  required String bomVersion,
}) {
  final componentId =
      (item['componentProductId'] ?? item['id'] ?? '').toString().trim();
  final code = (item['componentCode'] ?? '').toString().trim();
  final name = (item['componentName'] ?? '').toString().trim();
  final qty = item['qtyPerUnit'];
  final unit = (item['unit'] ?? '').toString().trim();
  final lineId = (item['lineId'] ?? item['id'] ?? '').toString().trim();

  final display = StructuredEntitySearchResult.productDisplayLabel({
    'productCode': code,
    'productName': name,
  });

  final qtyText = qty is num
      ? (qty % 1 == 0 ? qty.toInt().toString() : qty.toString())
      : (qty ?? '').toString().trim();
  final resolved = resolveBomItemTraceability(item);
  final secondaryParts = <String>[
    if (qtyText.isNotEmpty && unit.isNotEmpty) 'Normativ: $qtyText $unit',
    if (qtyText.isNotEmpty && unit.isEmpty) 'Normativ: $qtyText',
    if (qtyText.isEmpty && unit.isNotEmpty) 'JM: $unit',
    bomItemKindLabelBs(resolved.kind),
    if (!resolved.lotRequired) ompLotNotRequiredBanner,
  ];

  return StructuredEntitySearchResult(
    id: componentId,
    displayLabel: display == '—' ? (name.isNotEmpty ? name : code) : display,
    secondaryLabel: secondaryParts.isEmpty ? null : secondaryParts.join(' · '),
    raw: {
      'id': componentId,
      'productCode': code,
      'productName': name,
      'displayName': name,
      'componentProductId': componentId,
      'componentCode': code,
      'componentName': name,
      'qtyPerUnit': qty,
      'unit': unit,
      'bomId': bomId,
      'bomVersion': bomVersion,
      'bomItemLineId': lineId,
      'lineId': lineId,
      'source': 'bom_primary',
      bomItemFieldKind: resolved.kind,
      bomItemFieldTraceabilityMode: resolved.mode,
      bomItemFieldLotRequired: resolved.lotRequired,
    },
  );
}

Future<OmpBomPickerState> loadOmpPrimaryBomPickerState({
  required BomService bomService,
  required String companyId,
  required String productId,
  String softFallbackNoBomMessage =
      'Nije pronađena aktivna primarna sastavnica (BOM) za ovaj proizvod. '
      'Materijal možete privremeno odabrati iz kataloga.',
  String softFallbackEmptyItemsMessage =
      'Primarna sastavnica nema stavki. '
      'Materijal možete privremeno odabrati iz kataloga.',
  String softFallbackLoadErrorMessage =
      'Učitavanje sastavnice nije uspjelo. '
      'Materijal možete privremeno odabrati iz kataloga.',
}) async {
  final cid = companyId.trim();
  final pid = productId.trim();
  if (cid.isEmpty || pid.isEmpty) {
    return const OmpBomPickerState(mode: OmpBomPickerMode.idle);
  }

  try {
    final bom = await bomService.getActiveBomForProductAndClassification(
      companyId: cid,
      productId: pid,
      classification: 'PRIMARY',
    );
    if (bom == null) {
      return OmpBomPickerState(
        mode: OmpBomPickerMode.softFallback,
        productId: pid,
        errorMessage: softFallbackNoBomMessage,
      );
    }

    final bomId = (bom['id'] ?? '').toString().trim();
    var bomVersion = (bom['version'] ?? '').toString().trim();
    if (bomVersion.isEmpty) bomVersion = 'v1';

    final rawItems = await bomService.getBomItems(
      companyId: cid,
      bomId: bomId,
    );
    final mapped = rawItems
        .map(
          (item) => ompBomItemToSearchResult(
            item,
            bomId: bomId,
            bomVersion: bomVersion,
          ),
        )
        .where((r) => r.id.trim().isNotEmpty)
        .toList(growable: false);

    if (mapped.isEmpty) {
      return OmpBomPickerState(
        mode: OmpBomPickerMode.softFallback,
        productId: pid,
        bomId: bomId,
        bomVersion: bomVersion,
        errorMessage: softFallbackEmptyItemsMessage,
      );
    }

    return OmpBomPickerState(
      mode: OmpBomPickerMode.bomBound,
      productId: pid,
      bomId: bomId,
      bomVersion: bomVersion,
      items: mapped,
    );
  } catch (e) {
    return OmpBomPickerState(
      mode: OmpBomPickerMode.softFallback,
      productId: pid,
      errorMessage: softFallbackLoadErrorMessage,
    );
  }
}

/// Filtrira BOM stavke po upitu (šifra / naziv). Prazan upit = sve.
List<StructuredEntitySearchResult> filterOmpBomSearchResults({
  required List<StructuredEntitySearchResult> items,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<StructuredEntitySearchResult>.from(items);
  return items
      .where((item) {
        final code = (item.raw['productCode'] ?? item.raw['componentCode'] ?? '')
            .toString()
            .toLowerCase();
        final name = (item.raw['productName'] ??
                item.raw['componentName'] ??
                item.raw['displayName'] ??
                '')
            .toString()
            .toLowerCase();
        final label = item.displayLabel.toLowerCase();
        return code.contains(q) || name.contains(q) || label.contains(q);
      })
      .toList(growable: false);
}
