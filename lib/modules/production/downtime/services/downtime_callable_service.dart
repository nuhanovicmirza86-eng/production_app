import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../models/downtime_event_model.dart';

/// Čitanje i mutacije [downtime_events] (Admin SDK).
class DowntimeCallableService {
  DowntimeCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  Map<String, dynamic> _asStringKeyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  Future<Map<String, dynamic>> _callNamed(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _f.httpsCallable(name).call(body);
      return _asStringKeyMap(res.data);
    } catch (e) {
      throw Exception(AppErrorMapper.toMessage(e));
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    return _callNamed('mutateDowntimeEvent', body);
  }

  Future<({List<DowntimeEventModel> items, String? cursorId})> listEvents({
    required String companyId,
    required String plantKey,
    int limit = 400,
    bool descending = true,
    DateTime? startedAtFrom,
    DateTime? startedAtTo,
    String? cursorId,
  }) async {
    final body = <String, dynamic>{
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'limit': limit,
      'descending': descending,
    };
    if (startedAtFrom != null) {
      body['startedAtFrom'] = startedAtFrom.toUtc().toIso8601String();
    }
    if (startedAtTo != null) {
      body['startedAtTo'] = startedAtTo.toUtc().toIso8601String();
    }
    final c = (cursorId ?? '').trim();
    if (c.isNotEmpty) body['cursorId'] = c;

    final m = await _callNamed('listDowntimeEvents', body);
    final rawItems = m['items'];
    final items = <DowntimeEventModel>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        final map = _asStringKeyMap(row);
        final id = (map['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        items.add(DowntimeEventModel.fromMap(id, map));
      }
    }
    final next = (m['cursorId'] ?? '').toString().trim();
    return (items: items, cursorId: next.isEmpty ? null : next);
  }

  Future<({List<DowntimeCreateOrderOption> orders, List<DowntimeCreateProcessOption> processes})>
      listCreateOptions({
    required String companyId,
    required String plantKey,
  }) async {
    final m = await _callNamed('listDowntimeCreateOptions', {
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
    });
    final orders = <DowntimeCreateOrderOption>[];
    final rawOrders = m['orders'];
    if (rawOrders is List) {
      for (final row in rawOrders) {
        final map = _asStringKeyMap(row);
        final id = (map['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        orders.add(DowntimeCreateOrderOption.fromMap(id, map));
      }
    }
    final processes = <DowntimeCreateProcessOption>[];
    final rawProcs = m['processes'];
    if (rawProcs is List) {
      for (final row in rawProcs) {
        final map = _asStringKeyMap(row);
        final id = (map['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        processes.add(DowntimeCreateProcessOption.fromMap(id, map));
      }
    }
    return (orders: orders, processes: processes);
  }

  Future<DowntimeEventModel?> getEvent({
    required String companyId,
    required String downtimeId,
  }) async {
    final id = downtimeId.trim();
    final cid = companyId.trim();
    if (id.isEmpty || cid.isEmpty) return null;
    try {
      final m = await _callNamed('getDowntimeEvent', {
        'companyId': cid,
        'downtimeId': id,
      });
      final item = _asStringKeyMap(m['item']);
      final itemId = (item['id'] ?? '').toString().trim();
      if (itemId.isEmpty) return null;
      return DowntimeEventModel.fromMap(itemId, item);
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('nije pronađen') || msg.contains('not-found')) {
        return null;
      }
      rethrow;
    }
  }

  /// Vraća [downtimeId] s servera; [downtimeCode] u odgovoru ako treba.
  Future<String> create({
    required String companyId,
    required String plantKey,
    required Map<String, dynamic> create,
  }) async {
    final m = await _call({
      'action': 'create',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'create': create,
    });
    final id = m['downtimeId']?.toString() ?? '';
    if (id.isEmpty) {
      throw Exception('Server nije vratio downtimeId.');
    }
    return id;
  }

  Future<void> updateStatus({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String newStatus,
  }) async {
    await _call({
      'action': 'updateStatus',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'downtimeId': downtimeId.trim(),
      'newStatus': newStatus.trim(),
    });
  }

  Future<void> resolve({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorDisplayName,
    DateTime? endedAt,
  }) async {
    final body = <String, dynamic>{
      'action': 'resolve',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'downtimeId': downtimeId.trim(),
      'actorDisplayName': actorDisplayName.trim(),
    };
    if (endedAt != null) {
      body['endedAt'] = endedAt.toIso8601String();
    }
    await _call(body);
  }

  Future<void> verify({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorDisplayName,
  }) async {
    await _call({
      'action': 'verify',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'downtimeId': downtimeId.trim(),
      'actorDisplayName': actorDisplayName.trim(),
    });
  }

  Future<void> reject({
    required String downtimeId,
    required String companyId,
    required String plantKey,
    required String actorDisplayName,
    String? noteAppend,
  }) async {
    await _call({
      'action': 'reject',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'downtimeId': downtimeId.trim(),
      'actorDisplayName': actorDisplayName.trim(),
      if (noteAppend != null && noteAppend.trim().isNotEmpty)
        'noteAppend': noteAppend.trim(),
    });
  }

  Future<void> archive({
    required String downtimeId,
    required String companyId,
    required String plantKey,
  }) async {
    await _call({
      'action': 'archive',
      'companyId': companyId.trim(),
      'plantKey': plantKey.trim(),
      'downtimeId': downtimeId.trim(),
    });
  }
}

class DowntimeCreateOrderOption {
  const DowntimeCreateOrderOption({
    required this.id,
    required this.productionOrderCode,
    required this.productCode,
    required this.productName,
    required this.status,
    required this.workCenterId,
    required this.workCenterCode,
  });

  final String id;
  final String productionOrderCode;
  final String productCode;
  final String productName;
  final String status;
  final String workCenterId;
  final String workCenterCode;

  factory DowntimeCreateOrderOption.fromMap(String id, Map<String, dynamic> m) {
    String s(dynamic v) => (v ?? '').toString().trim();
    return DowntimeCreateOrderOption(
      id: id,
      productionOrderCode: s(m['productionOrderCode']),
      productCode: s(m['productCode']),
      productName: s(m['productName']),
      status: s(m['status']),
      workCenterId: s(m['workCenterId']),
      workCenterCode: s(m['workCenterCode']),
    );
  }
}

class DowntimeCreateProcessOption {
  const DowntimeCreateProcessOption({
    required this.id,
    required this.processCode,
    required this.name,
    required this.status,
    required this.isActive,
    required this.linkedWorkCenterIds,
  });

  final String id;
  final String processCode;
  final String name;
  final String status;
  final bool isActive;
  final List<String> linkedWorkCenterIds;

  factory DowntimeCreateProcessOption.fromMap(
    String id,
    Map<String, dynamic> m,
  ) {
    String s(dynamic v) => (v ?? '').toString().trim();
    final raw = m['linkedWorkCenterIds'];
    final linked = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final t = e.toString().trim();
        if (t.isNotEmpty) linked.add(t);
      }
    }
    return DowntimeCreateProcessOption(
      id: id,
      processCode: s(m['processCode']),
      name: s(m['name']),
      status: s(m['status']),
      isActive: m['isActive'] == true || s(m['status']) == 'active',
      linkedWorkCenterIds: linked,
    );
  }
}
