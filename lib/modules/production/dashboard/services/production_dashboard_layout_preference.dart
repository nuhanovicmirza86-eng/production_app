import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_dashboard_layout.dart';

class ProductionDashboardLayoutPreference {
  ProductionDashboardLayoutPreference._();

  static ProductionDashboardLayout readFromUserData(Map<String, dynamic>? data) {
    final prefs = data?['preferences'];
    if (prefs is! Map) {
      return ProductionDashboardLayout.standard;
    }
    final raw = prefs[ProductionDashboardLayout.preferenceKey];
    return ProductionDashboardLayout.fromStorage(raw?.toString());
  }

  static Stream<ProductionDashboardLayout> watch(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => readFromUserData(snap.data()));
  }

  static Future<void> save({
    required String uid,
    required ProductionDashboardLayout layout,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'preferences': {
          ProductionDashboardLayout.preferenceKey: layout.storageValue,
        },
      },
      SetOptions(merge: true),
    );
  }
}
