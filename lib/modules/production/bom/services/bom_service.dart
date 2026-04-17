import 'package:cloud_firestore/cloud_firestore.dart';

import '../../products/services/product_service.dart';

class BomService {
  BomService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _boms =>
      _firestore.collection('boms');

  CollectionReference<Map<String, dynamic>> get _bomItems =>
      _firestore.collection('bom_items');

  String _s(dynamic value) => (value ?? '').toString().trim();

  double _d(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_s(value).replaceAll(',', '.')) ?? 0;
  }

  int _extractVersionNumber(String version) {
    final raw = version.trim().toLowerCase();
    if (raw.startsWith('v')) {
      return int.tryParse(raw.substring(1)) ?? 1;
    }
    return int.tryParse(raw) ?? 1;
  }

  String _nextVersion(String currentVersion) {
    final current = _extractVersionNumber(currentVersion);
    return 'v${current + 1}';
  }

  // ================= BOM HEADER =================

  /// Klasifikacija sastavnice (`PRIMARY` / `SECONDARY` / `TRANSPORT`) s dokumenta `boms/{bomId}`.
  Future<String?> getClassificationForBomId(String bomId) async {
    final id = _s(bomId);
    if (id.isEmpty || id == 'unspecified') return null;
    final doc = await _boms.doc(id).get();
    if (!doc.exists) return null;
    final c = _s(doc.data()?['classification']);
    return c.isEmpty ? null : c;
  }

  Future<Map<String, dynamic>?> getActiveBomForProductAndClassification({
    required String companyId,
    required String productId,
    required String classification,
  }) async {
    final query = await _boms
        .where('companyId', isEqualTo: companyId)
        .where('productId', isEqualTo: productId)
        .where('classification', isEqualTo: classification)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  Future<String> createBom({
    required String companyId,
    required String productId,
    required String classification,
    required String createdBy,
    String version = 'v1',
  }) async {
    final existing = await getActiveBomForProductAndClassification(
      companyId: companyId,
      productId: productId,
      classification: classification,
    );

    if (existing != null) {
      return _s(existing['id']);
    }

    final docRef = _boms.doc();

    await docRef.set({
      'id': docRef.id,
      'companyId': companyId,
      'productId': productId,
      'classification': classification,
      'version': version,
      'isActive': true,
      'previousBomId': null, // ✅ NOVO
      'effectiveFrom': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': createdBy,
    });

    return docRef.id;
  }

  Future<String> getOrCreateActiveBom({
    required String companyId,
    required String productId,
    required String classification,
    required String createdBy,
    String version = 'v1',
  }) async {
    final existing = await getActiveBomForProductAndClassification(
      companyId: companyId,
      productId: productId,
      classification: classification,
    );

    if (existing != null) {
      return _s(existing['id']);
    }

    return createBom(
      companyId: companyId,
      productId: productId,
      classification: classification,
      createdBy: createdBy,
      version: version,
    );
  }

  Future<void> deactivateBom({
    required String bomId,
    required String updatedBy,
  }) async {
    await _boms.doc(bomId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': updatedBy,
    });
  }

  Future<String> createNewBomVersion({
    required String companyId,
    required String productId,
    required String classification,
    required String changedBy,
    String? version,
  }) async {
    final active = await getActiveBomForProductAndClassification(
      companyId: companyId,
      productId: productId,
      classification: classification,
    );

    if (active == null) {
      return createBom(
        companyId: companyId,
        productId: productId,
        classification: classification,
        createdBy: changedBy,
        version: version ?? 'v1',
      );
    }

    final activeBomId = _s(active['id']);
    final currentVersion = _s(active['version']).isEmpty
        ? 'v1'
        : _s(active['version']);
    final nextVersion = version ?? _nextVersion(currentVersion);

    final existingItems = await getBomItems(
      companyId: companyId,
      bomId: activeBomId,
    );

    final newBomRef = _boms.doc();
    final batch = _firestore.batch();

    batch.update(_boms.doc(activeBomId), {
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': changedBy,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': changedBy,
    });

    batch.set(newBomRef, {
      'id': newBomRef.id,
      'companyId': companyId,
      'productId': productId,
      'classification': classification,
      'version': nextVersion,
      'isActive': true,
      'previousBomId': activeBomId, // ✅ KLJUČNO
      'effectiveFrom': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': changedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': changedBy,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': changedBy,
    });

    for (final item in existingItems) {
      final itemRef = _bomItems.doc();

      batch.set(itemRef, {
        'id': itemRef.id,
        'lineId': _s(item['lineId']).isEmpty ? itemRef.id : _s(item['lineId']),
        'companyId': companyId,
        'bomId': newBomRef.id,
        'componentProductId': _s(item['componentProductId']),
        'componentCode': _s(item['componentCode']),
        'componentName': _s(item['componentName']),
        'qtyPerUnit': _d(item['qtyPerUnit']),
        'unit': _s(item['unit']),
        'note': _s(item['note']),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': changedBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': changedBy,
      });
    }

    await batch.commit();

    return newBomRef.id;
  }

  // ================= BOM ITEMS =================

  Future<List<Map<String, dynamic>>> getBomItems({
    required String companyId,
    required String bomId,
  }) async {
    final query = await _bomItems
        .where('companyId', isEqualTo: companyId)
        .where('bomId', isEqualTo: bomId)
        .get();

    final items = query.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    items.sort((a, b) {
      final codeA = _s(a['componentCode']).toLowerCase();
      final codeB = _s(b['componentCode']).toLowerCase();
      return codeA.compareTo(codeB);
    });

    return items;
  }

  Future<String> addBomItem({
    required String companyId,
    required String bomId,
    required String componentProductId,
    required String componentCode,
    required String componentName,
    required double qtyPerUnit,
    required String unit,
    required String createdBy,
    String? note,
  }) async {
    final docRef = _bomItems.doc();

    await docRef.set({
      'id': docRef.id,
      'lineId': docRef.id,
      'companyId': companyId,
      'bomId': bomId,
      'componentProductId': componentProductId,
      'componentCode': componentCode,
      'componentName': componentName,
      'qtyPerUnit': qtyPerUnit,
      'unit': unit,
      'note': note ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
    });

    return docRef.id;
  }

  Future<void> updateBomItem({
    required String itemId,
    required double qtyPerUnit,
    required String unit,
    String? note,
    required String updatedBy,
  }) async {
    await _bomItems.doc(itemId).update({
      'qtyPerUnit': qtyPerUnit,
      'unit': unit,
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Future<void> deleteBomItem({required String itemId}) async {
    await _bomItems.doc(itemId).delete();
  }

  // ================= HELPERS =================

  Future<Map<String, dynamic>> ensureBomAndLoad({
    required String companyId,
    required String productId,
    required String classification,
    required String userId,
  }) async {
    final bomId = await getOrCreateActiveBom(
      companyId: companyId,
      productId: productId,
      classification: classification,
      createdBy: userId,
    );

    final bomDoc = await _boms.doc(bomId).get();
    final bomData = bomDoc.data() ?? <String, dynamic>{};

    final items = await getBomItems(companyId: companyId, bomId: bomId);

    return {
      'bom': {'id': bomDoc.id, ...bomData},
      'items': items,
    };
  }

  Future<void> replaceBomItems({
    required String companyId,
    required String bomId,
    required List<Map<String, dynamic>> items,
    required String userId,
  }) async {
    final existing = await _bomItems
        .where('companyId', isEqualTo: companyId)
        .where('bomId', isEqualTo: bomId)
        .get();

    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final item in items) {
      final docRef = _bomItems.doc();

      batch.set(docRef, {
        'id': docRef.id,
        'lineId': _s(item['lineId']).isEmpty ? docRef.id : _s(item['lineId']),
        'companyId': companyId,
        'bomId': bomId,
        'componentProductId': _s(item['componentProductId']),
        'componentCode': _s(item['componentCode']),
        'componentName': _s(item['componentName']),
        'qtyPerUnit': _d(item['qtyPerUnit']),
        'unit': _s(item['unit']),
        'note': _s(item['note']),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    }

    batch.update(_boms.doc(bomId), {
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': userId,
    });

    await batch.commit();
  }

  /// Pantheon-stil: jedna glavna sastavnica = aktivna PRIMARY u `boms`; na `products`
  /// upisuje se `bomId` / `bomVersion` kao keš za šifarnik i proizvodne naloge.
  Future<void> syncActivePrimaryBomToProduct({
    required String companyId,
    required String productId,
    required String updatedBy,
  }) async {
    final cid = companyId.trim();
    final pid = productId.trim();
    final uid = updatedBy.trim();
    if (cid.isEmpty || pid.isEmpty || uid.isEmpty) return;

    final active = await getActiveBomForProductAndClassification(
      companyId: cid,
      productId: pid,
      classification: 'PRIMARY',
    );

    final productService = ProductService(firestore: _firestore);

    if (active == null) {
      await productService.updateProduct(
        productId: pid,
        companyId: cid,
        updatedBy: uid,
        bomId: '',
        bomVersion: '',
      );
      return;
    }

    var ver = _s(active['version']);
    if (ver.isEmpty) ver = 'v1';

    await productService.updateProduct(
      productId: pid,
      companyId: cid,
      updatedBy: uid,
      bomId: _s(active['id']),
      bomVersion: ver,
    );
  }
}
