import 'package:cloud_functions/cloud_functions.dart';

/// Mutacije [downtime_events] (Admin SDK) — usklađeno s 032c_downtime_events.rules.
class DowntimeCallableService {
  DowntimeCallableService({FirebaseFunctions? functions})
    : _f = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _f;

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final res = await _f.httpsCallable('mutateDowntimeEvent').call(body);
    final raw = res.data;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
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
