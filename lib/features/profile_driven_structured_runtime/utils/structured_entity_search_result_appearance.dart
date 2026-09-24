import '../../../core/access/production_access_helper.dart';
import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../catalog_evidence_runtime/utils/controlled_evidence_person_role_keys.dart';
import '../models/structured_entity_search_result.dart';

/// M1-I15-D-HOTFIX-09 — prikaz rezultata kontrolisanog pickera (bez raw ID / EN).
abstract final class StructuredEntitySearchResultAppearance {
  static bool isPersonField(String fieldKey) =>
      controlledEvidenceRoleKeysForPersonField(fieldKey) != null;

  static String title(StructuredEntitySearchResult item) {
    final label = item.displayLabel.trim();
    return label.isEmpty ? '—' : label;
  }

  /// Funkcija / tip entiteta za bedž (BCS).
  static String? badgeLabel({
    required ProductionStationProfileField field,
    required StructuredEntitySearchResult item,
  }) {
    if (isPersonField(field.key)) {
      return _personRoleBadge(field, item.raw);
    }
    return _entityTypeBadge(field);
  }

  /// Druga linija pored bedža: pogon samo za osobe.
  static String? trailingMeta({
    required ProductionStationProfileField field,
    String? plantDisplayLabel,
  }) {
    if (!isPersonField(field.key)) return null;
    return _safePlantLabel(plantDisplayLabel);
  }

  static String? _personRoleBadge(
    ProductionStationProfileField field,
    Map<String, dynamic> raw,
  ) {
    final fieldKey = field.key.trim();
    final jobTitle = (raw['jobTitle'] ?? '').toString().trim();
    if (jobTitle.isNotEmpty) {
      final fromJob = ProductionAccessHelper.displayRoleLabel(jobTitle);
      if (_isPresentableRole(fromJob)) return fromJob;
    }
    final role = (raw['role'] ?? '').toString().trim();
    if (role.isNotEmpty) {
      final normalized = ProductionAccessHelper.normalizeRole(role);
      if (normalized == ProductionAccessHelper.roleQualityControl) {
        return 'Kontrola kvaliteta';
      }
      final fromRole = ProductionAccessHelper.displayRoleLabel(role);
      if (_isPresentableRole(fromRole)) return fromRole;
    }
    final keys = controlledEvidenceRoleKeysForPersonField(fieldKey) ?? const [];
    if (field.label.contains('neposredni rukovodilac') ||
        keys.contains(ProductionAccessHelper.roleProductionManager)) {
      return 'Menadžer proizvodnje';
    }
    if (keys.contains(ProductionAccessHelper.roleProductionOperator) &&
        keys.length == 1) {
      return 'Operater proizvodnje';
    }
    if (keys.contains(ProductionAccessHelper.roleQualityOperator) &&
        keys.length == 1) {
      return 'Operater kvaliteta';
    }
    if (fieldKey == 'verifiedByEmployeeId') {
      return 'Kontrola kvaliteta';
    }
    if (keys.isNotEmpty) {
      final fromKey = ProductionAccessHelper.displayRoleLabel(keys.first);
      if (_isPresentableRole(fromKey)) return fromKey;
    }
    return null;
  }

  static String? _entityTypeBadge(ProductionStationProfileField field) {
    final strippedLabel = field.label.replaceAll('*', '').trim();
    if (strippedLabel == 'Komponenta') return 'Komponenta';
    if (strippedLabel == 'Hemikalija') return 'Hemikalija';
    final key = field.key.trim();
    switch (key) {
      case 'productId':
      case 'previousProductId':
      case 'nextProductId':
        return 'Proizvod';
      case 'materialId':
        return 'Materijal';
      case 'machineId':
        return 'Mašina';
      case 'workCenterId':
        return 'Radni centar';
      default:
        break;
    }
    final collection = (field.entityCollection ?? '').trim();
    switch (collection) {
      case 'products':
        return 'Proizvod';
      case 'chemicals':
        return 'Hemikalija';
      case 'assets':
        return 'Mašina';
      case 'work_centers':
        return 'Radni centar';
      default:
        return null;
    }
  }

  static String? _safePlantLabel(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty || t == '—' || t == '-') return null;
    if (RegExp(r'^PLANT_\d+$', caseSensitive: false).hasMatch(t)) return null;
    if (t.contains('_') && !t.contains(' ') && t == t.toUpperCase()) {
      return null;
    }
    return t;
  }

  static bool _isPresentableRole(String label) {
    final t = label.trim();
    if (t.isEmpty || t == '-') return false;
    if (t.contains('_')) return false;
    return true;
  }
}
