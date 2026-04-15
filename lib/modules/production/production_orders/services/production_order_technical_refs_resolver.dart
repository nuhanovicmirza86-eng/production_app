import '../../bom/services/bom_service.dart';

/// BOM i routing reference za kreiranje PN-a.
///
/// BOM (pojednostavljeno kao u Pantheonu): prvo keš na `products` (`bomId` /
/// `bomVersion`, automatski iz PRIMARY nakon rada na proizvodu), inače prva
/// aktivna sastavnica u `boms`: PRIMARY → SECONDARY → TRANSPORT.
///
/// Routing: ako na proizvodu nema `routingId` / `routingVersion`, koriste se
/// stabilni placeholderi dok se ne uvede kolekcija routings u aplikaciji.
class ProductionOrderTechnicalRefsResolver {
  ProductionOrderTechnicalRefsResolver({BomService? bomService})
    : _bom = bomService ?? BomService();

  final BomService _bom;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Placeholder kad proizvod nema aktivnu sastavnicu (isti princip kao routing).
  static const String bomPlaceholderId = 'unspecified';
  static const String bomPlaceholderVersion = '0';

  /// Vraća mapu s ključevima `bomId`, `bomVersion`, `routingId`, `routingVersion`.
  /// Ako nema aktivne BOM u bazi, vraća [bomPlaceholderId] / [bomPlaceholderVersion]
  /// umjesto da blokira kreiranje naloga.
  Future<Map<String, String>?> resolve({
    required String companyId,
    required String productId,
    String? productBomId,
    String? productBomVersion,
    String? productRoutingId,
    String? productRoutingVersion,
  }) async {
    final cid = companyId.trim();
    final pid = productId.trim();
    if (cid.isEmpty || pid.isEmpty) return null;

    var bomId = _s(productBomId);
    var bomVersion = _s(productBomVersion);

    if (bomId.isEmpty || bomVersion.isEmpty) {
      Map<String, dynamic>? found;
      for (final classification in ['PRIMARY', 'SECONDARY', 'TRANSPORT']) {
        final bom = await _bom.getActiveBomForProductAndClassification(
          companyId: cid,
          productId: pid,
          classification: classification,
        );
        if (bom != null) {
          found = bom;
          break;
        }
      }
      if (found != null) {
        bomId = _s(found['id']);
        bomVersion = _s(found['version']);
        if (bomVersion.isEmpty) bomVersion = 'v1';
      } else {
        bomId = bomPlaceholderId;
        bomVersion = bomPlaceholderVersion;
      }
    }

    if (bomId.isEmpty || bomVersion.isEmpty) {
      bomId = bomPlaceholderId;
      bomVersion = bomPlaceholderVersion;
    }

    var routingId = _s(productRoutingId);
    var routingVersion = _s(productRoutingVersion);
    if (routingId.isEmpty || routingVersion.isEmpty) {
      routingId = 'unspecified';
      routingVersion = '0';
    }

    return {
      'bomId': bomId,
      'bomVersion': bomVersion,
      'routingId': routingId,
      'routingVersion': routingVersion,
    };
  }
}
