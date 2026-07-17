import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/access/production_access_helper.dart';
import '../../../../core/access/production_maintenance_bridge.dart';
import '../../../../core/plant/production_plant_context_resolver.dart';
import '../../tracking/services/production_asset_display_lookup.dart';
import '../services/production_fault_photo_storage.dart';
import 'production_fault_asset_qr_scan_screen.dart';

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

  final TextEditingController _descriptionCtrl = TextEditingController();

  bool _submitting = false;
  bool _faultPhotoLoading = false;
  String? _selectedAssetId;
  String? _selectedFaultType;
  bool _isRunningReported = false;

  Map<String, dynamic>? _assetPayloadOverride;
  XFile? _faultPhoto;
  Uint8List? _faultPhotoPreview;

  static final ImagePicker _imagePicker = ImagePicker();

  bool get _isAndroidOrIos {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _queryPlantKey = '';
  bool _resolvingPlant = true;

  List<String> _mergedPlantKeys = const [];
  List<String> _mergedPlantIds = const [];
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _assetsListStream;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlantScopeForAssets());
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String get _companyId => _s(widget.companyData['companyId']);

  String get _sessionPlantKey => _s(widget.companyData['plantKey']);

  String get _role =>
      ProductionAccessHelper.normalizeRole(widget.companyData['role']);

  /// Admin / super_admin: session pogon (kao Zastoji, Procesi, Radni centri).
  bool get _usesSessionPlant =>
      ProductionAccessHelper.isAdminRole(_role) ||
      ProductionAccessHelper.isSuperAdminRole(_role);

  String get _uid {
    final authUid = _s(FirebaseAuth.instance.currentUser?.uid);
    if (authUid.isNotEmpty) return authUid;
    return _s(widget.companyData['userId']);
  }

  bool get _canSubmit {
    return !_submitting &&
        !_faultPhotoLoading &&
        _companyId.isNotEmpty &&
        _queryPlantKey.isNotEmpty &&
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

  Future<Map<String, dynamic>> _loadUserLikeForPlant() async {
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
          'homePlantKey': coalesce(
            _s(d['homePlantKey']),
            _s(userLike['homePlantKey']),
          ),
          'plantKey': coalesce(_s(d['plantKey']), _s(userLike['plantKey'])),
          'homePlantId': coalesce(
            _s(d['homePlantId']),
            _s(userLike['homePlantId']),
          ),
          'plantId': coalesce(_s(d['plantId']), _s(userLike['plantId'])),
        };
      } catch (_) {
        // ostaje session-based userLike
      }
    }
    return userLike;
  }

  Future<List<String>> _legacyPlantIdsForKeys(
    String companyId,
    List<String> plantKeys,
  ) async {
    final ids = <String>[];
    for (final pk in plantKeys) {
      if (pk.isEmpty) continue;
      try {
        final byId = await FirebaseFirestore.instance
            .collection('company_plants')
            .doc('${companyId}_$pk')
            .get();
        if (byId.exists) {
          final lid = _s(byId.data()?['legacyPlantId']);
          if (lid.isNotEmpty && !ids.contains(lid)) ids.add(lid);
          continue;
        }
        final q = await FirebaseFirestore.instance
            .collection('company_plants')
            .where('companyId', isEqualTo: companyId)
            .where('plantKey', isEqualTo: pk)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final lid = _s(q.docs.first.data()['legacyPlantId']);
          if (lid.isNotEmpty && !ids.contains(lid)) ids.add(lid);
        }
      } catch (_) {
        // preskoči pojedinačni pogon
      }
    }
    return ids;
  }

  Future<void> _loadPlantScopeForAssets() async {
    final cid = _companyId;
    if (cid.isEmpty || !maintenanceFaultBridgeEnabled(widget.companyData)) {
      if (mounted) {
        setState(() {
          _resolvingPlant = false;
          _assetsListStream = null;
          _queryPlantKey = '';
        });
      }
      return;
    }

    String primaryKey;
    List<String> plantKeys;
    List<String> plantIds;

    if (_usesSessionPlant) {
      primaryKey = _sessionPlantKey;
      plantKeys = _distinctNonEmptyUpTo10([primaryKey]);
      plantIds = await _legacyPlantIdsForKeys(cid, plantKeys);
    } else {
      final userLike = await _loadUserLikeForPlant();
      primaryKey = await ProductionPlantContextResolver.resolvePlantKeyOrFallback(
        companyId: cid,
        userData: userLike,
      );
      plantKeys = _distinctNonEmptyUpTo10([
        primaryKey,
        _s(userLike['plantKey']),
        _s(userLike['homePlantKey']),
      ]);
      plantIds = _distinctNonEmptyUpTo10([
        _s(userLike['plantId']),
        _s(userLike['homePlantId']),
        ...(await _legacyPlantIdsForKeys(cid, plantKeys)),
      ]);
    }

    if (!mounted) return;
    setState(() {
      _queryPlantKey = primaryKey;
      _mergedPlantKeys = plantKeys;
      _mergedPlantIds = plantIds;
      _resolvingPlant = false;
      _assetsListStream = plantKeys.isEmpty
          ? Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
              const [],
            )
          : _mergedAssetsStreamFromStoredCandidates();
    });
  }

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
      if (mounted) _showSnack('Slika nije učitana. Pokušaj ponovo.');
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
        throw Exception('Neočekivani odgovor servera.');
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
        } catch (_) {
          if (mounted) {
            _showSnack(
              'Kvar je prijavljen, ali slika nije spremljena. Pokušaj ponovo s detalja prijave.',
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
          : 'Prijava nije uspjela. Pokušaj ponovo.';
      _showSnack(msg);
    } catch (_) {
      _showSnack('Prijava nije uspjela. Pokušaj ponovo.');
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

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prijava problema'),
        content: const Text(
          'Ovdje možeš prijaviti kvar na uređaju iz odabranog proizvodnog pogona. '
          'Prijava se evidentira u Maintenance modulu.\n\n'
          'Za prijavu kvara mora postojati evidentiran uređaj u odabranom pogonu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!maintenanceFaultBridgeEnabled(widget.companyData)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prijava problema')),
        body: const _MissingMaintenanceModuleMessage(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prijava problema'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Informacije',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: (_companyId.isEmpty ||
              _uid.isEmpty ||
              (!_resolvingPlant && _queryPlantKey.isEmpty))
          ? const _MissingContextMessage()
          : _resolvingPlant
          ? const Center(child: CircularProgressIndicator())
          : _assetsListStream == null
          ? const Center(child: _MissingContextMessage())
          : StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: _assetsListStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Učitavanje uređaja nije uspjelo. Pokušaj osvježiti stranicu.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snap.data!,
                );

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nema evidentiranih uređaja za odabrani pogon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }

                if (_selectedAssetId == null ||
                    (!docs.any((d) => d.id == _selectedAssetId) &&
                        _assetPayloadOverride == null)) {
                  _selectedAssetId = docs.first.id;
                }

                final assetData = _resolveAssetData(docs);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isAndroidOrIos) ...[
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _openDeviceQrAndAssign,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Skeniraj QR uređaja'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('asset_${_selectedAssetId ?? 'none'}'),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>('ftype_${_selectedFaultType ?? 'none'}'),
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
                          : (v) => setState(() => _selectedFaultType = v),
                      decoration: const InputDecoration(
                        labelText: 'Tip kvara',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionCtrl,
                      minLines: 3,
                      maxLines: 6,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        hintText: 'Šta se desilo, kada i koji su simptomi...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isRunningReported,
                      onChanged: (_submitting || _faultPhotoLoading)
                          ? null
                          : (v) => setState(() => _isRunningReported = v),
                      title: const Text('Uređaj radi'),
                      subtitle: const Text(
                        'Ako je isključeno, prijava ide kao „Ne radi”.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isAndroidOrIos
                          ? 'Slika (opcionalno)'
                          : 'Priloži sliku (opcionalno)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_isAndroidOrIos)
                          OutlinedButton.icon(
                            onPressed: (_submitting || _faultPhotoLoading)
                                ? null
                                : () => _pickFaultPhoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Snimi'),
                          ),
                        OutlinedButton.icon(
                          onPressed: (_submitting || _faultPhotoLoading)
                              ? null
                              : () => _pickFaultPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _isAndroidOrIos ? 'Galerija' : 'Odaberi sliku',
                          ),
                        ),
                        if (_faultPhoto != null)
                          TextButton.icon(
                            onPressed: (_submitting || _faultPhotoLoading)
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _canSubmit ? () => _submitFault(assetData) : null,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _faultPhotoLoading
                              ? 'Priprema slike...'
                              : _submitting
                              ? 'Slanje...'
                              : 'Pošalji',
                        ),
                      ),
                    ),
                  ],
                );
              },
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
          'Nedostaje kontekst sesije. Odjavi se i prijavi ponovo, ili odaberi pogon rada.',
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
          'Prijava kvara nije dostupna za ovu kompaniju ili korisnički profil. '
          'Obrati se administratoru.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
