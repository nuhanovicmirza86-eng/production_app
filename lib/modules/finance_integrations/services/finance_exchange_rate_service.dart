import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Čitanje `exchange_rates/{yyyy-MM-dd}` (referentni tečaj za prikaz u aplikaciji).
class FinanceExchangeRateService {
  FinanceExchangeRateService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<Map<String, dynamic>?> getRatesForLocalDate(DateTime localDay) async {
    final ymd = DateFormat('yyyy-MM-dd').format(localDay);
    final snap = await _db.collection('exchange_rates').doc(ymd).get();
    return snap.data();
  }
}
