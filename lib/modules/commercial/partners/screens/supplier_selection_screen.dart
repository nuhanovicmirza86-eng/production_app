import 'package:flutter/material.dart';

import '../services/supplier_selection_callable_service.dart';

/// Supplier Selection / rangiranje dobavljača (Callable v1).
///
/// AI Asistent **ne** mijenja odabir — samo backend rangiranje i ručna potvrda.
class SupplierSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const SupplierSelectionScreen({super.key, required this.companyData});

  @override
  State<SupplierSelectionScreen> createState() => _SupplierSelectionScreenState();
}

class _SupplierSelectionScreenState extends State<SupplierSelectionScreen> {
  final _svc = SupplierSelectionCallableService();

  final _plantKey = TextEditingController();
  final _productId = TextEditingController();
  final _materialGroup = TextEditingController();
  final _processKey = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _requiredDate = TextEditingController();
  final _candidates = TextEditingController();

  String _companyId = '';

  String? _requestId;
  Map<String, dynamic>? _rankResponse;

  List<Map<String, dynamic>> _recentRequests = [];

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _companyId =
        (widget.companyData['companyId'] ?? '').toString().trim();
    final pk =
        (widget.companyData['plantKey'] ?? '').toString().trim();
    if (pk.isNotEmpty) _plantKey.text = pk;
    _requiredDate.text = DateTime.now().toIso8601String().split('T').first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecentRequests());
  }

  Future<void> _loadRecentRequests() async {
    if (_companyId.isEmpty) return;
    try {
      final items = await _svc.listSupplierSelectionRequests(
        companyId: _companyId,
        plantKey: _plantKey.text.trim(),
        limit: 15,
      );
      if (mounted) setState(() => _recentRequests = items);
    } catch (_) {
      /* Čitanje liste je opcionalno za ovaj ekran; grešku prikaži tek uz eksplicitni refresh. */
    }
  }

  Future<void> _refreshListsManual() async {
    if (_companyId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final items = await _svc.listSupplierSelectionRequests(
        companyId: _companyId,
        plantKey: _plantKey.text.trim(),
        limit: 15,
      );
      if (mounted) {
        setState(() => _recentRequests = items);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Učitano zahtjeva: ${items.length}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška liste (Callable): $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _plantKey.dispose();
    _productId.dispose();
    _materialGroup.dispose();
    _processKey.dispose();
    _qty.dispose();
    _requiredDate.dispose();
    _candidates.dispose();
    super.dispose();
  }

  Future<void> _runCreate() async {
    if (_companyId.isEmpty) return;
    final ids = _candidates.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final qty = double.tryParse(_qty.text.replaceAll(',', '.')) ?? 0;
    setState(() => _busy = true);
    try {
      final rid = await _svc.createSupplierSelectionRequest(
        companyId: _companyId,
        plantKey: _plantKey.text.trim(),
        productId: _productId.text.trim(),
        materialGroup: _materialGroup.text.trim(),
        processKey: _processKey.text.trim(),
        requiredQuantity: qty <= 0 ? 1 : qty,
        requiredDateIso: _requiredDate.text.trim(),
        candidateSupplierIds: ids,
      );
      setState(() {
        _requestId = rid;
        _rankResponse = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zahtjev kreiran: $rid')),
        );
      }
      await _loadRecentRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runRank() async {
    final rid = _requestId?.trim();
    if (rid == null || rid.isEmpty) return;
    setState(() => _busy = true);
    try {
      final data = await _svc.rankSupplierCandidates(
        companyId: _companyId,
        requestId: rid,
      );
      setState(() => _rankResponse = data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rangiranje gotovo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptRecommendation() async {
    final rank = _rankResponse;
    if (rank == null) return;
    final sid =
        (rank['selectionResultId'] ?? '').toString().trim();
    final rec =
        (rank['recommendedSupplierId'] ?? '').toString().trim();
    if (sid.isEmpty || rec.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nema preporuke (svi blokirani ili nedostaju podaci). Ručno overridden ili odbij.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.confirmSupplierSelection(
        companyId: _companyId,
        selectionResultId: sid,
        decision: 'accepted',
        chosenSupplierId: rec,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odabir potvrđen (accepted).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = (_rankResponse?['candidates'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Odabir dobavljača'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Unesi kontekst narudžbe i ID kandidata (Firestore supplierId), '
            'zatim rangiranje. Potvrda „Prihvati preporuku“ šalje Callable '
            'confirmSupplierSelection (accepted).',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plantKey,
            decoration: const InputDecoration(labelText: 'plantKey'),
          ),
          TextField(
            controller: _productId,
            decoration: const InputDecoration(labelText: 'productId'),
          ),
          TextField(
            controller: _materialGroup,
            decoration: const InputDecoration(labelText: 'materialGroup'),
          ),
          TextField(
            controller: _processKey,
            decoration: const InputDecoration(
              labelText: 'processKey (opcionalno)',
            ),
          ),
          TextField(
            controller: _qty,
            decoration: const InputDecoration(labelText: 'requiredQuantity'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _requiredDate,
            decoration: const InputDecoration(
              labelText: 'requiredDate (YYYY-MM-DD)',
            ),
          ),
          TextField(
            controller: _candidates,
            decoration: const InputDecoration(
              labelText: 'candidateSupplierIds (zarez ili razmak)',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          if (_requestId != null)
            Text('Posljednji requestId: $_requestId'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _runCreate,
                child: const Text('Kreiraj zahtjev'),
              ),
              FilledButton.tonal(
                onPressed: (_busy || _requestId == null) ? null : _runRank,
                child: const Text('Rangiraj'),
              ),
              OutlinedButton(
                onPressed: (_busy || _rankResponse == null)
                    ? null
                    : _acceptRecommendation,
                child: const Text('Prihvati preporuku'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _refreshListsManual,
                icon: const Icon(Icons.refresh),
                label: const Text('Osvježi listu (Callable read)'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Zadnji zahtjevi (Callable listSupplierSelectionRequests)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_recentRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Nema zapisa ili još učitavanje.'),
            )
          else
            ..._recentRequests.map((row) {
              final id = (row['id'] ?? '').toString();
              final st = (row['status'] ?? '').toString();
              final pq = (row['requiredQuantity'] ?? '').toString();
              return ListTile(
                dense: true,
                title: Text(id.isEmpty ? '(bez id)' : id),
                subtitle: Text('status: $st · qty: $pq'),
              );
            }),
          const Divider(height: 32),
          Text(
            'Rezultat (${candidates.length} redaka)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...candidates.map((raw) {
            if (raw is! Map) return const SizedBox.shrink();
            final m = Map<String, dynamic>.from(raw);
            final name = (m['supplierName'] ?? '').toString();
            final score = (m['finalScore'] ?? '').toString();
            final blocked = m['blockedCandidate'] == true;
            final sid = (m['supplierId'] ?? '').toString();
            return ListTile(
              dense: true,
              title: Text('$name ($sid)'),
              subtitle: Text(
                blocked ? 'BLOKIRAN · score $score' : 'score $score',
              ),
            );
          }),
        ],
      ),
    );
  }
}
