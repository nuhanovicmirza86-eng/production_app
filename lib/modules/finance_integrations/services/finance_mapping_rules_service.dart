import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/finance_mapping_rule_model.dart';

class FinanceMappingRulesService {
  FinanceMappingRulesService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int _limit = 100;

  Stream<List<FinanceMappingRuleModel>> watchRules(String companyId) {
    final cid = companyId.trim();
    if (cid.isEmpty) {
      return Stream<List<FinanceMappingRuleModel>>.value(const []);
    }
    return _db
        .collection('finance_mapping_rules')
        .where('companyId', isEqualTo: cid)
        .limit(_limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(
                (d) => FinanceMappingRuleModel.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort((a, b) {
            final ap = a.priority;
            final bp = b.priority;
            if (ap != bp) return ap.compareTo(bp);
            return a.id.compareTo(b.id);
          });
          return list;
        });
  }
}
