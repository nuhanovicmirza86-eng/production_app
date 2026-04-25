import 'package:flutter/material.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../services/production_traceability_callable_service.dart';

/// Pregled sljedljivosti (nalog → proizvod → operator tracking + inspekcije).
class ProductionOrderTraceabilityDialog extends StatefulWidget {
  const ProductionOrderTraceabilityDialog({
    super.key,
    required this.companyId,
    required this.productionOrderId,
  });

  final String companyId;
  final String productionOrderId;

  @override
  State<ProductionOrderTraceabilityDialog> createState() =>
      _ProductionOrderTraceabilityDialogState();
}

class _ProductionOrderTraceabilityDialogState
    extends State<ProductionOrderTraceabilityDialog> {
  final _svc = ProductionTraceabilityCallableService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await _svc.getTraceabilityBundle(
        companyId: widget.companyId,
        productionOrderId: widget.productionOrderId,
      );
      if (mounted) {
        setState(() {
          _data = m;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorMapper.toMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sljedljivost proizvoda i naloga'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : _error != null
            ? Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            : SingleChildScrollView(
                child: _data == null
                    ? const Text('Nema podataka.')
                    : _TraceabilityBody(data: _data!),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }
}

class _TraceabilityBody extends StatelessWidget {
  const _TraceabilityBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final order = data['order'];
    final product = data['product'];
    final tracking = data['operatorTracking'];
    final ins = data['inspectionResults'];

    final orderMap = order is Map ? Map<String, dynamic>.from(order) : null;
    Map<String, dynamic>? prodMap;
    if (product is Map) {
      final pm = Map<String, dynamic>.from(product);
      if (pm.isNotEmpty) prodMap = pm;
    }

    final tList = tracking is List ? tracking : const [];
    final iList = ins is List ? ins : const [];

    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sažetak: proizvod, nalog, tko i gdje je radio te kontrola, ako postoji u zapisu. '
          'Potpuna sljedivost u jedinstvenom lancu širi se s daljim razvojem.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (orderMap != null) ...[
          _SectionTitle(title: 'Nalog', icon: Icons.assignment_outlined),
          _kv('Kôd', orderMap['productionOrderCode']?.toString() ?? '—'),
          _kv('Status', orderMap['status']?.toString() ?? '—'),
          _kv('Radni centar', orderMap['workCenterName']?.toString().isNotEmpty == true
              ? orderMap['workCenterName']!.toString()
              : (orderMap['workCenterId']?.toString() ?? '—')),
          _kv('Ulazni lot (SK)', orderMap['inputMaterialLot']?.toString() ?? '—'),
        ],
        if (prodMap != null) ...[
          const SizedBox(height: 8),
          _SectionTitle(title: 'Proizvod', icon: Icons.inventory_2_outlined),
          _kv('Šifra', prodMap['productCode']?.toString() ?? '—'),
          _kv('Naziv', prodMap['name']?.toString() ?? '—'),
        ],
        const SizedBox(height: 8),
        _SectionTitle(
          title: 'Evidencija rada (zapisi: ${tList.length})',
          icon: Icons.playlist_add_check,
        ),
        if (tList.isEmpty)
          Text('Nema upisanog praćenja s ovim nalogom.', style: TextStyle(color: cs.outline))
        else
          for (final e in tList)
            if (e is Map) _TrackingLine(m: Map<String, dynamic>.from(e)),
        const SizedBox(height: 8),
        _SectionTitle(
          title: 'Kontrolne inspekcije (${iList.length})',
          icon: Icons.fact_check_outlined,
        ),
        if (iList.isEmpty)
          Text(
            'Nema zabilježenih kontrola kvalitete za ovaj nalog.',
            style: TextStyle(color: cs.outline),
          )
        else
          for (final e in iList)
            if (e is Map) _InspectionLine(m: Map<String, dynamic>.from(e)),
      ],
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _TrackingLine extends StatelessWidget {
  const _TrackingLine({required this.m});

  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final line = [
      m['phase']?.toString() ?? '',
      m['workDate']?.toString() ?? '',
      '${m['itemCode'] ?? ''} · ${m['quantity'] ?? ''} ${m['unit'] ?? ''}',
      if ((m['workCenterId'] ?? '').toString().isNotEmpty)
        'RC: ${m['workCenterId']}',
      m['createdByEmail']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        line,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _InspectionLine extends StatelessWidget {
  const _InspectionLine({required this.m});

  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      m['overallResult']?.toString() ?? '',
      m['inspectionPlanId']?.toString() ?? '',
      m['inspectedAtIso']?.toString() ?? '',
    ];
    final lot = m['lotId']?.toString() ?? '';
    if (lot.isNotEmpty) parts.add('lot: $lot');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        parts.where((s) => s.isNotEmpty).join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
