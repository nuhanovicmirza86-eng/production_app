import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:production_app/modules/personal/work_time/models/work_time_rules_draft.dart';

/// Učitavanje / spremanje [WorkTimeRulesDraft] preko `workTimeGetRules` / `workTimeSetRules` (europe-west1).
class WorkTimeRulesService {
  WorkTimeRulesService({FirebaseFunctions? functions})
    : _fn = functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  Future<WorkTimeRulesDraft> getRules({
    required String companyId,
    required String plantKey,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return WorkTimeRulesDraft.initial;
    }
    final c = _fn.httpsCallable('workTimeGetRules');
    final r = await c.call(<String, dynamic>{
      'companyId': cid,
      'plantKey': plantKey.trim(),
    });
    final d = r.data;
    if (d is! Map) {
      return WorkTimeRulesDraft.initial;
    }
    final m = Map<String, dynamic>.from(d);
    m.removeWhere(
      (k, _) => k.startsWith('_') || k == 'plantKey' || k == 'updatedAt',
    );
    return WorkTimeRulesDraft.fromJson(m);
  }

  /// Vraća `true` pri uspjehu, `false` pri grešci (poruka u [onMessage] / debug).
  Future<bool> setRules({
    required String companyId,
    required String plantKey,
    required WorkTimeRulesDraft rules,
    void Function(String message)? onError,
  }) async {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      onError?.call('Nedostaje companyId.');
      return false;
    }
    try {
      final c = _fn.httpsCallable('workTimeSetRules');
      await c.call(<String, dynamic>{
        'companyId': cid,
        'plantKey': plantKey.trim(),
        'rules': rules.toJson(),
      });
      return true;
    } catch (e, st) {
      debugPrint('workTimeSetRules: $e $st');
      onError?.call('Spremanje nije uspjelo. Provjerite ulogu i mrežu.');
      return false;
    }
  }
}
