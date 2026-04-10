import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../production_qr_resolver.dart';

bool get _useDeviceCamera {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Sken QR (kamera na telefonu) ili ručni unos (web / desktop).
class ProductionQrScanScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionQrScanScreen({super.key, required this.companyData});

  @override
  State<ProductionQrScanScreen> createState() => _ProductionQrScanScreenState();
}

class _ProductionQrScanScreenState extends State<ProductionQrScanScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();

  bool _locked = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _finishWithRaw(String raw) async {
    if (_locked || !mounted) return;
    _locked = true;

    if (_useDeviceCamera) {
      await _cameraController.stop();
    }

    final resolution = resolveProductionQrScan(raw);
    if (!mounted) return;
    Navigator.of(context).pop(resolution);
  }

  void _onManualSubmit() {
    _finishWithRaw(_manualController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skeniraj QR'),
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
          if (_useDeviceCamera) ...[
            Expanded(
              child: ClipRect(
                child: MobileScanner(
                  controller: _cameraController,
                  onDetect: (BarcodeCapture capture) {
                    if (_locked) return;
                    final codes = capture.barcodes;
                    if (codes.isEmpty) return;
                    final raw = codes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    _finishWithRaw(raw);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Usmjerite kameru na QR. Na webu i desktopu koristite polje ispod.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kamera nije dostupna na ovoj platformi. Zalijepite sadržaj QR koda '
                '(npr. iz slike ili dokumenta) u polje ispod.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _manualController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ručni unos (sadržaj QR)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onSubmitted: (_) => _onManualSubmit(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _locked ? null : _onManualSubmit,
                  icon: const Icon(Icons.search),
                  label: const Text('Prepoznaj'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
