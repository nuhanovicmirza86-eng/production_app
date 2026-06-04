import 'package:cloud_functions/cloud_functions.dart';

class PartnerPick {
  final String id;
  final String code;
  final String name;

  const PartnerPick({required this.id, required this.code, required this.name});
}

/// Lookup kupaca/dobavljača za pickere (Callable read — B2).
class PartnersLookupService {
  PartnersLookupService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<PartnerPick> _rowsToPicks(List<Map<String, dynamic>> rows) {
    final out = <PartnerPick>[];
    for (final row in rows) {
      final id = _s(row['id']);
      final code = _s(row['code']);
      final name = _s(row['name']);
      if (id.isEmpty || (code.isEmpty && name.isEmpty)) continue;
      out.add(PartnerPick(id: id, code: code, name: name));
    }
    return out;
  }

  Future<List<PartnerPick>> searchCustomers({
    required String companyId,
    required String query,
    int limit = 80,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final res = await _functions
        .httpsCallable('listCommercialCustomers')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'limit': limit,
          if (query.trim().isNotEmpty) 'query': query.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Pretraga kupaca nije uspjela.');
    }
    return _rowsToPicks(_listOfMaps(data['customers']));
  }

  Future<List<PartnerPick>> searchSuppliers({
    required String companyId,
    required String query,
    int limit = 80,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) return const [];

    final res = await _functions
        .httpsCallable('listCommercialSuppliers')
        .call<Map<String, dynamic>>({
          'companyId': cid,
          'limit': limit,
          if (query.trim().isNotEmpty) 'query': query.trim(),
        });
    final data = res.data;
    if (data['success'] != true) {
      throw Exception('Pretraga dobavljača nije uspjela.');
    }
    return _rowsToPicks(_listOfMaps(data['suppliers']));
  }
}
