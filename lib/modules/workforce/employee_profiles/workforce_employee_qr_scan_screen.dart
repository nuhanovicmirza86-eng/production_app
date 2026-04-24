import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'workforce_employee_qr_navigation.dart';

bool get _useDeviceCamera {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Sken bedža radnika ([buildWorkforceEmployeeQrPayload]) → otvaranje [EmployeeEditScreen].
class WorkforceEmployeeQrScanScreen extends StatefulWidget {
  const WorkforceEmployeeQrScanScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<WorkforceEmployeeQrScanScreen> createState() =>
      _WorkforceEmployeeQrScanScreenState();
}

class _WorkforceEmployeeQrScanScreenState
    extends State<WorkforceEmployeeQrScanScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();

  /// Sprječava dupli okidač skenere prije nego se zatvori ruta.
  bool _locked = false;
  bool _busy = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handleRaw(String raw) async {
    if (_locked || !mounted) return;
    _locked = true;
    setState(() => _busy = true);
    if (_useDeviceCamera) {
      await _cameraController.stop();
    }
    if (!mounted) return;

    try {
      final opened = await openWorkforceEmployeeFromBadgeQr(
        context: context,
        companyData: widget.companyData,
        rawPayload: raw,
      );
      if (!mounted) return;
      if (opened) {
        Navigator.of(context).pop();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Greška: $e')));
      }
    }

    if (!mounted) return;
    _locked = false;
    setState(() => _busy = false);
    if (_useDeviceCamera) {
      await _cameraController.start();
    }
  }

  void _onManualSubmit() {
    _handleRaw(_manualController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skeniraj bedž radnika'),
        actions: [
          if (_useDeviceCamera)
            IconButton(
              tooltip: 'Bljeskalica',
              onPressed: _busy ? null : () => _cameraController.toggleTorch(),
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
                    if (_busy) return;
                    final codes = capture.barcodes;
                    if (codes.isEmpty) return;
                    final raw = codes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    _handleRaw(raw);
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Usmjeri kameru na QR s bedža radnika. Na webu i desktopu zalijepi sadržaj ispod.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kamera nije dostupna. Zalijepi sadržaj QR koda (iz Generiraj / kopiraj na profilu radnika).',
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
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Ručni unos (sadržaj QR)',
                    alignLabelWithHint: true,
                  ),
                  onSubmitted: (_) => _onManualSubmit(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _onManualSubmit,
                  icon: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner),
                  label: Text(_busy ? 'Otvaram…' : 'Otvori radnika'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
