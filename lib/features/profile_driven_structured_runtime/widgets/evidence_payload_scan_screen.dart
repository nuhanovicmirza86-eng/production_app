import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// M1-I5-C7 — kanonske BS poruke za sken / ručni unos proizvodnog naloga.
abstract final class EvidenceOrderScanUx {
  static const scannerUnavailableMessage =
      'Skener nije dostupan na ovom uređaju. Unesite broj naloga ručno.';

  static const orderNotFoundMessage =
      'Nalog nije pronađen. Provjerite QR kod ili uneseni broj naloga.';

  static const scanButtonLabel = 'Skeniraj QR / barkod';
  static const manualOrderButtonLabel = 'Pretraga naloga';

  static bool get useDeviceCamera {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}

/// Kamera (telefon) ili ručni unos — vraća sirovi payload za
/// `resolveProductionEvidenceScan`.
class EvidencePayloadScanScreen extends StatefulWidget {
  const EvidencePayloadScanScreen({
    super.key,
    this.initialManualOnly = false,
  });

  /// Kad je true (npr. web/desktop), odmah prikaži ručni unos bez kamere.
  final bool initialManualOnly;

  @override
  State<EvidencePayloadScanScreen> createState() =>
      _EvidencePayloadScanScreenState();
}

class _EvidencePayloadScanScreenState extends State<EvidencePayloadScanScreen> {
  MobileScannerController? _cameraController;
  final TextEditingController _manualController = TextEditingController();
  bool _locked = false;

  bool get _showCamera =>
      EvidenceOrderScanUx.useDeviceCamera && !widget.initialManualOnly;

  @override
  void initState() {
    super.initState();
    if (_showCamera) {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _finishWithRaw(String raw) async {
    final payload = raw.trim();
    if (_locked || payload.isEmpty || !mounted) return;
    _locked = true;
    try {
      await _cameraController?.stop();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(payload);
    });
  }

  void _onManualSubmit() => _finishWithRaw(_manualController.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showCamera ? 'Skeniraj QR / barkod' : 'Unesi broj naloga',
        ),
        actions: [
          if (_showCamera && _cameraController != null)
            IconButton(
              tooltip: 'Bljeskalica',
              onPressed: () => _cameraController!.toggleTorch(),
              icon: const Icon(Icons.flash_on_outlined),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showCamera) ...[
            Expanded(
              child: ClipRect(
                child: MobileScanner(
                  controller: _cameraController!,
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
                'Usmjerite kameru na QR / barkod radnog naloga. '
                'Ispod možete unijeti broj naloga ručno.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                EvidenceOrderScanUx.scannerUnavailableMessage,
                style: Theme.of(context).textTheme.bodyMedium,
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
                  autofocus: !_showCamera,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Broj naloga ili sadržaj QR',
                    border: OutlineInputBorder(),
                    helperText:
                        'Ručni unos broja naloga ili zalijepljeni QR payload.',
                  ),
                  onSubmitted: _locked ? null : (_) => _onManualSubmit(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _locked ? null : _onManualSubmit,
                  icon: const Icon(Icons.check),
                  label: const Text('Potvrdi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
