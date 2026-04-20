import 'package:cloud_firestore/cloud_firestore.dart';

class ProductLookupItem {
  final String productId;
  final String companyId;
  final String productCode;
  final String productName;
  final String? customerId;
  final String? customerName;
  final String? unit;
  final String status;
  final bool isActive;

  final String? bomId;
  final String? bomVersion;
  final String? routingId;
  final String? routingVersion;

  const ProductLookupItem({
    required this.productId,
    required this.companyId,
    required this.productCode,
    required this.productName,
    required this.status,
    required this.isActive,
    this.customerId,
    this.customerName,
    this.unit,
    this.bomId,
    this.bomVersion,
    this.routingId,
    this.routingVersion,
  });

  factory ProductLookupItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ProductLookupItem.fromMap(doc.id, doc.data());
  }

  factory ProductLookupItem.fromMap(String id, Map<String, dynamic> data) {
    return ProductLookupItem(
      productId: id,
      companyId: (data['companyId'] ?? '').toString().trim(),
      productCode: (data['productCode'] ?? '').toString().trim(),
      productName: (data['productName'] ?? '').toString().trim(),
      customerId: _readNullableString(
        data['defaultCustomerId'] ?? data['customerId'],
      ),
      customerName: _readNullableString(data['customerName']),
      unit: _readNullableString(data['unit']),
      status: (data['status'] ?? 'active').toString().trim().toLowerCase(),
      isActive: (data['isActive'] as bool?) ?? true,
      bomId: _readNullableString(data['bomId']),
      bomVersion: _readNullableString(data['bomVersion']),
      routingId: _readNullableString(data['routingId']),
      routingVersion: _readNullableString(data['routingVersion']),
    );
  }

  factory ProductLookupItem.fromDocumentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Product dokument nema podataka');
    }
    return ProductLookupItem.fromMap(doc.id, data);
  }

  Map<String, dynamic> toSelectionMap() {
    return <String, dynamic>{
      'productId': productId,
      'companyId': companyId,
      'productCode': productCode,
      'productName': productName,
      'customerId': customerId,
      'customerName': customerName,
      'unit': unit,
      'status': status,
      'isActive': isActive,
      'bomId': bomId,
      'bomVersion': bomVersion,
      'routingId': routingId,
      'routingVersion': routingVersion,
    };
  }

  static String? _readNullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}

class ProductLookupService {
  final FirebaseFirestore _firestore;

  ProductLookupService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Future<List<ProductLookupItem>> searchProducts({
    required String companyId,
    required String query,
    int limit = 10,
    bool onlyActive = true,
  }) async {
    final normalizedCompanyId = companyId.trim();
    final normalizedQuery = normalizeLookupInput(query);

    if (normalizedCompanyId.isEmpty) {
      throw Exception('Nedostaje companyId za pretragu proizvoda.');
    }

    if (normalizedQuery.isEmpty) {
      return const [];
    }

    Query<Map<String, dynamic>> firestoreQuery = _products
        .where('companyId', isEqualTo: normalizedCompanyId)
        .where('searchTokens', arrayContains: normalizedQuery)
        .limit(limit);

    if (onlyActive) {
      firestoreQuery = firestoreQuery.where('status', isEqualTo: 'active');
    }

    final snapshot = await firestoreQuery.get();

    final items = snapshot.docs.map(ProductLookupItem.fromDoc).where((item) {
      if (item.companyId != normalizedCompanyId) return false;
      if (item.productCode.isEmpty) return false;
      if (item.productName.isEmpty) return false;

      if (onlyActive && (!item.isActive || item.status != 'active')) {
        return false;
      }

      return true;
    }).toList();

    items.sort((a, b) {
      final aCodeStarts = normalizeLookupInput(
        a.productCode,
      ).startsWith(normalizedQuery);
      final bCodeStarts = normalizeLookupInput(
        b.productCode,
      ).startsWith(normalizedQuery);

      if (aCodeStarts != bCodeStarts) {
        return aCodeStarts ? -1 : 1;
      }

      final aNameStarts = normalizeLookupInput(
        a.productName,
      ).startsWith(normalizedQuery);
      final bNameStarts = normalizeLookupInput(
        b.productName,
      ).startsWith(normalizedQuery);

      if (aNameStarts != bNameStarts) {
        return aNameStarts ? -1 : 1;
      }

      final codeCompare = a.productCode.toLowerCase().compareTo(
        b.productCode.toLowerCase(),
      );
      if (codeCompare != 0) return codeCompare;

      return a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
    });

    return items;
  }

  Future<ProductLookupItem?> getByExactCode({
    required String companyId,
    required String productCode,
    bool onlyActive = true,
  }) async {
    final results = await searchProducts(
      companyId: companyId,
      query: productCode,
      limit: 20,
      onlyActive: onlyActive,
    );

    final normalizedCode = normalizeLookupInput(productCode);

    for (final item in results) {
      if (normalizeLookupInput(item.productCode) == normalizedCode) {
        return item;
      }
    }

    return null;
  }

  /// Učitava proizvod po Firestore ID-u (npr. `productId` na stavci narudžbe).
  Future<ProductLookupItem?> getByProductId({
    required String companyId,
    required String productId,
    bool onlyActive = true,
  }) async {
    final pid = productId.trim();
    final cid = companyId.trim();
    if (pid.isEmpty || cid.isEmpty) return null;

    final doc = await _products.doc(pid).get();
    if (!doc.exists) return null;

    final item = ProductLookupItem.fromDocumentSnapshot(doc);
    if (item.companyId != cid) return null;
    if (onlyActive && (!item.isActive || item.status != 'active')) {
      return null;
    }
    return item;
  }

  static String normalizeLookupInput(String value) {
    return value.trim().toLowerCase();
  }

  /// Kanonski zapis barkoda/QR-a za polje [scanAliases] (čuva vodeće nule).
  static String normalizeScanAlias(String value) {
    return value.trim();
  }

  /// Jedinstveni prefiksi za pretragu; uključuje i vanjske kodove.
  static List<String> buildSearchTokens({
    required String productCode,
    required String productName,
    List<String> scanAliases = const [],
  }) {
    final tokens = <String>{};

    void addPrefixesFromText(String input) {
      final normalized = normalizeLookupInput(input);
      if (normalized.isEmpty) return;

      for (int i = 1; i <= normalized.length; i++) {
        tokens.add(normalized.substring(0, i));
      }

      final parts = normalized
          .split(RegExp(r'[^a-z0-9]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);

      for (final part in parts) {
        for (int i = 1; i <= part.length; i++) {
          tokens.add(part.substring(0, i));
        }
      }
    }

    addPrefixesFromText(productCode);
    addPrefixesFromText(productName);

    for (final a in scanAliases) {
      final s = normalizeScanAlias(a);
      if (s.isEmpty) continue;
      addPrefixesFromText(s);
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 4) {
        addPrefixesFromText(digits);
      }
    }

    return tokens.toList()..sort();
  }

  /// Točan pogodak na jedan od upisanih vanjskih kodova (EAN, QR sadržaj, …).
  Future<ProductLookupItem?> getByScanAlias({
    required String companyId,
    required String raw,
  }) async {
    final key = normalizeScanAlias(raw);
    if (key.isEmpty || companyId.trim().isEmpty) return null;

    final snap = await _products
        .where('companyId', isEqualTo: companyId.trim())
        .where('scanAliases', arrayContains: key)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return ProductLookupItem.fromDoc(snap.docs.first);
  }

  /// Pokušaj: vanjski kod → zatim direktan [productId].
  Future<ProductLookupItem?> findProductByScanContent({
    required String companyId,
    required String raw,
    bool onlyActive = true,
  }) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final byAlias = await getByScanAlias(companyId: companyId, raw: trimmed);
    if (byAlias != null) {
      if (onlyActive && (!byAlias.isActive || byAlias.status != 'active')) {
        return null;
      }
      return byAlias;
    }

    return getByProductId(
      companyId: companyId,
      productId: trimmed,
      onlyActive: onlyActive,
    );
  }
}
