import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'pma_models.dart';

abstract class ProductMachineApprovalGateway {
  Future<List<PmaApprovalView>> listForProduct({
    required String productId,
  });

  Future<PmaApprovalView> createDraft(PmaDraftRequest request);

  Future<PmaApprovalView> approveTechnology({
    required String omNumber,
    required int revision,
  });

  Future<List<PmaPlantOption>> listPlants(String companyId);

  Future<List<PmaMachineOption>> listMachines({
    required String companyId,
    required String plantKey,
  });
}

class FirebaseProductMachineApprovalGateway
    implements ProductMachineApprovalGateway {
  FirebaseProductMachineApprovalGateway({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  String _s(dynamic value) => (value ?? '').toString().trim();

  @override
  Future<List<PmaApprovalView>> listForProduct({
    required String productId,
  }) async {
    final result = await _functions
        .httpsCallable('listProductMachineApprovals')
        .call(<String, dynamic>{
          'productId': productId,
        });
    final data = result.data;
    final raw = data is Map ? data['approvals'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => PmaApprovalView.fromCallable(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<PmaApprovalView> createDraft(PmaDraftRequest request) async {
    final result = await _functions
        .httpsCallable('createProductMachineApprovalDraft')
        .call(<String, dynamic>{
          'plantKey': request.plantKey,
          'productScopeMode': 'selected_products',
          'productIds': [request.productId],
          'machineScopeMode': request.machineScopeMode,
          'machineIds': request.machineIds,
        });
    final data = result.data;
    final raw = data is Map ? data['approval'] : null;
    if (raw is! Map) {
      throw Exception('Odobrenje nije sačuvano.');
    }
    return PmaApprovalView.fromCallable(Map<String, dynamic>.from(raw));
  }

  @override
  Future<PmaApprovalView> approveTechnology({
    required String omNumber,
    required int revision,
  }) async {
    final result = await _functions
        .httpsCallable('approveProductMachineTechnology')
        .call(<String, dynamic>{
          'omNumber': omNumber,
          'revision': revision,
        });
    final data = result.data;
    final raw = data is Map ? data['approval'] : null;
    if (raw is! Map) {
      throw Exception('Odobrenje nije sačuvano.');
    }
    return PmaApprovalView.fromCallable(Map<String, dynamic>.from(raw));
  }

  @override
  Future<List<PmaPlantOption>> listPlants(String companyId) async {
    final snap = await _db
        .collection('company_plants')
        .where('companyId', isEqualTo: companyId)
        .where('active', isEqualTo: true)
        .get();
    final plants = snap.docs.map((doc) {
      final data = doc.data();
      final plantKey = _s(data['plantKey']).isNotEmpty
          ? _s(data['plantKey'])
          : doc.id;
      return PmaPlantOption(
        plantKey: plantKey,
        plantName: _plantName(data),
      );
    }).toList();
    plants.sort((a, b) => a.plantName.compareTo(b.plantName));
    return plants;
  }

  String _plantName(Map<String, dynamic> data) {
    final display = _s(data['displayName']);
    final fallback = _s(data['defaultName']).isNotEmpty
        ? _s(data['defaultName'])
        : _s(data['primaryName']);
    final name = display.isNotEmpty ? display : fallback;
    final code = _s(data['plantCode']);
    if (name.isNotEmpty && code.isNotEmpty) return '$name ($code)';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return 'Pogon';
  }

  @override
  Future<List<PmaMachineOption>> listMachines({
    required String companyId,
    required String plantKey,
  }) async {
    final snap = await _db
        .collection('assets')
        .where('companyId', isEqualTo: companyId)
        .where('plantKey', isEqualTo: plantKey)
        .where('active', isEqualTo: true)
        .get();
    final machines = <PmaMachineOption>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (_s(data['deviceType']).toLowerCase() == 'peripheral') continue;
      final code = _first([
        data['pantheonCode'],
        data['assetTag'],
        data['code'],
        data['assetCode'],
      ]);
      final name = _s(data['primaryName']).isNotEmpty
          ? _s(data['primaryName'])
          : _s(data['name']);
      machines.add(
        PmaMachineOption(
          machineId: doc.id,
          machineCode: code,
          machineName: name.isEmpty ? 'Mašina' : name,
        ),
      );
    }
    machines.sort((a, b) => a.label.compareTo(b.label));
    return machines;
  }

  String _first(List<dynamic> values) {
    for (final value in values) {
      final text = _s(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
