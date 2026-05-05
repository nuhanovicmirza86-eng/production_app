import 'package:cloud_functions/cloud_functions.dart';

/// Callable [upsertFinanceConnection] — samo metapodaci veze (bez tajni).
class FinanceConnectionCallableService {
  FinanceConnectionCallableService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> upsertFinanceConnection(Map<String, dynamic> payload) async {
    final res =
        await _functions.httpsCallable('upsertFinanceConnection').call(payload);
    final raw = res.data;
    if (raw is! Map) {
      throw StateError('Neočekivan odgovor poslužitelja.');
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['success'] != true) {
      throw StateError('Spremanje ERP veze nije uspjelo.');
    }
    final id = (data['connectionId'] ?? '').toString().trim();
    if (id.isEmpty) {
      throw StateError('Nedostaje identifikator veze u odgovoru.');
    }
    return id;
  }
}
