import '../../profile_driven_structured_runtime/models/structured_entity_search_result.dart';
import '../../../modules/production/bom/services/bom_service.dart';
import 'operation_material_preparation_bom_picker.dart';

/// M1-I14-F — BOM-first picker proizvoda za Finalna kontrola / Kontrolisani komadi.
const finalControlBomNoBomMessage =
    'Nije pronađena aktivna primarna sastavnica za proizvod naloga. '
    'Proizvod možete privremeno odabrati iz šireg kataloga.';

const finalControlBomEmptyItemsMessage =
    'Primarna sastavnica nema stavki. '
    'Proizvod možete privremeno odabrati iz šireg kataloga.';

const finalControlBomLoadErrorMessage =
    'Učitavanje sastavnice nije uspjelo. '
    'Proizvod možete privremeno odabrati iz šireg kataloga.';

Future<OmpBomPickerState> loadFinalControlBomProductPickerState({
  required BomService bomService,
  required String companyId,
  required String productId,
}) {
  return loadOmpPrimaryBomPickerState(
    bomService: bomService,
    companyId: companyId,
    productId: productId,
    softFallbackNoBomMessage: finalControlBomNoBomMessage,
    softFallbackEmptyItemsMessage: finalControlBomEmptyItemsMessage,
    softFallbackLoadErrorMessage: finalControlBomLoadErrorMessage,
  );
}

/// Proizvod naloga + BOM stavke (bez duplikata). Bez raw ID u labeli.
List<StructuredEntitySearchResult> buildFinalControlBomProductChoices({
  required OmpBomPickerState bom,
  StructuredEntitySearchResult? orderProduct,
}) {
  final out = <StructuredEntitySearchResult>[];
  final seen = <String>{};

  void add(StructuredEntitySearchResult item) {
    final id = item.id.trim();
    if (id.isEmpty || !seen.add(id)) return;
    out.add(item);
  }

  if (orderProduct != null) {
    add(orderProduct);
  }
  for (final item in bom.items) {
    add(item);
  }
  return out;
}
