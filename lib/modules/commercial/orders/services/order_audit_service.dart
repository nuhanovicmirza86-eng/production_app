import 'package:cloud_firestore/cloud_firestore.dart';

class OrderAuditService {
  OrderAuditService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference get _orderStatusHistory =>
      _firestore.collection('order_status_history');

  CollectionReference get _orderLinkHistory =>
      _firestore.collection('order_link_history');

  Future<void> appendOrderStatusHistory({
    required String companyId,
    required String orderId,
    required String orderNumber,
    required String oldStatus,
    required String newStatus,
    required String changedBy,
    String? reason,
  }) async {
    final doc = _orderStatusHistory.doc();

    await doc.set({
      'id': doc.id,
      'companyId': companyId,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'reason': reason,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': changedBy,
    });
  }

  Future<void> appendOrderLinkHistory({
    required String companyId,
    required String orderId,
    required String orderItemId,
    required String productionOrderId,
    required String productionOrderCode,
    required String linkedBy,
  }) async {
    final doc = _orderLinkHistory.doc();

    await doc.set({
      'id': doc.id,
      'companyId': companyId,
      'orderId': orderId,
      'orderItemId': orderItemId,
      'productionOrderId': productionOrderId,
      'productionOrderCode': productionOrderCode,
      'linkedAt': FieldValue.serverTimestamp(),
      'linkedBy': linkedBy,
    });
  }
}
