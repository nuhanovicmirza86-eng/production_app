import 'package:flutter/material.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../models/ncr_action_history_models.dart';
import '../services/quality_callable_service.dart';
import '../utils/qms_ncr_display_labels.dart';
import '../widgets/ncr_action_history_timeline.dart';
import '../widgets/qms_iatf_help.dart';
import 'ncr_detail_screen.dart';

/// QMS hub — pregled historije akcija NCR-a (M1-I13-D).
class NcrActionHistoryHubScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const NcrActionHistoryHubScreen({super.key, required this.companyData});

  @override
  State<NcrActionHistoryHubScreen> createState() =>
      _NcrActionHistoryHubScreenState();
}

class _NcrActionHistoryHubScreenState extends State<NcrActionHistoryHubScreen> {
  final _svc = QualityCallableService();

  bool _loading = true;
  String? _error;
  var _rows = const <NcrActionHistoryHubRow>[];

  /// `open` | `closed` | `all`
  String _statusFilter = 'all';

  String get _cid =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime? _parseBsDateTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '—') return null;
    final m = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4})\.\s*(\d{2}):(\d{2})$',
    ).firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Nedostaje podatak o kompaniji. Obrati se administratoru.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ncrs = await _svc.listNonConformances(
        companyId: cid,
        statusFilter: _statusFilter,
        limit: 40,
      );

      final hubRows = <NcrActionHistoryHubRow>[];
      await Future.wait(
        ncrs.map((ncr) async {
          try {
            final hist = await _svc.listNcrActionHistory(
              companyId: cid,
              ncrId: ncr.id,
              limit: 15,
            );
            for (final entry in hist.items) {
              hubRows.add(
                NcrActionHistoryHubRow(
                  entry: entry,
                  ncrDocumentNo: hist.ncrDocumentNo.isNotEmpty
                      ? hist.ncrDocumentNo
                      : QmsNcrDisplayLabels.displayDocumentNumber(
                          ncrCode: ncr.ncrCode,
                          ncrDocumentNo: ncr.ncrDocumentNo,
                        ),
                  ncrStatusLabel: hist.ncrStatusLabel.isNotEmpty
                      ? hist.ncrStatusLabel
                      : QmsNcrDisplayLabels.status(ncr.status),
                  ncrId: ncr.id,
                ),
              );
            }
          } catch (_) {
            // Jedan NCR ne smije oboriti cijeli hub pregled.
          }
        }),
      );

      hubRows.sort((a, b) {
        final da = _parseBsDateTime(a.entry.occurredAt);
        final db = _parseBsDateTime(b.entry.occurredAt);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _rows = hubRows;
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

  void _setStatusFilter(String value) {
    if (_statusFilter == value) return;
    setState(() => _statusFilter = value);
    _load();
  }

  Future<void> _openNcrDetail(String ncrId) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NcrDetailScreen(
          companyData: widget.companyData,
          ncrId: ncrId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historija akcija NCR-a'),
        actions: const [
          QmsIatfInfoIcon(
            title: 'Historija akcija',
            message:
                'Poslovni ledger svih akcija na neusaglašenostima — '
                'ko je dodijelio, kome, rok i izvor. Odvojeno od IATF audit traga.',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Sve'),
                  selected: _statusFilter == 'all',
                  onSelected: (_) => _setStatusFilter('all'),
                ),
                ChoiceChip(
                  label: const Text('Otvorene'),
                  selected: _statusFilter == 'open',
                  onSelected: (_) => _setStatusFilter('open'),
                ),
                ChoiceChip(
                  label: const Text('Zatvorene'),
                  selected: _statusFilter == 'closed',
                  onSelected: (_) => _setStatusFilter('closed'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NcrActionHistoryTimeline(
              entries: _rows,
              loading: _loading,
              error: _error,
              showNcrHeader: true,
              onNcrTap: _openNcrDetail,
              onRetry: _load,
            ),
          ],
        ),
      ),
    );
  }
}
