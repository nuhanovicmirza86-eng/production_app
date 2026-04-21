import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/errors/app_error_mapper.dart';

/// Sken QR mašine (`assetId:<id>` ili čisti id) — isti format kao Maintenance operator.
/// Vraća mapu podataka asseta + ključ `__assetDocId` = Firestore id dokumenta.
class ProductionFaultAssetQrScanScreen extends StatefulWidget {
  const ProductionFaultAssetQrScanScreen({
    super.key,
    required this.companyId,
    required this.allowedPlantKeys,
    required this.allowedPlantIds,
  });

  final String companyId;
  final List<String> allowedPlantKeys;
  final List<String> allowedPlantIds;

  @override
  State<ProductionFaultAssetQrScanScreen> createState() =>
      _ProductionFaultAssetQrScanScreenState();
}

class _ProductionFaultAssetQrScanScreenState
    extends State<ProductionFaultAssetQrScanScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();

  bool _locked = false;
  String? _err;

  bool get _useDeviceCamera {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (_useDeviceCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cameraController.start();
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _userFacingError(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return AppErrorMapper.toMessage(e);
  }

  String? _parseAssetId(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    if (lower.startsWith('assetid:')) {
      final id = t.substring('assetid:'.length).trim();
      return id.isEmpty ? null : id;
    }
    if (t.contains(':') || t.contains(';')) return null;
    return t;
  }

  bool _plantAllowed(Map<String, dynamic> data) {
    final pk = _s(data['plantKey']);
    final pid = _s(data['plantId']);
    final keys = widget.allowedPlantKeys.map(_s).where((e) => e.isNotEmpty).toSet();
    final ids = widget.allowedPlantIds.map(_s).where((e) => e.isNotEmpty).toSet();
    if (keys.isEmpty && ids.isEmpty) return false;
    if (pk.isNotEmpty && keys.contains(pk)) return true;
    if (pid.isNotEmpty && ids.contains(pid)) return true;
    return false;
  }

  Future<void> _finishWithRaw(String raw) async {
    if (_locked || !mounted) return;

    final assetId = _parseAssetId(raw);
    if (assetId == null || assetId.isEmpty) {
      setState(() {
        _err =
            'QR nije prepoznat kao uređaj. Očekujem šifru iz šifrarnika ili oblik assetId: …';
      });
      return;
    }

    setState(() {
      _locked = true;
      _err = null;
    });

    if (_useDeviceCamera) {
      await _cameraController.stop();
    }

    try {
      final cid = widget.companyId.trim();
      if (cid.isEmpty) {
        throw Exception('Nedostaje podatak o kompaniji. Obrati se administratoru.');
      }

      final snap = await FirebaseFirestore.instance
          .collection('assets')
          .doc(assetId)
          .get();

      if (!snap.exists) {
        throw Exception('Uređaj nije pronađen u šifrarniku.');
      }

      final d = snap.data() ?? <String, dynamic>{};
      final ac = _s(d['companyId']);
      if (ac.isNotEmpty && ac != cid) {
        throw Exception('Ovaj QR pripada drugoj kompaniji.');
      }

      if (!_plantAllowed(d)) {
        throw Exception(
          'Uređaj nije u tvom pogonu (plantKey/plantId ne odgovara tvom profilu).',
        );
      }

      final out = Map<String, dynamic>.from(d);
      out['__assetDocId'] = snap.id;

      if (!mounted) return;
      Navigator.of(context).pop(out);
    } catch (e) {
      if (!mounted) return;
      final msg = e is FirebaseException
          ? AppErrorMapper.toMessage(e)
          : _userFacingError(e);
      setState(() {
        _locked = false;
        _err = msg;
      });
      if (_useDeviceCamera) {
        try {
          await _cameraController.start();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR uređaja'),
        actions: [
          if (_useDeviceCamera)
            IconButton(
              tooltip: 'Bljeskalica',
              onPressed: () => _cameraController.toggleTorch(),
              icon: const Icon(Icons.flash_on_outlined),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_err != null)
            MaterialBanner(
              content: Text(_err!, maxLines: 4),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _err = null),
                  child: const Text('OK'),
                ),
              ],
            ),
          if (_useDeviceCamera)
            Expanded(
              child: ClipRect(
                child: MobileScanner(
                  controller: _cameraController,
                  onDetect: (capture) {
                    if (_locked) return;
                    final codes = capture.barcodes;
                    if (codes.isEmpty) return;
                    final raw = codes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    _finishWithRaw(raw);
                  },
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kamera nije dostupna. Zalijepi sadržaj QR koda u polje ispod.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _manualController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ručni unos (sadržaj QR)',
                    alignLabelWithHint: true,
                  ),
                  onSubmitted: (_) {
                    if (!_locked) _finishWithRaw(_manualController.text);
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _locked
                      ? null
                      : () => _finishWithRaw(_manualController.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Učitaj uređaj'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
