import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_connection_model.dart';

/// Čitanje ERP veza za tenant preko Callable [listFinanceConnections]
/// (`operonix-finance-integrations`). Bez direktnog Firestore reada na `(default)`.
class FinanceConnectionService {
  FinanceConnectionService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const String _functionsRegion = 'europe-west1';
  static const String _listCallableName = 'listFinanceConnections';

  final FirebaseFunctions _functions;

  /// Isti API kao prije M4-A; jednokratno učitavanje preko Callablea (nema live snapshota).
  Stream<List<FinanceConnectionModel>> watchConnections(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceConnectionModel>>.value(const []);
    }
    return Stream.fromFuture(_fetchConnections(cid));
  }

  Future<List<FinanceConnectionModel>> _fetchConnections(String companyId) async {
    final callable = _functions.httpsCallable(_listCallableName);
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId,
    });

    final data = response.data;
    if (data is! Map) {
      return const [];
    }

    final rawItems = data['items'];
    if (rawItems is! List) {
      return const [];
    }

    final list = <FinanceConnectionModel>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = (item['documentId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      item.remove('documentId');
      _normalizeCallableTimestamps(item);
      list.add(FinanceConnectionModel.fromFirestore(id, item));
    }

    list.sort((a, b) {
      final an = a.connectionName.toLowerCase();
      final bn = b.connectionName.toLowerCase();
      final c = an.compareTo(bn);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  /// Callable vraća timestamp kao `{seconds, nanoseconds}` — pretvori u [DateTime] za model.
  static void _normalizeCallableTimestamps(Map<String, dynamic> item) {
    for (final key in [
      'lastSuccessfulSyncAt',
      'lastConnectionTestAt',
      'updatedAt',
    ]) {
      final v = item[key];
      final dt = _parseCallableTimestamp(v);
      if (dt != null) {
        item[key] = dt;
      }
    }
  }

  static DateTime? _parseCallableTimestamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is Map) {
      final sec = v['seconds'];
      final ns = v['nanoseconds'];
      if (sec is num) {
        final millis =
            sec.toInt() * 1000 + ((ns is num ? ns.toInt() : 0) ~/ 1000000);
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      }
    }
    return null;
  }
}
