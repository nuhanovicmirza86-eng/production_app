import 'package:cloud_firestore/cloud_firestore.dart';

class ProductLookupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getByCode({
    required String companyId,
    required String productCode,
  }) async {
    final code = productCode.trim();

    if (code.isEmpty) return null;

    final query = await _db
        .collection('products')
        .where('companyId', isEqualTo: companyId)
        .where('productCode', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final data = doc.data();

    return {
      'productId': doc.id,
      'productCode': data['productCode'],
      'productName': data['productName'],
      'productType': data['productType'],
      'defaultCustomerId': data['defaultCustomerId'],
      'customerName': data['customerName'],
      'bomId': data['bomId'],
      'bomVersion': data['bomVersion'],
      'routingId': data['routingId'],
      'routingVersion': data['routingVersion'],
    };
  }
}
