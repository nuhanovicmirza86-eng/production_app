import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_lookup_service.dart';

class ProductService {
  final FirebaseFirestore _firestore;

  ProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  String _s(dynamic value) => (value ?? '').toString().trim();

  double? _readDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(_s(v).replaceAll(',', '.'));
  }

  /// Usporedba za update (uključuje „prazno“: [next] ≤ 0 tretira kao brisanje).
  bool _almostEqualDouble(double? cur, double? next) {
    if (next == null) return true;
    if (next <= 0) return cur == null || cur <= 0;
    if (cur == null) return false;
    return (cur - next).abs() < 1e-9;
  }

  /// Maks. broj vanjskih barkodova/QR po dokumentu `products`.
  static const int maxScanAliasesForProduct = 20;

  List<String> _normalizeScanAliasesList(List<String>? input) {
    if (input == null || input.isEmpty) return [];
    final out = <String>[];
    final seen = <String>{};
    for (final s in input) {
      final a = ProductLookupService.normalizeScanAlias(s);
      if (a.isEmpty) continue;
      if (seen.add(a)) out.add(a);
    }
    return out;
  }

  List<String> _readScanAliasesFromDoc(Map<String, dynamic> data) {
    final raw = data['scanAliases'];
    if (raw is! List) return [];
    return _normalizeScanAliasesList(raw.map((e) => e.toString()).toList());
  }

  bool _scanAliasListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  Future<void> _ensureScanAliasesUnique({
    required String companyId,
    required List<String> aliases,
    String? excludeProductId,
  }) async {
    for (final a in aliases) {
      final q = await _products
          .where('companyId', isEqualTo: companyId)
          .where('scanAliases', arrayContains: a)
          .limit(5)
          .get();

      for (final doc in q.docs) {
        if (excludeProductId != null && doc.id == excludeProductId) {
          continue;
        }
        throw Exception(
          'Vanjski barkod/QR "$a" je već dodijeljen drugom proizvodu.',
        );
      }
    }
  }

  Future<void> _ensureUniqueProductCode({
    required String companyId,
    required String productCode,
    String? excludeProductId,
  }) async {
    final query = await _products
        .where('companyId', isEqualTo: companyId)
        .where('productCode', isEqualTo: productCode)
        .limit(10)
        .get();

    for (final doc in query.docs) {
      if (excludeProductId != null && doc.id == excludeProductId) {
        continue;
      }

      throw Exception('Proizvod sa ovom šifrom već postoji.');
    }
  }

  Map<String, dynamic> _buildCreatePayload({
    required String companyId,
    required String productCode,
    required String productName,
    required String status,
    required String createdBy,
    required String updatedBy,
    String? unit,
    String? description,
    String? customerId,
    String? customerName,
    String? defaultPlantKey,
    String? bomId,
    String? bomVersion,
    String? routingId,
    String? routingVersion,
    double? packagingQty,
    String? secondaryClassificationCode,
    String? secondaryClassificationDescription,
    double? standardUnitPrice,
    String? currency,
    bool isActive = true,
    bool? lotTrackingRequired,
    int? shelfLifeDays,
    double? minStockQty,
    double? maxStockQty,
    double? idealCycleTimeSeconds,
    List<String> scanAliases = const [],
  }) {
    final now = DateTime.now();

    final normalizedCompanyId = companyId.trim();
    final normalizedProductCode = productCode.trim();
    final normalizedProductName = productName.trim();
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedCreatedBy = createdBy.trim();
    final normalizedUpdatedBy = updatedBy.trim();

    final normalizedUnit = _s(unit);
    final normalizedDescription = _s(description);
    final normalizedCustomerId = _s(customerId);
    final normalizedCustomerName = _s(customerName);
    final normalizedDefaultPlantKey = _s(defaultPlantKey);
    final normalizedBomId = _s(bomId);
    final normalizedBomVersion = _s(bomVersion);
    final normalizedRoutingId = _s(routingId);
    final normalizedRoutingVersion = _s(routingVersion);
    final secCode = _s(secondaryClassificationCode);
    final secDesc = _s(secondaryClassificationDescription);
    final cur = _s(currency);

    final aliasList = _normalizeScanAliasesList(scanAliases);
    if (aliasList.length > maxScanAliasesForProduct) {
      throw Exception(
        'Najviše $maxScanAliasesForProduct vanjskih barkodova/QR po proizvodu.',
      );
    }

    final payload = <String, dynamic>{
      'companyId': normalizedCompanyId,
      'productCode': normalizedProductCode,
      'productName': normalizedProductName,
      'status': normalizedStatus,
      'isActive': isActive,
      'createdAt': now,
      'createdBy': normalizedCreatedBy,
      'updatedAt': now,
      'updatedBy': normalizedUpdatedBy,
      'searchTokens': ProductLookupService.buildSearchTokens(
        productCode: normalizedProductCode,
        productName: normalizedProductName,
        scanAliases: aliasList,
      ),
    };

    if (aliasList.isNotEmpty) {
      payload['scanAliases'] = aliasList;
    }

    if (normalizedUnit.isNotEmpty) {
      payload['unit'] = normalizedUnit;
    }

    if (normalizedDescription.isNotEmpty) {
      payload['description'] = normalizedDescription;
    }

    if (normalizedCustomerId.isNotEmpty) {
      payload['customerId'] = normalizedCustomerId;
      payload['defaultCustomerId'] = normalizedCustomerId;
    }

    if (normalizedCustomerName.isNotEmpty) {
      payload['customerName'] = normalizedCustomerName;
    }

    if (normalizedDefaultPlantKey.isNotEmpty) {
      payload['defaultPlantKey'] = normalizedDefaultPlantKey;
    }

    if (normalizedBomId.isNotEmpty) {
      payload['bomId'] = normalizedBomId;
    }

    if (normalizedBomVersion.isNotEmpty) {
      payload['bomVersion'] = normalizedBomVersion;
    }

    if (normalizedRoutingId.isNotEmpty) {
      payload['routingId'] = normalizedRoutingId;
    }

    if (normalizedRoutingVersion.isNotEmpty) {
      payload['routingVersion'] = normalizedRoutingVersion;
    }

    if (packagingQty != null && packagingQty > 0) {
      payload['packagingQty'] = packagingQty;
    }

    if (secCode.isNotEmpty) {
      payload['secondaryClassificationCode'] = secCode;
    }
    if (secDesc.isNotEmpty) {
      payload['secondaryClassificationDescription'] = secDesc;
    }
    if (standardUnitPrice != null && standardUnitPrice > 0) {
      payload['standardUnitPrice'] = standardUnitPrice;
    }
    if (cur.isNotEmpty) {
      payload['currency'] = cur;
    }

    if (lotTrackingRequired != null) {
      payload['lotTrackingRequired'] = lotTrackingRequired;
    }
    if (shelfLifeDays != null && shelfLifeDays > 0) {
      payload['shelfLifeDays'] = shelfLifeDays;
    }
    if (minStockQty != null && minStockQty > 0) {
      payload['minStockQty'] = minStockQty;
    }
    if (maxStockQty != null && maxStockQty > 0) {
      payload['maxStockQty'] = maxStockQty;
    }

    if (idealCycleTimeSeconds != null && idealCycleTimeSeconds > 0) {
      payload['idealCycleTimeSeconds'] = idealCycleTimeSeconds;
    }

    return payload;
  }

  Future<String> createProduct({
    required String companyId,
    required String productCode,
    required String productName,
    required String createdBy,
    String status = 'active',
    String? unit,
    String? description,
    String? customerId,
    String? customerName,
    String? defaultPlantKey,
    String? bomId,
    String? bomVersion,
    String? routingId,
    String? routingVersion,
    double? packagingQty,
    String? secondaryClassificationCode,
    String? secondaryClassificationDescription,
    double? standardUnitPrice,
    String? currency,
    bool isActive = true,
    bool? lotTrackingRequired,
    int? shelfLifeDays,
    double? minStockQty,
    double? maxStockQty,
    double? idealCycleTimeSeconds,
    List<String>? scanAliases,
  }) async {
    final normalizedCompanyId = companyId.trim();
    final normalizedProductCode = productCode.trim();
    final normalizedProductName = productName.trim();
    final normalizedCreatedBy = createdBy.trim();
    final normalizedStatus = status.trim().toLowerCase();

    if (normalizedCompanyId.isEmpty) {
      throw Exception('Nedostaje podatak o kompaniji. Obrati se administratoru.');
    }

    if (normalizedProductCode.isEmpty) {
      throw Exception('Šifra proizvoda je obavezna.');
    }

    if (normalizedProductName.isEmpty) {
      throw Exception('Naziv proizvoda je obavezan.');
    }

    if (normalizedCreatedBy.isEmpty) {
      throw Exception('createdBy je obavezan.');
    }

    if (normalizedStatus != 'active' && normalizedStatus != 'inactive') {
      throw Exception('Status proizvoda mora biti active ili inactive.');
    }

    await _ensureUniqueProductCode(
      companyId: normalizedCompanyId,
      productCode: normalizedProductCode,
    );

    final normalizedAliases = _normalizeScanAliasesList(scanAliases);
    if (normalizedAliases.isNotEmpty) {
      await _ensureScanAliasesUnique(
        companyId: normalizedCompanyId,
        aliases: normalizedAliases,
      );
    }

    final docRef = _products.doc();

    final payload = _buildCreatePayload(
      companyId: normalizedCompanyId,
      productCode: normalizedProductCode,
      productName: normalizedProductName,
      status: normalizedStatus,
      createdBy: normalizedCreatedBy,
      updatedBy: normalizedCreatedBy,
      unit: unit,
      description: description,
      customerId: customerId,
      customerName: customerName,
      defaultPlantKey: defaultPlantKey,
      bomId: bomId,
      bomVersion: bomVersion,
      routingId: routingId,
      routingVersion: routingVersion,
      packagingQty: packagingQty,
      secondaryClassificationCode: secondaryClassificationCode,
      secondaryClassificationDescription: secondaryClassificationDescription,
      standardUnitPrice: standardUnitPrice,
      currency: currency,
      isActive: isActive,
      lotTrackingRequired: lotTrackingRequired,
      shelfLifeDays: shelfLifeDays,
      minStockQty: minStockQty,
      maxStockQty: maxStockQty,
      idealCycleTimeSeconds: idealCycleTimeSeconds,
      scanAliases: normalizedAliases,
    );

    await docRef.set(payload);

    return docRef.id;
  }

  Future<void> updateProduct({
    required String productId,
    required String companyId,
    required String updatedBy,
    String? productCode,
    String? productName,
    String? status,
    String? unit,
    String? description,
    String? customerId,
    String? customerName,
    String? defaultPlantKey,
    String? bomId,
    String? bomVersion,
    String? routingId,
    String? routingVersion,
    double? packagingQty,
    String? secondaryClassificationCode,
    String? secondaryClassificationDescription,
    double? standardUnitPrice,
    String? currency,
    bool? isActive,
    bool? lotTrackingRequired,
    int? shelfLifeDays,
    double? minStockQty,
    double? maxStockQty,
    double? idealCycleTimeSeconds,
    List<String>? scanAliases,
  }) async {
    final normalizedProductId = productId.trim();
    final normalizedCompanyId = companyId.trim();
    final normalizedUpdatedBy = updatedBy.trim();

    if (normalizedProductId.isEmpty) {
      throw Exception('productId je obavezan.');
    }

    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }

    if (normalizedUpdatedBy.isEmpty) {
      throw Exception('updatedBy je obavezan.');
    }

    final docRef = _products.doc(normalizedProductId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('Proizvod ne postoji.');
    }

    final current = doc.data();
    if (current == null) {
      throw Exception('Podaci proizvoda nedostaju.');
    }

    if (_s(current['companyId']) != normalizedCompanyId) {
      throw Exception('Nemaš pristup ovom proizvodu.');
    }

    final nextProductCode = productCode != null
        ? productCode.trim()
        : _s(current['productCode']);
    final nextProductName = productName != null
        ? productName.trim()
        : _s(current['productName']);
    final nextStatus = status != null
        ? status.trim().toLowerCase()
        : _s(current['status']).toLowerCase();

    if (nextProductCode.isEmpty) {
      throw Exception('Šifra proizvoda je obavezna.');
    }

    if (nextProductName.isEmpty) {
      throw Exception('Naziv proizvoda je obavezan.');
    }

    if (nextStatus != 'active' && nextStatus != 'inactive') {
      throw Exception('Status proizvoda mora biti active ili inactive.');
    }

    final currentProductCode = _s(current['productCode']);
    if (nextProductCode != currentProductCode) {
      await _ensureUniqueProductCode(
        companyId: normalizedCompanyId,
        productCode: nextProductCode,
        excludeProductId: normalizedProductId,
      );
    }

    final currentAliases = _readScanAliasesFromDoc(current);
    final List<String> aliasesForTokens;
    if (scanAliases == null) {
      aliasesForTokens = currentAliases;
    } else {
      final n = _normalizeScanAliasesList(scanAliases);
      if (n.length > maxScanAliasesForProduct) {
        throw Exception(
          'Najviše $maxScanAliasesForProduct vanjskih barkodova/QR po proizvodu.',
        );
      }
      if (n.isNotEmpty) {
        await _ensureScanAliasesUnique(
          companyId: normalizedCompanyId,
          aliases: n,
          excludeProductId: normalizedProductId,
        );
      }
      aliasesForTokens = n;
    }

    final updates = <String, dynamic>{
      'productCode': nextProductCode,
      'productName': nextProductName,
      'status': nextStatus,
      'updatedAt': DateTime.now(),
      'updatedBy': normalizedUpdatedBy,
      'searchTokens': ProductLookupService.buildSearchTokens(
        productCode: nextProductCode,
        productName: nextProductName,
        scanAliases: aliasesForTokens,
      ),
    };

    if (scanAliases != null) {
      if (aliasesForTokens.isEmpty) {
        updates['scanAliases'] = FieldValue.delete();
      } else {
        updates['scanAliases'] = aliasesForTokens;
      }
    }

    if (isActive != null) {
      updates['isActive'] = isActive;
    }

    if (unit != null) {
      final value = unit.trim();
      if (value.isEmpty) {
        updates['unit'] = FieldValue.delete();
      } else {
        updates['unit'] = value;
      }
    }

    if (description != null) {
      final value = description.trim();
      if (value.isEmpty) {
        updates['description'] = FieldValue.delete();
      } else {
        updates['description'] = value;
      }
    }

    if (customerId != null) {
      final value = customerId.trim();
      if (value.isEmpty) {
        updates['customerId'] = FieldValue.delete();
        updates['defaultCustomerId'] = FieldValue.delete();
      } else {
        updates['customerId'] = value;
        updates['defaultCustomerId'] = value;
      }
    }

    if (customerName != null) {
      final value = customerName.trim();
      if (value.isEmpty) {
        updates['customerName'] = FieldValue.delete();
      } else {
        updates['customerName'] = value;
      }
    }

    if (defaultPlantKey != null) {
      final value = defaultPlantKey.trim();
      if (value.isEmpty) {
        updates['defaultPlantKey'] = FieldValue.delete();
      } else {
        updates['defaultPlantKey'] = value;
      }
    }

    if (bomId != null) {
      final value = bomId.trim();
      if (value.isEmpty) {
        updates['bomId'] = FieldValue.delete();
      } else {
        updates['bomId'] = value;
      }
    }

    if (bomVersion != null) {
      final value = bomVersion.trim();
      if (value.isEmpty) {
        updates['bomVersion'] = FieldValue.delete();
      } else {
        updates['bomVersion'] = value;
      }
    }

    if (routingId != null) {
      final value = routingId.trim();
      if (value.isEmpty) {
        updates['routingId'] = FieldValue.delete();
      } else {
        updates['routingId'] = value;
      }
    }

    if (routingVersion != null) {
      final value = routingVersion.trim();
      if (value.isEmpty) {
        updates['routingVersion'] = FieldValue.delete();
      } else {
        updates['routingVersion'] = value;
      }
    }

    if (packagingQty != null) {
      if (packagingQty <= 0) {
        updates['packagingQty'] = FieldValue.delete();
      } else {
        updates['packagingQty'] = packagingQty;
      }
    }

    if (secondaryClassificationCode != null) {
      final value = secondaryClassificationCode.trim();
      if (value.isEmpty) {
        updates['secondaryClassificationCode'] = FieldValue.delete();
      } else {
        updates['secondaryClassificationCode'] = value;
      }
    }

    if (secondaryClassificationDescription != null) {
      final value = secondaryClassificationDescription.trim();
      if (value.isEmpty) {
        updates['secondaryClassificationDescription'] = FieldValue.delete();
      } else {
        updates['secondaryClassificationDescription'] = value;
      }
    }

    if (standardUnitPrice != null) {
      if (standardUnitPrice <= 0) {
        updates['standardUnitPrice'] = FieldValue.delete();
      } else {
        updates['standardUnitPrice'] = standardUnitPrice;
      }
    }

    if (currency != null) {
      final value = currency.trim();
      if (value.isEmpty) {
        updates['currency'] = FieldValue.delete();
      } else {
        updates['currency'] = value;
      }
    }

    if (lotTrackingRequired != null) {
      updates['lotTrackingRequired'] = lotTrackingRequired;
    }
    if (shelfLifeDays != null) {
      if (shelfLifeDays <= 0) {
        updates['shelfLifeDays'] = FieldValue.delete();
      } else {
        updates['shelfLifeDays'] = shelfLifeDays;
      }
    }
    if (minStockQty != null) {
      if (minStockQty <= 0) {
        updates['minStockQty'] = FieldValue.delete();
      } else {
        updates['minStockQty'] = minStockQty;
      }
    }
    if (maxStockQty != null) {
      if (maxStockQty <= 0) {
        updates['maxStockQty'] = FieldValue.delete();
      } else {
        updates['maxStockQty'] = maxStockQty;
      }
    }

    if (idealCycleTimeSeconds != null) {
      if (idealCycleTimeSeconds <= 0) {
        updates['idealCycleTimeSeconds'] = FieldValue.delete();
      } else {
        updates['idealCycleTimeSeconds'] = idealCycleTimeSeconds;
      }
    }

    final currentUnit = _s(current['unit']);
    final currentDescription = _s(current['description']);
    final currentCustomerId = _s(current['customerId']);
    final currentCustomerName = _s(current['customerName']);
    final currentDefaultPlantKey = _s(current['defaultPlantKey']);
    final currentBomId = _s(current['bomId']);
    final currentBomVersion = _s(current['bomVersion']);
    final currentRoutingId = _s(current['routingId']);
    final currentRoutingVersion = _s(current['routingVersion']);
    final currentPackagingQty = current['packagingQty'];
    final currentSecCode = _s(current['secondaryClassificationCode']);
    final currentSecDesc = _s(current['secondaryClassificationDescription']);
    final currentStdPrice = _readDouble(current['standardUnitPrice']);
    final currentCurrency = _s(current['currency']);
    final currentStatus = _s(current['status']).toLowerCase();
    final currentIsActive = (current['isActive'] as bool?) ?? true;
    final currentLotTr = (current['lotTrackingRequired'] as bool?) ?? false;
    final currentShelf = current['shelfLifeDays'];
    int? currentShelfDays;
    if (currentShelf is int) {
      currentShelfDays = currentShelf;
    } else if (currentShelf is num) {
      currentShelfDays = currentShelf.toInt();
    }
    final currentMinStock = _readDouble(current['minStockQty']);
    final currentMaxStock = _readDouble(current['maxStockQty']);
    final currentIdealCycle = _readDouble(current['idealCycleTimeSeconds']);

    final nothingChanged =
        nextProductCode == currentProductCode &&
        nextProductName == _s(current['productName']) &&
        nextStatus == currentStatus &&
        (scanAliases == null ||
            _scanAliasListsEqual(
              currentAliases,
              _normalizeScanAliasesList(scanAliases),
            )) &&
        (isActive == null || isActive == currentIsActive) &&
        (unit == null || _s(unit) == currentUnit) &&
        (description == null || _s(description) == currentDescription) &&
        (customerId == null || _s(customerId) == currentCustomerId) &&
        (customerName == null || _s(customerName) == currentCustomerName) &&
        (defaultPlantKey == null ||
            _s(defaultPlantKey) == currentDefaultPlantKey) &&
        (bomId == null || _s(bomId) == currentBomId) &&
        (bomVersion == null || _s(bomVersion) == currentBomVersion) &&
        (routingId == null || _s(routingId) == currentRoutingId) &&
        (routingVersion == null ||
            _s(routingVersion) == currentRoutingVersion) &&
        (packagingQty == null ||
            _almostEqualDouble(
              _readDouble(currentPackagingQty),
              packagingQty,
            )) &&
        (secondaryClassificationCode == null ||
            _s(secondaryClassificationCode) == currentSecCode) &&
        (secondaryClassificationDescription == null ||
            _s(secondaryClassificationDescription) == currentSecDesc) &&
        (standardUnitPrice == null ||
            _almostEqualDouble(currentStdPrice, standardUnitPrice)) &&
        (currency == null || _s(currency) == currentCurrency) &&
        (lotTrackingRequired == null || lotTrackingRequired == currentLotTr) &&
        (shelfLifeDays == null ||
            (shelfLifeDays <= 0 && currentShelfDays == null) ||
            (shelfLifeDays > 0 && currentShelfDays == shelfLifeDays)) &&
        (minStockQty == null ||
            _almostEqualDouble(currentMinStock, minStockQty)) &&
        (maxStockQty == null ||
            _almostEqualDouble(currentMaxStock, maxStockQty)) &&
        (idealCycleTimeSeconds == null ||
            _almostEqualDouble(currentIdealCycle, idealCycleTimeSeconds));

    if (nothingChanged) {
      return;
    }

    await docRef.update(updates);
  }

  Future<void> setActiveBom({
    required String productId,
    required String companyId,
    required String updatedBy,
    required String bomId,
    required String bomVersion,
  }) async {
    final normalizedBomId = bomId.trim();
    final normalizedBomVersion = bomVersion.trim();

    if (normalizedBomId.isEmpty) {
      throw Exception('bomId je obavezan.');
    }

    if (normalizedBomVersion.isEmpty) {
      throw Exception('bomVersion je obavezan.');
    }

    await updateProduct(
      productId: productId,
      companyId: companyId,
      updatedBy: updatedBy,
      bomId: normalizedBomId,
      bomVersion: normalizedBomVersion,
    );
  }

  Future<void> setActiveRouting({
    required String productId,
    required String companyId,
    required String updatedBy,
    required String routingId,
    required String routingVersion,
  }) async {
    final normalizedRoutingId = routingId.trim();
    final normalizedRoutingVersion = routingVersion.trim();

    if (normalizedRoutingId.isEmpty) {
      throw Exception('routingId je obavezan.');
    }

    if (normalizedRoutingVersion.isEmpty) {
      throw Exception('routingVersion je obavezan.');
    }

    await updateProduct(
      productId: productId,
      companyId: companyId,
      updatedBy: updatedBy,
      routingId: normalizedRoutingId,
      routingVersion: normalizedRoutingVersion,
    );
  }

  Future<Map<String, dynamic>?> getProductById({
    required String productId,
    required String companyId,
  }) async {
    final normalizedProductId = productId.trim();
    final normalizedCompanyId = companyId.trim();

    if (normalizedProductId.isEmpty) {
      throw Exception('productId je obavezan.');
    }

    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }

    final doc = await _products.doc(normalizedProductId).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) {
      return null;
    }

    if (_s(data['companyId']) != normalizedCompanyId) {
      throw Exception('Nemaš pristup ovom proizvodu.');
    }

    return <String, dynamic>{'productId': doc.id, ...data};
  }

  Future<List<Map<String, dynamic>>> getProducts({
    required String companyId,
    bool onlyActive = false,
    int limit = 100,
  }) async {
    final normalizedCompanyId = companyId.trim();

    if (normalizedCompanyId.isEmpty) {
      throw Exception('companyId je obavezan.');
    }

    Query<Map<String, dynamic>> query = _products
        .where('companyId', isEqualTo: normalizedCompanyId)
        .limit(limit);

    if (onlyActive) {
      query = query.where('status', isEqualTo: 'active');
    }

    final snapshot = await query.get();

    final items = snapshot.docs
        .map((doc) => <String, dynamic>{'productId': doc.id, ...doc.data()})
        .toList();

    items.sort((a, b) {
      final aCode = _s(a['productCode']).toLowerCase();
      final bCode = _s(b['productCode']).toLowerCase();
      final codeCompare = aCode.compareTo(bCode);
      if (codeCompare != 0) return codeCompare;

      final aName = _s(a['productName']).toLowerCase();
      final bName = _s(b['productName']).toLowerCase();
      return aName.compareTo(bName);
    });

    return items;
  }

  Future<void> deactivateProduct({
    required String productId,
    required String companyId,
    required String updatedBy,
  }) async {
    await updateProduct(
      productId: productId,
      companyId: companyId,
      updatedBy: updatedBy,
      status: 'inactive',
      isActive: false,
    );
  }

  Future<void> activateProduct({
    required String productId,
    required String companyId,
    required String updatedBy,
  }) async {
    await updateProduct(
      productId: productId,
      companyId: companyId,
      updatedBy: updatedBy,
      status: 'active',
      isActive: true,
    );
  }
}
