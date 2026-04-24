import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../logistics/inventory/widgets/product_warehouse_stock_section.dart';
import '../../../quality/models/qms_document_kind.dart';
import '../../../quality/models/qms_list_models.dart';
import '../../../quality/services/quality_callable_service.dart';
import '../services/product_service.dart';

/// Tab „Zaliha“: stanje po magacinima + minimalna / optimalna zaliha (IATF polja na `products`).
class ProductDetailsStockTab extends StatefulWidget {
  final String companyId;
  final String productId;
  final String? plantKey;
  final String? fallbackUnit;
  final Map<String, dynamic> product;
  final String updatedByUid;
  final bool canEdit;
  final Future<void> Function() onStockSettingsSaved;

  const ProductDetailsStockTab({
    super.key,
    required this.companyId,
    required this.productId,
    this.plantKey,
    this.fallbackUnit,
    required this.product,
    required this.updatedByUid,
    required this.canEdit,
    required this.onStockSettingsSaved,
  });

  @override
  State<ProductDetailsStockTab> createState() => _ProductDetailsStockTabState();
}

class _ProductDetailsStockTabState extends State<ProductDetailsStockTab> {
  final ProductService _productService = ProductService();
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  bool _saving = false;

  static String _formatNumForField(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      final d = v.toDouble();
      if (d == d.roundToDouble()) return d.round().toString();
      return d.toString();
    }
    return v.toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: _formatNumForField(widget.product['minStockQty']),
    );
    _maxCtrl = TextEditingController(
      text: _formatNumForField(widget.product['maxStockQty']),
    );
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  double? _parseUpdateDouble(String text, {required String label}) {
    final s = text.trim().replaceAll(',', '.');
    if (s.isEmpty) return 0.0;
    final v = double.tryParse(s);
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neispravan broj: $label')),
      );
      return null;
    }
    return v;
  }

  Future<void> _saveThresholds() async {
    if (!widget.canEdit) return;
    final minUp = _parseUpdateDouble(_minCtrl.text, label: 'Minimalna zaliha');
    if (minUp == null) return;
    final maxUp = _parseUpdateDouble(_maxCtrl.text, label: 'Optimalna zaliha');
    if (maxUp == null) return;
    final uid = widget.updatedByUid.trim();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostaje korisnik za spremanje.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _productService.updateProduct(
        productId: widget.productId,
        companyId: widget.companyId,
        updatedBy: uid,
        minStockQty: minUp,
        maxStockQty: maxUp,
      );
      if (!mounted) return;
      await widget.onStockSettingsSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postavke zalihe su spremljene.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciljevi zalihe',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Minimalna i optimalna količina u istoj jedinici kao proizvod '
                  '(uskladio se s poljima u uređivanju proizvoda — min. / max. zaliha).',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _minCtrl,
                  enabled: widget.canEdit && !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimalna zaliha',
                    hintText: 'Prazno = ukloni',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxCtrl,
                  enabled: widget.canEdit && !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Optimalna zaliha',
                    hintText: 'Prazno = ukloni (u bazi: max. zaliha)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.canEdit) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveThresholds,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Spremi ciljeve zalihe'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ProductWarehouseStockSection(
          companyId: widget.companyId,
          productId: widget.productId,
          plantKey: widget.plantKey,
          fallbackUnit: widget.fallbackUnit,
        ),
      ],
    );
  }
}

/// Tab „Dokumentacija“: QMS dokumenti vezani uz ovaj proizvod.
class ProductDetailsDocumentationTab extends StatefulWidget {
  final String companyId;
  final String productId;

  const ProductDetailsDocumentationTab({
    super.key,
    required this.companyId,
    required this.productId,
  });

  @override
  State<ProductDetailsDocumentationTab> createState() =>
      _ProductDetailsDocumentationTabState();
}

class _ProductDetailsDocumentationTabState
    extends State<ProductDetailsDocumentationTab> {
  final QualityCallableService _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  final Map<QmsDocumentKind, List<QmsDocumentRow>> _byKind = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openUrl(String? url) async {
    final u = url?.trim();
    if (u == null || u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openFile(QmsDocumentRow r) async {
    try {
      final dl = await _svc.getQmsDocumentSignedDownloadUrl(
        companyId: widget.companyId,
        qmsDocumentId: r.id,
      );
      final u = dl.downloadUrl.trim();
      if (u.isEmpty) return;
      final uri = Uri.tryParse(u);
      if (uri == null || !uri.hasScheme) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorMapper.toMessage(e))),
      );
    }
  }

  Future<void> _load() async {
    final cid = widget.companyId.trim();
    final pid = widget.productId.trim();
    if (cid.isEmpty || pid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaju podaci.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _byKind.clear();
    });

    try {
      for (final k in QmsDocumentKind.values) {
        final page = await _svc.listQmsDocuments(
          companyId: cid,
          documentKind: k.apiValue,
          productId: pid,
          limit: 80,
        );
        _byKind[k] = page.items;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<QmsDocumentRow> rows,
  }) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...rows.map((r) {
              final hasFile =
                  (r.fileStoragePath ?? '').trim().isNotEmpty ||
                      (r.fileName ?? '').trim().isNotEmpty;
              final ext = (r.externalUrl ?? '').trim();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  r.title.trim().isEmpty ? 'Bez naslova' : r.title.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    r.documentCode?.trim(),
                    r.status,
                    if ((r.updatedAtIso ?? '').length >= 10)
                      r.updatedAtIso!.substring(0, 10),
                  ].where((e) => (e ?? '').toString().isNotEmpty).join(' · '),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ext.isNotEmpty)
                      IconButton(
                        tooltip: 'Vanjski link',
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => _openUrl(ext),
                      ),
                    if (hasFile)
                      IconButton(
                        tooltip: 'Preuzmi datoteku',
                        icon: const Icon(Icons.download_outlined, size: 20),
                        onPressed: () => _openFile(r),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ],
      );
    }

    final work = _byKind[QmsDocumentKind.workInstruction] ?? const [];
    final pack = _byKind[QmsDocumentKind.packingInstruction] ?? const [];
    final forms = _byKind[QmsDocumentKind.form] ?? const [];
    final other = _byKind[QmsDocumentKind.other] ?? const [];
    final formsAndCatalogs = [...forms, ...other];
    final emptyDocs = work.isEmpty &&
        pack.isEmpty &&
        forms.isEmpty &&
        other.isEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (emptyDocs)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'Nema QMS dokumentacije vezane uz ovaj proizvod '
                '(radni uputi, pakovanje, obrasci / katalozi).',
                style: TextStyle(color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),
            ),
          _section(context, title: 'Radni uputi', rows: work),
          _section(context, title: 'Upute za pakovanje', rows: pack),
          if (forms.isNotEmpty || other.isNotEmpty)
            _section(
              context,
              title: 'Obrasci i katalozi (ukl. katalog grešaka ako je unesen kao obrazac)',
              rows: formsAndCatalogs,
            ),
        ],
      ),
    );
  }
}

/// Tab „Reklamacije“: NCR zapisi za ovaj proizvod.
class ProductDetailsComplaintsTab extends StatefulWidget {
  final String companyId;
  final String productId;

  const ProductDetailsComplaintsTab({
    super.key,
    required this.companyId,
    required this.productId,
  });

  @override
  State<ProductDetailsComplaintsTab> createState() =>
      _ProductDetailsComplaintsTabState();
}

class _ProductDetailsComplaintsTabState extends State<ProductDetailsComplaintsTab> {
  final QualityCallableService _svc = QualityCallableService();
  bool _loading = true;
  String? _error;
  List<QmsNcrRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = widget.companyId.trim();
    final pid = widget.productId.trim();
    if (cid.isEmpty || pid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaju podaci.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _svc.listNonConformances(
        companyId: cid,
        productId: pid,
        limit: 200,
        openOnly: false,
      );
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  static String _statusHr(String s) {
    switch (s.trim().toUpperCase()) {
      case 'OPEN':
        return 'Otvoren';
      case 'CLOSED':
        return 'Zatvoren';
      case 'CANCELLED':
        return 'Otkazan';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: Colors.red.shade800)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ],
      );
    }

    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
            ),
            Text(
              'Nema evidentiranih reklamacija / NCR zapisa za ovaj proizvod.',
              style: TextStyle(color: Theme.of(context).hintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final cs = Theme.of(context).colorScheme;
          return Card(
            child: ListTile(
              title: Text(
                r.ncrCode.trim().isEmpty ? r.id : r.ncrCode.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    r.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(_statusHr(r.status)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        label: Text('Izvor: ${r.source}'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if ((r.createdAtIso ?? '').length >= 10)
                        Text(
                          r.createdAtIso!.substring(0, 10),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
