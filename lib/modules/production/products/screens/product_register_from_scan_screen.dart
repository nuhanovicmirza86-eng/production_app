import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../logistics/wms/wms_scan_helpers.dart';
import '../services/product_lookup_service.dart';
import 'product_create_screen.dart';

/// Prvo skeniranje postojećeg barkoda/QR-a, zatim isti obrazac kao [ProductCreateScreen].
class ProductRegisterFromScanScreen extends StatefulWidget {
  const ProductRegisterFromScanScreen({super.key, required this.companyData});

  final Map<String, dynamic> companyData;

  @override
  State<ProductRegisterFromScanScreen> createState() =>
      _ProductRegisterFromScanScreenState();
}

class _ProductRegisterFromScanScreenState
    extends State<ProductRegisterFromScanScreen> {
  final _lookup = ProductLookupService();
  final _controller = TextEditingController();
  bool _busy = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final raw = await wmsScanBarcodeRaw(
      context,
      companyData: widget.companyData,
    );
    if (!mounted || raw == null || raw.isEmpty) return;
    setState(() => _controller.text = raw);
  }

  Future<void> _continue() async {
    final raw = ProductLookupService.normalizeScanAlias(_controller.text);
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unesi ili skeniraj sadržaj barkoda / QR-a.'),
        ),
      );
      return;
    }

    if (_companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje podatak o kompaniji. Obrati se administratoru.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final existing = await _lookup.getByScanAlias(
        companyId: _companyId,
        raw: raw,
      );
      if (!mounted) return;
      if (existing != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Kod je već u sistemu'),
            content: Text(
              'Ovaj barkod/QR je već vezan za proizvod:\n'
              '${existing.productCode} — ${existing.productName}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        );
        return;
      }

      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ProductCreateScreen(
            companyData: widget.companyData,
            initialScanAliases: [raw],
          ),
        ),
      );
      if (!mounted) return;
      if (created == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novi proizvod iz barkoda / QR'),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Za artikle koji već imaju etiketu u proizvodnji, skeniraj ili '
              'zalijepi točan sadržaj (EAN, QR, interni kod). Zatim unosiš '
              'šifru i naziv u Operonix kao i inače.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Sadržaj barkoda / QR',
                      hintText: 'Skeniraj ili zalijepi',
                    ),
                    maxLines: 3,
                  ),
                ),
                IconButton(
                  tooltip: 'Skeniraj',
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _continue,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('Nastavi na unos proizvoda'),
            ),
          ],
        ),
      ),
    );
  }
}
