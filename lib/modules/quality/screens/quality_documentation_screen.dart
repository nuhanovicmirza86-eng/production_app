import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../production/products/services/product_service.dart';
import '../models/qms_document_kind.dart';
import '../models/qms_list_models.dart';
import '../services/quality_callable_service.dart';
import '../widgets/qms_display_formatters.dart';
import '../widgets/qms_iatf_help.dart';
import '../widgets/qms_pickers.dart';

/// Centralno mjesto za radne upute, upute za pakovanje, obrasce itd.
/// Lista: [listQmsDocuments] (paginacija). Datoteka: potpisani upload (Callable) + HTTP PUT.
class QualityDocumentationScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const QualityDocumentationScreen({super.key, required this.companyData});

  @override
  State<QualityDocumentationScreen> createState() =>
      _QualityDocumentationScreenState();
}

class _QualityDocumentationScreenState extends State<QualityDocumentationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final QualityCallableService _svc = QualityCallableService();
  final ProductService _productService = ProductService();

  static const _kinds = QmsDocumentKind.values;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  /// Povećaj nakon spremanja dokumenta da se tabovi ponovo učitaju.
  int _reloadSeq = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kinds.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog(QmsDocumentKind kind) async {
    final cid = _companyId;
    if (cid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddQmsDocumentDialog(
        companyId: cid,
        kind: kind,
        svc: _svc,
        productService: _productService,
      ),
    );
    if (ok == true && mounted) {
      setState(() => _reloadSeq++);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dokument je spremljen.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cid = _companyId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumentacija'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final k in _kinds) Tab(text: k.shortLabel)],
        ),
        actions: [
          QmsIatfInfoIcon(
            title: 'Dokumentacija',
            message: QmsIatfStrings.documentationHub,
          ),
        ],
      ),
      body: cid.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nedostaje podatak o kompaniji.'),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                for (final kind in _kinds)
                  _DocumentKindTab(
                    key: ValueKey('doc_${_reloadSeq}_${kind.apiValue}'),
                    companyId: cid,
                    kind: kind,
                    svc: _svc,
                    onOpenUrl: _openExternalUrl,
                    onDownloadFile: _openStoredFile,
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(_kinds[_tabController.index]),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj dokument'),
      ),
    );
  }

  static String _productLine(QmsDocumentRow r) {
    final code = r.productCodeSnapshot?.trim();
    final name = r.productNameSnapshot?.trim();
    if (code != null && code.isNotEmpty) {
      if (name != null && name.isNotEmpty) return '$code · $name';
      return code;
    }
    if (name != null && name.isNotEmpty) return name;
    return r.productId;
  }

  static String _formatUpdated(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    if (iso.length >= 10) return iso.substring(0, 10);
    return iso;
  }

  Future<void> _openExternalUrl(String? url) async {
    final u = url?.trim();
    if (u == null || u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openStoredFile(String companyId, QmsDocumentRow r) async {
    try {
      final dl = await _svc.getQmsDocumentSignedDownloadUrl(
        companyId: companyId,
        qmsDocumentId: r.id,
      );
      final u = dl.downloadUrl.trim();
      if (u.isEmpty) return;
      final uri = Uri.tryParse(u);
      if (uri == null || !uri.hasScheme) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _DocumentKindTab extends StatefulWidget {
  const _DocumentKindTab({
    super.key,
    required this.companyId,
    required this.kind,
    required this.svc,
    required this.onOpenUrl,
    required this.onDownloadFile,
  });

  final String companyId;
  final QmsDocumentKind kind;
  final QualityCallableService svc;
  final Future<void> Function(String? url) onOpenUrl;
  final Future<void> Function(String companyId, QmsDocumentRow row)
  onDownloadFile;

  @override
  State<_DocumentKindTab> createState() => _DocumentKindTabState();
}

class _DocumentKindTabState extends State<_DocumentKindTab> {
  final List<QmsDocumentRow> _rows = [];
  String? _nextToken;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Dokument u tijeku brisanja (sprječava dvostruki klik).
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
      _nextToken = null;
      _rows.clear();
    });
    try {
      final page = await widget.svc.listQmsDocuments(
        companyId: widget.companyId,
        documentKind: widget.kind.apiValue,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.items);
        _nextToken = page.nextPageToken;
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

  Future<void> _loadMore() async {
    final t = _nextToken;
    if (t == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.svc.listQmsDocuments(
        companyId: widget.companyId,
        documentKind: widget.kind.apiValue,
        limit: 50,
        pageToken: t,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.items);
        _nextToken = page.nextPageToken;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  Future<void> _confirmDelete(QmsDocumentRow r) async {
    final label = r.title.trim().isEmpty
        ? 'ovaj dokument'
        : '„${r.title.trim()}“';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati dokument?'),
        content: Text(
          '$label će biti uklonjen iz liste. Ovo ne može poništiti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deletingId = r.id);
    try {
      await widget.svc.deleteQmsDocument(
        companyId: widget.companyId,
        qmsDocumentId: r.id,
      );
      if (!mounted) return;
      setState(() {
        _rows.removeWhere((e) => e.id == r.id);
        _deletingId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dokument je obrisan.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadFirst,
                child: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  widget.kind.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dokumenti vezani uz proizvod. Lista je straničena (50 po stranici). '
                  'Datoteka: upload na storage preko potpisanog URL-a.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          if (_rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined, size: 56, color: cs.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Još nema dokumenata u ovoj kategoriji.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dodaj dokument i odaberi proizvod — opcionalno priloži datoteku.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final r = _rows[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(r.title.isEmpty ? 'Bez naslova' : r.title),
                      trailing: _deletingId == r.id
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Obriši dokument',
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => _confirmDelete(r),
                            ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proizvod: ${_QualityDocumentationScreenState._productLine(r)}',
                          ),
                          Text(
                            'Status: ${QmsDisplayFormatters.qmsDocStatus(r.status)} · '
                            'Ažurirano: ${_QualityDocumentationScreenState._formatUpdated(r.updatedAtIso)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          if (r.notes != null && r.notes!.trim().isNotEmpty)
                            Text(
                              r.notes!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (r.fileStoragePath != null &&
                              r.fileStoragePath!.trim().isNotEmpty)
                            TextButton.icon(
                              onPressed: () =>
                                  widget.onDownloadFile(widget.companyId, r),
                              icon: const Icon(
                                Icons.download_outlined,
                                size: 18,
                              ),
                              label: Text(
                                r.fileName?.trim().isNotEmpty == true
                                    ? 'Preuzmi: ${r.fileName}'
                                    : 'Preuzmi datoteku',
                              ),
                            ),
                          if (r.externalUrl != null &&
                              r.externalUrl!.trim().isNotEmpty)
                            TextButton.icon(
                              onPressed: () => widget.onOpenUrl(r.externalUrl),
                              icon: const Icon(Icons.link, size: 18),
                              label: const Text('Vanjski link'),
                            ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _rows.length),
              ),
            ),
          if (_rows.isNotEmpty && _nextToken != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Center(
                  child: FilledButton.tonal(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Učitaj više'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddQmsDocumentDialog extends StatefulWidget {
  const _AddQmsDocumentDialog({
    required this.companyId,
    required this.kind,
    required this.svc,
    required this.productService,
  });

  final String companyId;
  final QmsDocumentKind kind;
  final QualityCallableService svc;
  final ProductService productService;

  @override
  State<_AddQmsDocumentDialog> createState() => _AddQmsDocumentDialogState();
}

class _AddQmsDocumentDialogState extends State<_AddQmsDocumentDialog> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _externalUrl = TextEditingController();

  String? _productId;
  String? _productLabel;
  String? _productNameSnapshot;
  String? _productCodeSnapshot;
  String _status = 'draft';
  bool _submitting = false;

  Uint8List? _fileBytes;
  String? _pickedName;
  String? _mime;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _externalUrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final id = await showQmsProductPicker(
      context: context,
      companyId: widget.companyId,
    );
    if (id == null || !mounted) return;
    try {
      final p = await widget.productService.getProductById(
        productId: id,
        companyId: widget.companyId,
      );
      if (!mounted) return;
      final code = (p?['productCode'] ?? '').toString().trim();
      final name = (p?['productName'] ?? '').toString().trim();
      setState(() {
        _productId = id;
        _productNameSnapshot = name.isEmpty ? null : name;
        _productCodeSnapshot = code.isEmpty ? null : code;
        _productLabel = code.isNotEmpty && name.isNotEmpty
            ? '$code · $name'
            : (name.isNotEmpty ? name : (code.isNotEmpty ? code : id));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productId = id;
        _productLabel = id;
        _productNameSnapshot = null;
        _productCodeSnapshot = null;
      });
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Datoteka nije učitana u memoriju (probaj manju datoteku).',
            ),
          ),
        );
      }
      return;
    }
    final name = f.name.trim().isEmpty ? 'datoteka' : f.name.trim();
    setState(() {
      _fileBytes = bytes;
      _pickedName = name;
      _mime = _guessMimeFromName(name);
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final pid = _productId?.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unesi naslov dokumenta.')));
      return;
    }
    if (pid == null || pid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Odaberi proizvod.')));
      return;
    }

    final notes = _notes.text.trim();
    final ext = _externalUrl.text.trim();

    setState(() => _submitting = true);
    try {
      final id = await widget.svc.upsertQmsDocument(
        companyId: widget.companyId,
        title: title,
        productId: pid,
        documentKind: widget.kind.apiValue,
        status: _status,
        notes: notes.isEmpty ? null : notes,
        externalUrl: ext.isEmpty ? null : ext,
        productNameSnapshot: _productNameSnapshot,
        productCodeSnapshot: _productCodeSnapshot,
      );

      if (_fileBytes != null &&
          _pickedName != null &&
          _pickedName!.isNotEmpty) {
        final ct =
            _mime ??
            _guessMimeFromName(_pickedName!) ??
            'application/octet-stream';
        final up = await widget.svc.getQmsDocumentSignedUploadUrl(
          companyId: widget.companyId,
          qmsDocumentId: id,
          fileName: _pickedName!,
          contentType: ct,
        );
        final put = await http.put(
          Uri.parse(up.uploadUrl),
          headers: {'Content-Type': up.contentType},
          body: _fileBytes!,
        );
        if (put.statusCode < 200 || put.statusCode >= 300) {
          throw Exception('Upload neuspješan (HTTP ${put.statusCode}).');
        }
        await widget.svc.upsertQmsDocument(
          companyId: widget.companyId,
          qmsDocumentId: id,
          title: title,
          productId: pid,
          documentKind: widget.kind.apiValue,
          status: _status,
          notes: notes.isEmpty ? null : notes,
          externalUrl: ext.isEmpty ? null : ext,
          productNameSnapshot: _productNameSnapshot,
          productCodeSnapshot: _productCodeSnapshot,
          fileName: _pickedName,
          fileStoragePath: up.storagePath,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String? _guessMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Novi dokument · ${widget.kind.label}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Naslov'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickProduct,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(_productLabel ?? 'Odaberi proizvod'),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Status',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Nacrt')),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Odobreno'),
                      ),
                      DropdownMenuItem(
                        value: 'obsolete',
                        child: Text('Zastarjelo'),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) {
                            if (v != null) setState(() => _status = v);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _pickedName != null
                      ? 'Datoteka: $_pickedName'
                      : 'Priloži datoteku (opcionalno)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Napomena (opcionalno)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _externalUrl,
                decoration: const InputDecoration(
                  labelText: 'Vanjski link (opcionalno)',
                  hintText: 'https://…',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Spremi'),
        ),
      ],
    );
  }
}
