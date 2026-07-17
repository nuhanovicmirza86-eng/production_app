import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/access/production_maintenance_bridge.dart';
import '../../../../core/plant/production_plant_context_resolver.dart';
import '../../qr/screens/production_qr_scan_screen.dart';
import '../../qr/production_qr_resolver.dart';
import '../../tracking/screens/production_operator_tracking_screen.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import '../services/production_fault_photo_storage.dart';
import 'production_fault_asset_qr_scan_screen.dart';
import 'production_fault_detail_screen.dart';

class ProductionProblemReportingScreen extends StatefulWidget {
  const ProductionProblemReportingScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductionProblemReportingScreen> createState() =>
      _ProductionProblemReportingScreenState();
}

class _ProductionProblemReportingScreenState
    extends State<ProductionProblemReportingScreen> {
  static const List<String> _faultTypes = <String>[
    'Mehanički',
    'Električni',
    'Hidraulični',
    'Pneumatika',
    'Kvalitet / Proces',
    'Ostalo',
  ];

  static const String _statusOpen = 'open';
  static const String _statusInProgress = 'in_progress';
  static const String _statusClosed = 'closed';
  static const String _statusCancelled = 'cancelled';

  static const List<String> _activeStatuses = <String>[
    _statusOpen,
    _statusInProgress,
  ];

  static const List<String> _archivedStatuses = <String>[
    _statusClosed,
    _statusCancelled,
  ];

  final TextEditingController _descriptionCtrl = TextEditingController();

  String _statusFilter = 'active';
  bool _submitting = false;
  bool _faultPhotoLoading = false;
  String? _selectedAssetId;
  String? _selectedFaultType;
  bool _isRunningReported = false;

  /// Kad je uređaj odabran skeniranjem QR-a a nije u trenutnoj stream listi.
  Map<String, dynamic>? _assetPayloadOverride;
  XFile? _faultPhoto;
  Uint8List? _faultPhotoPreview;

  static final ImagePicker _imagePicker = ImagePicker();

  /// QR skeniranje + kamera za sliku — samo Android/iOS (kao Maintenance prijava kvara).
  /// Web i desktop (Windows, macOS, Linux): bez QR-a; samo upload slike (galerija / datoteka).
  bool get _isAndroidOrIos {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Canonical key za faults / prikaz (Maintenance `report_fault` semantika).
  String? _resolvedAssetPlantKey;
  bool _resolvingPlant = true;

  List<String> _mergedPlantKeys = const [];
  List<String> _mergedPlantIds = const [];
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _assetsListStream;

  /// Isti kanonski id kao u Firestore pravilima (`users.companyId` string ili DocumentReference.id).
  String _faultsQueryCompanyId = '';

  @override
  void initState() {
    super.initState();
    _faultsQueryCompanyId = _s(widget.companyData['companyId']);
    unawaited(_loadFaultsQueryCompanyId());
    _loadResolvedPlantKeyForAssets();
  }

  String _companyIdFromUserField(dynamic raw) {
    if (raw is DocumentReference) return raw.id.trim();
    return _s(raw);
  }

  /// Osigurava da `faults` upit koristi isti tenant string kao pravila (ne zastarjeli session map).
  Future<void> _loadFaultsQueryCompanyId() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      if (!snap.exists || !mounted) return;
      final d = snap.data() ?? <String, dynamic>{};
      final merged = Map<String, dynamic>.from(d);
      final acc = d['appAccess'];
      if (acc is Map<String, dynamic>) {
        acc.forEach((k, v) {
          if (!merged.containsKey(k) || merged[k] == null) merged[k] = v;
        });
      }
      final cid = _companyIdFromUserField(merged['companyId']);
      if (cid.isNotEmpty && cid != _faultsQueryCompanyId) {
        setState(() => _faultsQueryCompanyId = cid);
      }
    } catch (_) {
      // ostaje widget.companyData
    }
  }

  Future<void> _loadResolvedPlantKeyForAssets() async {
    final cid = _companyId;
    if (cid.isEmpty ||
        !maintenanceFaultBridgeEnabled(widget.companyData)) {
      if (mounted) {
        setState(() {
          _resolvingPlant = false;
          _assetsListStream = null;
          _mergedPlantKeys = const [];
          _mergedPlantIds = const [];
        });
      }
      return;
    }

    String coalesce(String a, String b) => a.isNotEmpty ? a : b;

    var userLike = <String, dynamic>{
      'homePlantKey': _s(widget.companyData['userHomePlantKey']),
      'plantKey': _s(widget.companyData['plantKey']),
      'homePlantId': _s(widget.companyData['userHomePlantId']),
      'plantId': _s(widget.companyData['userLegacyPlantId']),
    };

    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      try {
        final snap =
            await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
        final d = snap.data() ?? <String, dynamic>{};
        userLike = <String, dynamic>{
          'homePlantKey': coalesce(_s(d['homePlantKey']), _s(userLike['homePlantKey'])),
          'plantKey': coalesce(_s(d['plantKey']), _s(userLike['plantKey'])),
          'homePlantId': coalesce(_s(d['homePlantId']), _s(userLike['homePlantId'])),
          'plantId': coalesce(_s(d['plantId']), _s(userLike['plantId'])),
        };
      } catch (_) {
        // keep session-based userLike
      }
    }

    try {
      final k = await ProductionPlantContextResolver.resolvePlantKeyOrFallback(
        companyId: cid,
        userData: userLike,
      );
      if (!mounted) return;
      final resolvedK = k.trim();
      final plantKeys = _distinctNonEmptyUpTo10([
        resolvedK,
        _s(userLike['plantKey']),
        _s(userLike['homePlantKey']),
      ]);
      final plantIds = _distinctNonEmptyUpTo10([
        _s(userLike['plantId']),
        _s(userLike['homePlantId']),
        _s(userLike['plantKey']),
        resolvedK,
      ]);
      setState(() {
        _resolvedAssetPlantKey = resolvedK.isNotEmpty ? resolvedK : null;
        _mergedPlantKeys = plantKeys;
        _mergedPlantIds = plantIds;
        _resolvingPlant = false;
        _assetsListStream = _mergedAssetsStreamFromStoredCandidates();
      });
    } catch (_) {
      if (!mounted) return;
      final plantKeys = _distinctNonEmptyUpTo10([
        _plantKey,
        _s(widget.companyData['userHomePlantKey']),
      ]);
      final plantIds = _distinctNonEmptyUpTo10([
        _s(widget.companyData['userLegacyPlantId']),
        _s(widget.companyData['userHomePlantId']),
        _plantKey,
      ]);
      setState(() {
        _resolvedAssetPlantKey = _plantKey;
        _mergedPlantKeys = plantKeys;
        _mergedPlantIds = plantIds;
        _resolvingPlant = false;
        _assetsListStream = _mergedAssetsStreamFromStoredCandidates();
      });
    }
  }

  /// Same key Maintenance koristi za listu uređaja na prijavi kvara.
  String get _queryPlantKey {
    final r = _s(_resolvedAssetPlantKey);
    return r.isNotEmpty ? r : _plantKey;
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String get _companyId => _s(widget.companyData['companyId']);
  String get _companyIdForFaultsQuery =>
      _faultsQueryCompanyId.isNotEmpty ? _faultsQueryCompanyId : _companyId;
  String get _plantKey => _s(widget.companyData['plantKey']);

  /// Usklađeno s Firestore pravilima (`request.auth.uid` + `createdByUid` na dokumentu).
  /// `companyData['userId']` može biti zastario ili pogrešan — ne koristiti za faults upite.
  String get _uid {
    final authUid = _s(FirebaseAuth.instance.currentUser?.uid);
    if (authUid.isNotEmpty) return authUid;
    return _s(widget.companyData['userId']);
  }

  bool get _canSubmit {
    return !_submitting &&
        !_faultPhotoLoading &&
        _companyId.isNotEmpty &&
        _plantKey.isNotEmpty &&
        _uid.isNotEmpty;
  }

  List<String> _distinctNonEmptyUpTo10(Iterable<String> raw) {
    final out = <String>[];
    for (final e in raw) {
      final v = e.trim();
      if (v.isEmpty || out.contains(v)) continue;
      out.add(v);
      if (out.length >= 10) break;
    }
    return out;
  }

  /// Uređaji mogu biti vezani na `plantKey` **ili** (legacy) na `plantId`
  /// kao u Maintenance `AssetsService.streamAssets`.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _mergedAssetsStreamFromStoredCandidates() {
    final cid = _companyId;
    if (cid.isEmpty) {
      return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
        const [],
      );
    }

    final plantKeys = _mergedPlantKeys;
    final plantIds = _mergedPlantIds;

    if (plantKeys.isEmpty) {
      return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
        const [],
      );
    }

    return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.multi(
      (controller) {
        final byPlantKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        final byPlantId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

        void emit() {
          final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
            ...byPlantKey,
            ...byPlantId,
          };
          final list = merged.values.toList()
            ..sort(
              (a, b) => _assetLabel(a.data())
                  .toLowerCase()
                  .compareTo(_assetLabel(b.data()).toLowerCase()),
            );
          if (!controller.isClosed) {
            controller.add(list);
          }
        }

        late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subK;
        StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subI;

        Query<Map<String, dynamic>> qk = FirebaseFirestore.instance
            .collection('assets')
            .where('companyId', isEqualTo: cid);
        if (plantKeys.length == 1) {
          qk = qk.where('plantKey', isEqualTo: plantKeys.first);
        } else {
          qk = qk.where('plantKey', whereIn: plantKeys);
        }

        subK = qk.snapshots().listen(
          (snap) {
            byPlantKey
              ..clear()
              ..addEntries(snap.docs.map((d) => MapEntry(d.id, d)));
            emit();
          },
          onError: controller.addError,
        );

        if (plantIds.isNotEmpty) {
          Query<Map<String, dynamic>> qi = FirebaseFirestore.instance
              .collection('assets')
              .where('companyId', isEqualTo: cid);
          if (plantIds.length == 1) {
            qi = qi.where('plantId', isEqualTo: plantIds.first);
          } else {
            qi = qi.where('plantId', whereIn: plantIds);
          }
          subI = qi.snapshots().listen(
            (snap) {
              byPlantId
                ..clear()
                ..addEntries(snap.docs.map((d) => MapEntry(d.id, d)));
              emit();
            },
            onError: controller.addError,
          );
        }

        controller.onCancel = () {
          subK.cancel();
          subI?.cancel();
        };
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myFaultsStream() {
    final cid = _companyIdForFaultsQuery;
    if (cid.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('faults')
        .where('companyId', isEqualTo: cid)
        .where('createdByUid', isEqualTo: _uid)
        .snapshots();
  }

  Map<String, dynamic> _resolveAssetData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sid = _s(_selectedAssetId);
    if (sid.isEmpty) return <String, dynamic>{};
    for (final d in docs) {
      if (d.id == sid) return d.data();
    }
    return Map<String, dynamic>.from(_assetPayloadOverride ?? const {});
  }

  List<DropdownMenuItem<String>> _assetDropdownItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = docs
        .map(
          (doc) => DropdownMenuItem<String>(
            value: doc.id,
            child: Text(
              _assetLabel(doc.data()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(growable: true);
    final sid = _s(_selectedAssetId);
    if (sid.isNotEmpty &&
        _assetPayloadOverride != null &&
        !docs.any((d) => d.id == sid)) {
      items.add(
        DropdownMenuItem<String>(
          value: sid,
          child: Text(
            _assetLabel(_assetPayloadOverride!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }

  Future<void> _openDeviceQrAndAssign() async {
    if (!_isAndroidOrIos) return;
    if (_mergedPlantKeys.isEmpty && _mergedPlantIds.isEmpty) {
      _showSnack('Još učitavam pogon — pokušaj za trenut.');
      return;
    }
    final r = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => ProductionFaultAssetQrScanScreen(
          companyId: _companyId,
          allowedPlantKeys: _mergedPlantKeys,
          allowedPlantIds: _mergedPlantIds,
        ),
      ),
    );
    if (!mounted || r == null) return;
    final id = _s(r['__assetDocId']);
    if (id.isEmpty) return;
    final copy = Map<String, dynamic>.from(r)..remove('__assetDocId');
    setState(() {
      _selectedAssetId = id;
      _assetPayloadOverride = copy;
    });
    _showSnack('Uređaj postavljen iz QR koda.');
  }

  Future<void> _openProductQrAppendDescription() async {
    if (!_isAndroidOrIos) return;
    final res = await Navigator.push<ProductionQrScanResolution>(
      context,
      MaterialPageRoute<ProductionQrScanResolution>(
        builder: (_) => ProductionQrScanScreen(companyData: widget.companyData),
      ),
    );
    if (!mounted || res == null) return;
    if (!res.isKnown) {
      _showSnack('QR nije prepoznat kao proizvodni format.');
      return;
    }
    var line = '';
    if (res.intent == ProductionQrIntent.printedClassificationLabelV1) {
      final f = res.labelFields ?? <String, dynamic>{};
      final pn = _s(res.productionOrderCode).isNotEmpty
          ? _s(res.productionOrderCode)
          : _s(f['pn']);
      final sku = _s(f['sku']);
      line =
          '[QR proizvod] PN: $pn${sku.isNotEmpty ? '; SKU: $sku' : ''}';
    } else if (res.intent == ProductionQrIntent.productionOrderReferenceV1) {
      line =
          '[QR nalog] ${_s(res.productionOrderCode)} (id: ${_s(res.productionOrderId)})';
    }
    if (line.isEmpty) return;
    final cur = _descriptionCtrl.text.trim();
    _descriptionCtrl.text = cur.isEmpty ? line : '$line\n$cur';
    setState(() {});
    _showSnack('Tekst iz QR-a dodan u opis.');
  }

  Future<void> _pickFaultPhoto(ImageSource source) async {
    setState(() => _faultPhotoLoading = true);
    try {
      final x = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1920,
      );
      if (!mounted || x == null) return;
      final bytes = await ProductionFaultPhotoStorage.readBytesWithRetry(x);
      if (!mounted) return;
      setState(() {
        _faultPhoto = x;
        _faultPhotoPreview = bytes;
      });
    } catch (e) {
      if (mounted) _showSnack('Slika: $e');
    } finally {
      if (mounted) setState(() => _faultPhotoLoading = false);
    }
  }

  void _clearFaultPhoto() {
    setState(() {
      _faultPhoto = null;
      _faultPhotoPreview = null;
    });
  }

  String _assetLabel(Map<String, dynamic> d) =>
      ProductionAssetDisplayLookup.labelFromAssetData(d);

  /// Naslov u listi kvarova — bez Firestore ID-a uređaja.
  String _faultDeviceTitle(Map<String, dynamic> d) {
    final primary = _s(d['assetPrimaryName']);
    final secondary = _s(d['assetSecondaryName']);
    final dn = _s(d['deviceName']);
    if (primary.isNotEmpty && secondary.isNotEmpty) {
      return '$primary — $secondary';
    }
    if (primary.isNotEmpty) return primary;
    if (secondary.isNotEmpty) return secondary;
    if (dn.isNotEmpty) return dn;
    return 'Uređaj (naziv nije u šifrarniku)';
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case _statusOpen:
        return Colors.red;
      case _statusInProgress:
        return Colors.orange;
      case _statusClosed:
        return Colors.green;
      case _statusCancelled:
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case _statusOpen:
        return 'OTVOREN';
      case _statusInProgress:
        return 'U TOKU';
      case _statusClosed:
        return 'ZATVOREN';
      case _statusCancelled:
        return 'OTKAZAN';
      default:
        return status.trim().isEmpty ? '-' : status.toUpperCase();
    }
  }

  bool _statusAllowedByFilter(String statusCode) {
    final s = statusCode.trim().toLowerCase();
    switch (_statusFilter) {
      case 'active':
        return _activeStatuses.contains(s);
      case 'archived':
        return _archivedStatuses.contains(s);
      case 'all':
      default:
        return true;
    }
  }

  Future<void> _submitFault(Map<String, dynamic> assetData) async {
    final assetId = (_selectedAssetId ?? '').trim();
    final faultType = (_selectedFaultType ?? '').trim();
    final description = _descriptionCtrl.text.trim();

    if (assetId.isEmpty) {
      _showSnack('Odaberi uređaj.');
      return;
    }
    if (faultType.isEmpty) {
      _showSnack('Odaberi tip kvara.');
      return;
    }
    if (description.isEmpty) {
      _showSnack('Upiši opis kvara.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final locationPath = _s(assetData['locationPath']).isNotEmpty
          ? _s(assetData['locationPath'])
          : _queryPlantKey;
      final deviceName = _assetLabel(assetData);

      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('createFaultReport');
      final result = await callable.call(<String, dynamic>{
        'locationPath': locationPath,
        'assetId': assetId,
        'deviceId': assetId,
        'deviceName': deviceName,
        'faultType': faultType,
        'description': description,
        'isRunningReported': _isRunningReported,
      });

      final data = result.data;
      String faultId = '';
      if (data is Map) {
        final id = data['faultId'];
        if (id is String && id.trim().isNotEmpty) {
          faultId = id.trim();
        }
      }
      if (faultId.isEmpty) {
        throw Exception('Neočekivani odgovor servera (createFaultReport).');
      }

      final hadPhoto = _faultPhoto != null;
      var photoLinked = !hadPhoto;
      if (hadPhoto) {
        try {
          await ProductionFaultPhotoStorage.uploadFaultPhoto(
            faultId: faultId,
            photo: _faultPhoto!,
            preloadedBytes: _faultPhotoPreview,
          );
          photoLinked = true;
        } catch (e) {
          if (mounted) {
            _showSnack(
              'Kvar je kreiran, ali upload ili povezivanje slike (Firestore) nije uspjelo: $e',
            );
          }
        }
      }

      _descriptionCtrl.clear();
      _selectedFaultType = null;
      _isRunningReported = false;
      _assetPayloadOverride = null;
      _faultPhoto = null;
      _faultPhotoPreview = null;
      if (mounted) {
        setState(() {});
      }
      if (photoLinked) {
        _showSnack(
          hadPhoto
              ? 'Kvar je uspješno prijavljen (sa slikom).'
              : 'Kvar je uspješno prijavljen.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      final msg = (e.message != null && e.message!.trim().isNotEmpty)
          ? e.message!.trim()
          : e.code;
      _showSnack('Greška pri prijavi kvara: $msg');
    } catch (e) {
      _showSnack('Greška pri prijavi kvara: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!maintenanceFaultBridgeEnabled(widget.companyData)) {
      return const Scaffold(
        body: _MissingMaintenanceModuleMessage(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Prijava problema')),
      body: (_companyId.isEmpty || _plantKey.isEmpty || _uid.isEmpty)
          ? const _MissingContextMessage()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle(context, 'Maintenance kvarovi'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prijava kvara ide u Maintenance domenu, a ostaje dostupna iz Production aplikacije.',
                        ),
                        const SizedBox(height: 12),
                        if (_resolvingPlant)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          )
                        else if (_assetsListStream == null)
                          const Text(
                            'Nije moguće učitati listu uređaja (sesija). Osvježi stranicu.',
                          )
                        else
                          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                          stream: _assetsListStream,
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Text(
                                'Greška pri učitavanju uređaja: ${snap.error}',
                                style: const TextStyle(color: Colors.red),
                              );
                            }

                            if (!snap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(),
                              );
                            }

                            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                              snap.data!,
                            );

                            if (docs.isEmpty) {
                              return Text(
                                'Nema uređaja za tvoj pogon. '
                                'Tražimo plantKey u [${_mergedPlantKeys.join(", ")}] '
                                'i plantId u [${_mergedPlantIds.join(", ")}]. '
                                'U Firestore `assets` moraju imati isti companyId i jedan od tih ključeva. '
                                'Ako i dalje vidiš staru poruku, deployaj novu web verziju Production app-a.',
                              );
                            }

                            if (_selectedAssetId == null ||
                                (!docs.any((d) => d.id == _selectedAssetId) &&
                                    _assetPayloadOverride == null)) {
                              _selectedAssetId = docs.first.id;
                            }

                            final assetData = _resolveAssetData(docs);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isAndroidOrIos) ...[
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _submitting
                                            ? null
                                            : _openDeviceQrAndAssign,
                                        icon: const Icon(Icons.qr_code_scanner),
                                        label: const Text('QR uređaja'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _submitting
                                            ? null
                                            : _openProductQrAppendDescription,
                                        icon: const Icon(Icons.inventory_2_outlined),
                                        label: const Text('QR proizvoda / naloga'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                DropdownButtonFormField<String>(
                                  key: ValueKey<String>(
                                    'asset_${_selectedAssetId ?? 'none'}',
                                  ),
                                  isExpanded: true,
                                  initialValue: _selectedAssetId,
                                  items: _assetDropdownItems(docs),
                                  onChanged: _submitting
                                      ? null
                                      : (v) {
                                          if (v == null) return;
                                          setState(() {
                                            _selectedAssetId = v;
                                            _assetPayloadOverride = null;
                                          });
                                        },
                                  decoration: const InputDecoration(
                                    labelText: 'Uređaj',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  key: ValueKey<String>(
                                    'ftype_${_selectedFaultType ?? 'none'}',
                                  ),
                                  isExpanded: true,
                                  initialValue: _selectedFaultType,
                                  items: _faultTypes
                                      .map(
                                        (t) => DropdownMenuItem<String>(
                                          value: t,
                                          child: Text(t),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: _submitting
                                      ? null
                                      : (v) => setState(
                                          () => _selectedFaultType = v,
                                        ),
                                  decoration: const InputDecoration(
                                    labelText: 'Tip kvara',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _descriptionCtrl,
                                  minLines: 3,
                                  maxLines: 6,
                                  enabled: !_submitting,
                                  decoration: const InputDecoration(
                                    labelText: 'Opis kvara',
                                    hintText:
                                        'Šta se desilo, kada i koji su simptomi...',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _isAndroidOrIos
                                      ? 'Slika (opcionalno) — kamera ili galerija'
                                      : 'Upload slike (opcionalno)',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (_isAndroidOrIos)
                                      OutlinedButton.icon(
                                        onPressed: (_submitting ||
                                                _faultPhotoLoading)
                                            ? null
                                            : () => _pickFaultPhoto(
                                                  ImageSource.camera,
                                                ),
                                        icon: const Icon(Icons.photo_camera_outlined),
                                        label: const Text('Snimi'),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: (_submitting ||
                                              _faultPhotoLoading)
                                          ? null
                                          : () => _pickFaultPhoto(
                                                ImageSource.gallery,
                                              ),
                                      icon: const Icon(Icons.photo_library_outlined),
                                      label: Text(
                                        _isAndroidOrIos ? 'Galerija' : 'Odaberi sliku',
                                      ),
                                    ),
                                    if (_faultPhoto != null)
                                      TextButton.icon(
                                        onPressed: (_submitting ||
                                                _faultPhotoLoading)
                                            ? null
                                            : _clearFaultPhoto,
                                        icon: const Icon(Icons.clear),
                                        label: const Text('Ukloni sliku'),
                                      ),
                                  ],
                                ),
                                if (_faultPhotoPreview != null) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      _faultPhotoPreview!,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _isRunningReported,
                                  onChanged: (_submitting || _faultPhotoLoading)
                                      ? null
                                      : (v) =>
                                          setState(() => _isRunningReported = v),
                                  title: const Text('Uređaj radi'),
                                  subtitle: const Text(
                                    'Ako je isključeno, prijava ide kao "Ne radi".',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _canSubmit
                                        ? () => _submitFault(assetData)
                                        : null,
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send_outlined),
                                    label: Text(
                                      _faultPhotoLoading
                                          ? 'Priprema slike...'
                                          : _submitting
                                              ? 'Slanje...'
                                              : 'Pošalji prijavu kvara',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Moje prijave kvarova'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Aktivni'),
                      selected: _statusFilter == 'active',
                      onSelected: (_) => setState(() => _statusFilter = 'active'),
                    ),
                    ChoiceChip(
                      label: const Text('Arhiva'),
                      selected: _statusFilter == 'archived',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'archived'),
                    ),
                    ChoiceChip(
                      label: const Text('Svi'),
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _myFaultsStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text(
                        'Greška pri učitavanju prijava: ${snap.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snap.data!.docs
                        .where((d) => _statusAllowedByFilter(_s(d['status'])))
                        .toList(growable: false)
                      ..sort((a, b) {
                        final da = a.data()['createdAt'];
                        final db = b.data()['createdAt'];
                        final aDate = da is Timestamp ? da.toDate() : DateTime(0);
                        final bDate = db is Timestamp ? db.toDate() : DateTime(0);
                        return bDate.compareTo(aDate);
                      });

                    if (docs.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Nema prijava za odabrani filter.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data();
                        final status = _s(d['status']);
                        final created = d['createdAt'];
                        final createdAt = created is Timestamp
                            ? created.toDate()
                            : null;
                        final title = _faultDeviceTitle(d);
                        return Card(
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => ProductionFaultDetailScreen(
                                    companyData: widget.companyData,
                                    faultId: doc.id,
                                  ),
                                ),
                              );
                            },
                            title: Text(
                              title.isEmpty ? 'Uređaj -' : title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(_s(d['description'])),
                                const SizedBox(height: 6),
                                Text(
                                  'Tip: ${_s(d['faultType'])} • ${createdAt?.toLocal().toString().substring(0, 16) ?? '-'}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                            trailing: _StatusBadge(
                              label: _statusLabel(status),
                              color: _statusColor(status),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Production škart / neusklađenost'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Za škart i proizvodne neusklađenosti koristi postojeći tok praćenja proizvodnje (unos dobrog i škarta po šifri defekta).',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ili otvori praćenje odmah dugmetom ispod.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ProductionOperatorTrackingScreen(
                                  companyData: widget.companyData,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Otvori praćenje proizvodnje'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _MissingContextMessage extends StatelessWidget {
  const _MissingContextMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nedostaju sesijski podaci (companyId/plantKey/userId). Ponovo se prijavi ili kontaktiraj admina.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _MissingMaintenanceModuleMessage extends StatelessWidget {
  const _MissingMaintenanceModuleMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Prijava kvara ovdje nije dostupna: kompanija mora imati Maintenance modul, a Admin mora vam u profilu uključiti pristup (appAccess.maintenance).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
