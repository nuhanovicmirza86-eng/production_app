import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/structured_entity_search_result.dart';
import '../services/production_evidence_entity_search_service.dart';
import 'evidence_payload_scan_screen.dart';

/// M1-I5-C7A — pretraga naloga dok korisnik kuca (autocomplete).
Future<StructuredScanResolveResult?> showEvidenceProductionOrderSearchDialog({
  required BuildContext context,
  required String companyId,
  String? plantKey,
  required ProductionEvidenceEntitySearchCallableService searchService,
}) {
  return showDialog<StructuredScanResolveResult>(
    context: context,
    builder: (ctx) => _EvidenceProductionOrderSearchDialog(
      companyId: companyId,
      searchService: searchService,
    ),
  );
}

class _EvidenceProductionOrderSearchDialog extends StatefulWidget {
  const _EvidenceProductionOrderSearchDialog({
    required this.companyId,
    required this.searchService,
  });

  final String companyId;
  final ProductionEvidenceEntitySearchCallableService searchService;

  @override
  State<_EvidenceProductionOrderSearchDialog> createState() =>
      _EvidenceProductionOrderSearchDialogState();
}

class _EvidenceProductionOrderSearchDialogState
    extends State<_EvidenceProductionOrderSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  Object? _error;
  List<StructuredEntitySearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      // Ne slati plantKey — Callable odbija klijentski plantKey.
      final items = await widget.searchService.searchProductionOrders(
        companyId: widget.companyId,
        query: q,
        limit: 25,
      );
      if (!mounted) return;
      setState(() {
        _results = items;
        _searching = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _searching = false;
        _results = const [];
      });
    }
  }

  void _select(StructuredEntitySearchResult item) {
    final resolved = StructuredScanResolveResult.fromOrderSearchResult(item);
    if (!resolved.isKnown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(EvidenceOrderScanUx.orderNotFoundMessage),
        ),
      );
      return;
    }
    Navigator.pop(context, resolved);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxListHeight = math.max(
      120.0,
      math.min(280.0, media.size.height - media.viewInsets.bottom - 280),
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: const Text('Pretraga proizvodnog naloga'),
      content: SizedBox(
        width: math.min(420, media.size.width - 48),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Broj naloga / proizvod',
                  border: const OutlineInputBorder(),
                  helperText:
                      'Unesite najmanje 2 znaka — prijedlozi se filtriraju.',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search),
                ),
                onChanged: _scheduleSearch,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  productionEvidenceEntitySearchErrorMessage(_error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ] else ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: maxListHeight,
                  child: _results.isEmpty
                      ? Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _controller.text.trim().length < 2
                                  ? 'Počnite kucati broj naloga…'
                                  : (_searching
                                      ? 'Pretraga…'
                                      : EvidenceOrderScanUx
                                          .orderNotFoundMessage),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            final subtitle = item.secondaryLabel;
                            final line =
                                (subtitle == null || subtitle.isEmpty)
                                    ? item.displayLabel
                                    : '${item.displayLabel} — $subtitle';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(line),
                              onTap: () => _select(item),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
      ],
    );
  }
}
